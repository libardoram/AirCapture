import Foundation
import AVFoundation
import CoreMedia
import CoreImage
import AppKit
import os.log

// MARK: - SnapshotRecorder

/// Records video by capturing snapshots every 5 seconds, then generating a video from the images.
/// This approach is simpler and more reliable than H.264 passthrough.
final class SnapshotRecorder {
    
    // MARK: - Properties
    
    private let slotIndex: Int
    private let serviceName: String
    private let baseDirectory: URL
    private let sessionName: String
    
    private var isRecording = false
    private var snapshotTimer: Timer?
    private var videoGenerationTimer: Timer?
    private var snapshotCount = 0
    private var sessionDirectory: URL?
    private var imagesDirectory: URL?
    private var sessionStartTime: Date?
    private var consolidatedVideoURL: URL?  // Track the current consolidated video file
    
    private weak var streamSlot: StreamSlot?
    
    // Video generation settings (configurable)
    var videoGenerationInterval: TimeInterval = 300.0  // 5 minutes in seconds
    var snapshotInterval: TimeInterval = 5.0  // Capture interval in seconds
    var videoQuality: Float = 0.9  // JPEG quality 0.0-1.0
    var videoBitRate: Int = 2_000_000
    
    private static let logger = Logger(subsystem: "com.aircapture.AirCapture", category: "SnapshotRecorder")
    
    // MARK: - Init
    
    /// - Parameters:
    ///   - slotIndex: The stream slot index.
    ///   - serviceName: The service name (e.g., "AirCapture-01").
    ///   - baseDirectory: Base directory for recordings (e.g., ~/Documents/AirCapture Recordings).
    ///   - streamSlot: Reference to the stream slot to get pixel buffers from.
    ///   - sessionName: Name of the recording session (e.g., "Midterm Exam" or "Session01").
    init(slotIndex: Int, serviceName: String, baseDirectory: URL, streamSlot: StreamSlot, sessionName: String) {
        self.slotIndex = slotIndex
        self.serviceName = serviceName
        self.baseDirectory = baseDirectory
        self.streamSlot = streamSlot
        self.sessionName = sessionName
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Recording Control
    
    /// Start recording snapshots every 5 seconds.
    func start() throws {
        guard !isRecording else { return }
        
        // Store session start time
        let startTime = Date()
        self.sessionStartTime = startTime
        
        // Create session directory: YYYY-MM-DD/SessionName/AirCapture-XX/
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: startTime)
        
        let dateDir = baseDirectory.appendingPathComponent(dateString, isDirectory: true)
        let sessionDir = dateDir.appendingPathComponent(sessionName, isDirectory: true)
        let streamDir = sessionDir.appendingPathComponent(serviceName, isDirectory: true)
        
        // Create .images subdirectory (hidden from Finder)
        let imagesDir = streamDir.appendingPathComponent(".images", isDirectory: true)
        
        try FileManager.default.createDirectory(at: streamDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        
        self.sessionDirectory = streamDir
        self.imagesDirectory = imagesDir
        self.snapshotCount = 0
        
        // Start timer to capture snapshots every 5 seconds (or configured interval)
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: snapshotInterval, repeats: true) { [weak self] _ in
            self?.captureSnapshot()
        }
        
        // Start timer to generate video every 5 minutes
        videoGenerationTimer = Timer.scheduledTimer(withTimeInterval: videoGenerationInterval, repeats: true) { [weak self] _ in
            self?.generateSegmentVideo()
        }
        
        // Capture first snapshot immediately
        captureSnapshot()
        
        isRecording = true
        Self.logger.info("SnapshotRecorder[\(self.slotIndex)] started, saving to \(streamDir.path)")
    }
    
    /// Stop recording and generate final video from remaining snapshots.
    func stop(completion: (() -> Void)? = nil) {
        guard isRecording else { 
            completion?()
            return 
        }
        isRecording = false
        
        snapshotTimer?.invalidate()
        snapshotTimer = nil
        
        videoGenerationTimer?.invalidate()
        videoGenerationTimer = nil
        
        Self.logger.info("SnapshotRecorder[\(self.slotIndex)] stopped, captured \(self.snapshotCount) snapshots")
        
        // Generate final video from remaining snapshots, then consolidate all videos
        if let sessionDir = sessionDirectory, let imagesDir = imagesDirectory {
            Task.detached {
                // Generate final video from any remaining JPEGs
                await self.generateFinalVideo(from: sessionDir, imagesDirectory: imagesDir, deleteImages: true)
                
                // Consolidate all MP4 files into one video
                await self.consolidateVideos(in: sessionDir)
                
                completion?()
            }
        } else {
            completion?()
        }
        
        sessionDirectory = nil
        sessionStartTime = nil
        imagesDirectory = nil
        snapshotCount = 0
    }
    
    // MARK: - Video Consolidation
    
    /// Rolling consolidation: Merge new segment videos with existing consolidated video.
    /// This keeps disk usage minimal by maintaining only one consolidated file at a time.
    private func consolidateVideosRolling(in directory: URL) async {
        let fileManager = FileManager.default
        
        // Get all segment MP4 files (excluding CONSOLIDATED)
        guard let segmentFiles = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter({ $0.pathExtension == "mp4" && !$0.lastPathComponent.contains("CONSOLIDATED") })
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }),
              !segmentFiles.isEmpty else {
            // No new segments to consolidate
            return
        }
        
        Self.logger.info("SnapshotRecorder[\(self.slotIndex)] rolling consolidation: \(segmentFiles.count) segment(s) to merge")
        
        // Output filename (always the same - gets replaced each time)
        let consolidatedFilename = "\(serviceName)_CONSOLIDATED.mp4"
        let consolidatedURL = directory.appendingPathComponent(consolidatedFilename)
        let tempConsolidatedURL = directory.appendingPathComponent("\(serviceName)_TEMP_CONSOLIDATED.mp4")
        
        // Files to merge: existing consolidated (if exists) + all segment files
        var filesToMerge: [URL] = []
        if fileManager.fileExists(atPath: consolidatedURL.path) {
            filesToMerge.append(consolidatedURL)
        }
        filesToMerge.append(contentsOf: segmentFiles)
        
        // Create composition
        let composition = AVMutableComposition()
        
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            Self.logger.error("SnapshotRecorder[\(self.slotIndex)] failed to create video track for consolidation")
            return
        }
        
        var currentTime = CMTime.zero
        
        // Add each video to the composition
        for videoURL in filesToMerge {
            let asset = AVURLAsset(url: videoURL)
            
            guard let assetTrack = try? await asset.loadTracks(withMediaType: .video).first else {
                Self.logger.warning("SnapshotRecorder[\(self.slotIndex)] failed to load track from \(videoURL.lastPathComponent)")
                continue
            }
            
            let duration = try? await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration ?? .zero)
            
            do {
                try videoTrack.insertTimeRange(timeRange, of: assetTrack, at: currentTime)
                currentTime = CMTimeAdd(currentTime, duration ?? .zero)
                Self.logger.debug("SnapshotRecorder[\(self.slotIndex)] merged \(videoURL.lastPathComponent)")
            } catch {
                Self.logger.error("SnapshotRecorder[\(self.slotIndex)] failed to insert \(videoURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        // Export the consolidated video to temp location
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            Self.logger.error("SnapshotRecorder[\(self.slotIndex)] failed to create export session")
            return
        }
        
        exportSession.outputURL = tempConsolidatedURL
        exportSession.outputFileType = .mp4
        
        await exportSession.export()
        
        if exportSession.status == .completed {
            Self.logger.info("SnapshotRecorder[\(self.slotIndex)] rolling consolidation completed")
            
            // Delete old consolidated file
            if fileManager.fileExists(atPath: consolidatedURL.path) {
                try? fileManager.removeItem(at: consolidatedURL)
            }
            
            // Move temp consolidated to final location
            do {
                try fileManager.moveItem(at: tempConsolidatedURL, to: consolidatedURL)
                Self.logger.debug("SnapshotRecorder[\(self.slotIndex)] moved temp consolidated to final location")
            } catch {
                Self.logger.error("SnapshotRecorder[\(self.slotIndex)] failed to move consolidated file: \(error.localizedDescription)")
            }
            
            // Delete all segment files
            for segmentURL in segmentFiles {
                try? fileManager.removeItem(at: segmentURL)
            }
            Self.logger.debug("SnapshotRecorder[\(self.slotIndex)] deleted \(segmentFiles.count) segment file(s)")
            
        } else if let error = exportSession.error {
            Self.logger.error("SnapshotRecorder[\(self.slotIndex)] rolling consolidation failed: \(error.localizedDescription)")
            // Clean up temp file on failure
            try? fileManager.removeItem(at: tempConsolidatedURL)
        }
    }
    
    /// Consolidate all MP4 files in the directory into a single video.
    /// This is called at the end of recording to ensure all videos are merged.
    private func consolidateVideos(in directory: URL) async {
        let fileManager = FileManager.default
        
        // Check if we already have a CONSOLIDATED file
        let consolidatedFilename = "\(serviceName)_CONSOLIDATED.mp4"
        let consolidatedURL = directory.appendingPathComponent(consolidatedFilename)
        
        // Get all segment MP4 files (excluding CONSOLIDATED)
        let segmentFiles = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter({ $0.pathExtension == "mp4" && !$0.lastPathComponent.contains("CONSOLIDATED") })
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })) ?? []
        
        // If we have a consolidated file and no segments, we're done
        if fileManager.fileExists(atPath: consolidatedURL.path) && segmentFiles.isEmpty {
            Self.logger.info("SnapshotRecorder[\(self.slotIndex)] consolidated file already exists, no segments to merge")
            return
        }
        
        // If we only have segments, merge them
        if !segmentFiles.isEmpty {
            Self.logger.info("SnapshotRecorder[\(self.slotIndex)] final consolidation: merging \(segmentFiles.count) remaining segment(s)")
            await consolidateVideosRolling(in: directory)
        } else if !fileManager.fileExists(atPath: consolidatedURL.path) {
            // No videos at all
            Self.logger.info("SnapshotRecorder[\(self.slotIndex)] no videos found for consolidation")
        }
    }
    
    // MARK: - Private Helpers
    
    private func captureSnapshot() {
        guard let imagesDir = imagesDirectory else { return }
        
        Task { @MainActor in
            guard let pixelBuffer = streamSlot?.latestPixelBuffer else {
                Self.logger.debug("SnapshotRecorder[\(self.slotIndex)] skipping snapshot - no pixel buffer available")
                return
            }
            
            // CRITICAL: Create a copy of pixel buffer before using it off main thread
            // This prevents use-after-free if the buffer is replaced/released during conversion
            guard let pixelBufferCopy = self.createPixelBufferCopy(pixelBuffer) else {
                Self.logger.error("SnapshotRecorder[\(self.slotIndex)] failed to copy pixel buffer")
                return
            }
            
            // Convert CVPixelBuffer to NSImage (done off main thread to avoid blocking UI)
            Task.detached {
                guard let image = self.pixelBufferToNSImage(pixelBufferCopy) else {
                    Self.logger.error("SnapshotRecorder[\(self.slotIndex)] failed to convert pixel buffer to image")
                    return
                }
                
                // Save as JPEG with timestamp in filename: YYYY-MM-DD_HH-MM-SS_frame_XXXXX.jpg
                await MainActor.run {
                    self.snapshotCount += 1
                }
                let count = await MainActor.run { self.snapshotCount }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let timestamp = dateFormatter.string(from: Date())
                let filename = String(format: "%@_frame_%05d.jpg", timestamp, count)
                let fileURL = imagesDir.appendingPathComponent(filename)
                
                if let tiffData = image.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffData),
                   let jpegData = bitmapImage.representation(using: NSBitmapImageRep.FileType.jpeg, properties: [NSBitmapImageRep.PropertyKey.compressionFactor: NSNumber(value: self.videoQuality)]) {
                    do {
                        try jpegData.write(to: fileURL)
                        Self.logger.debug("SnapshotRecorder[\(self.slotIndex)] saved snapshot \(count)")
                    } catch {
                        Self.logger.error("SnapshotRecorder[\(self.slotIndex)] failed to save snapshot: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    /// Create a deep copy of a pixel buffer
    private func createPixelBufferCopy(_ source: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        let format = CVPixelBufferGetPixelFormatType(source)
        
        var pixelBufferCopy: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            format,
            attrs,
            &pixelBufferCopy
        )
        
        guard status == kCVReturnSuccess, let destination = pixelBufferCopy else {
            return nil
        }
        
        // Lock both buffers for copying
        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(destination, [])
        defer {
            CVPixelBufferUnlockBaseAddress(source, .readOnly)
            CVPixelBufferUnlockBaseAddress(destination, [])
        }
        
        // Copy the pixel data
        guard let sourceData = CVPixelBufferGetBaseAddress(source),
              let destinationData = CVPixelBufferGetBaseAddress(destination) else {
            return nil
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(source)
        let totalBytes = bytesPerRow * height
        memcpy(destinationData, sourceData, totalBytes)
        
        return destination
    }
    
    private func pixelBufferToNSImage(_ pixelBuffer: CVPixelBuffer) -> NSImage? {
        // Lock the pixel buffer to ensure safe memory access
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        return NSImage(cgImage: cgImage, size: size)
    }
    
    /// Generate a video from accumulated snapshots and delete the images.
    /// Then immediately consolidate with existing video to minimize disk usage.
    private func generateSegmentVideo() {
        guard let sessionDir = sessionDirectory,
              let imagesDir = imagesDirectory else { return }
        
        Task.detached {
            // Generate new segment video from snapshots
            await self.generateVideo(from: sessionDir, imagesDirectory: imagesDir, deleteImages: true)
            
            // Immediately consolidate to minimize disk usage (rolling consolidation)
            await self.consolidateVideosRolling(in: sessionDir)
            
            // Reset snapshot count for next video
            await MainActor.run {
                self.snapshotCount = 0
            }
        }
    }
    
    /// Generate final video from remaining JPEGs when stopping (checks disk for files).
    private func generateFinalVideo(from directory: URL, imagesDirectory: URL, deleteImages: Bool = false) async {
        // Check if there are any JPEG files on disk
        let fileManager = FileManager.default
        guard let jpegFiles = try? fileManager.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil)
            .filter({ $0.pathExtension == "jpg" }),
              !jpegFiles.isEmpty else {
            Self.logger.info("SnapshotRecorder[\(self.slotIndex)] no remaining JPEG files to process")
            return
        }
        
        Self.logger.info("SnapshotRecorder[\(self.slotIndex)] generating final video from \(jpegFiles.count) remaining JPEGs...")
        await self.generateVideo(from: directory, imagesDirectory: imagesDirectory, deleteImages: deleteImages)
    }
    
    private func generateVideo(from directory: URL, imagesDirectory: URL, deleteImages: Bool = false) async {
        Self.logger.info("SnapshotRecorder[\(self.slotIndex)] generating video from images...")
        
        // Output video filename with timestamp (marked as SEGMENT for easy identification)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let videoFilename = "\(serviceName)_segment_\(timestamp).mp4"
        let videoURL = directory.appendingPathComponent(videoFilename)
        
        // Get list of image files from .images directory
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil)
            .filter({ $0.pathExtension == "jpg" })
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) else {
            Self.logger.error("SnapshotRecorder[\(self.slotIndex)] failed to list image files")
            return
        }
        
        guard !files.isEmpty else {
            Self.logger.warning("SnapshotRecorder[\(self.slotIndex)] no images to create video")
            return
        }
        
        // Load first image to get dimensions
        guard let firstImage = NSImage(contentsOf: files[0]),
              let cgImage = firstImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            Self.logger.error("SnapshotRecorder[\(self.slotIndex)] failed to load first image")
            return
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Create AVAssetWriter
        guard let writer = try? AVAssetWriter(outputURL: videoURL, fileType: .mp4) else {
            Self.logger.error("SnapshotRecorder[\(self.slotIndex)] failed to create AVAssetWriter")
            return
        }
        
        // Video settings for configurable framerate H.264
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: videoBitRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )
        
        writer.add(writerInput)
        
        // Start writing
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        // Calculate frame duration to match real-time playback
        // Each snapshot represents snapshotInterval seconds of real time
        // So each frame in the video should be displayed for that duration
        let frameDuration = CMTime(seconds: snapshotInterval, preferredTimescale: 600)
        var frameCount: Int64 = 0
        
        for imageURL in files {
            guard let image = NSImage(contentsOf: imageURL),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                continue
            }
            
            // Wait until ready for more data
            while !writerInput.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.01)
            }
            
            // Create pixel buffer from CGImage
            var pixelBuffer: CVPixelBuffer?
            let attrs = [
                kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
            ] as CFDictionary
            
            let status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                width,
                height,
                kCVPixelFormatType_32ARGB,
                attrs,
                &pixelBuffer
            )
            
            guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
                continue
            }
            
            // Draw CGImage into pixel buffer
            CVPixelBufferLockBaseAddress(buffer, [])
            defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
            
            guard let context = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer),
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
            ) else {
                continue
            }
            
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            // Append pixel buffer at correct timestamp
            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameCount))
            adaptor.append(buffer, withPresentationTime: presentationTime)
            
            frameCount += 1
        }
        
        // Finish writing
        writerInput.markAsFinished()
        await writer.finishWriting()
        
        if writer.status == .completed {
            Self.logger.info("SnapshotRecorder[\(self.slotIndex)] video created successfully: \(videoURL.path)")
            
            // Delete image files if requested
            if deleteImages {
                let fileManager = FileManager.default
                for imageURL in files {
                    try? fileManager.removeItem(at: imageURL)
                }
                Self.logger.info("SnapshotRecorder[\(self.slotIndex)] deleted \(files.count) snapshot images")
            }
        } else if let error = writer.error {
            Self.logger.error("SnapshotRecorder[\(self.slotIndex)] video generation failed: \(error.localizedDescription)")
        }
    }
}
