// AirCapture - Multi-stream AirPlay receiver and recorder for macOS
// Copyright (C) 2026  Libardo Ramirez
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.
//
// Source code: https://github.com/libardoram/AirCapture
// Binary available at: https://aircapture.eqmo.com

import Foundation
import AVFoundation
import CoreMedia
import os.log

// MARK: - StreamRecorder

/// Records a single AirPlay video stream to an MP4 file using H.264 passthrough (no re-encoding).
/// Feeds raw H.264 NAL units from the AirPlay stream directly to AVAssetWriter.
/// Records at 15fps (drops every other frame) to optimize storage space for long exam sessions.
final class StreamRecorder {

    // MARK: - Properties

    private let slotIndex: Int
    private let outputURL: URL

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var formatDescription: CMFormatDescription?

    private var spsData: Data?
    private var ppsData: Data?

    private var isRecording = false
    private var startTime: CMTime?
    private var lastPresentationTime: CMTime = .zero

    /// Frame counter for dropping frames to achieve 15fps recording (drop every other frame)
    private var frameCounter: UInt64 = 0

    private static let logger = Logger(subsystem: "com.aircapture.AirCapture", category: "StreamRecorder")

    // MARK: - Init

    /// - Parameters:
    ///   - slotIndex: The stream slot index.
    ///   - outputURL: The URL to write the MP4 file.
    init(slotIndex: Int, outputURL: URL) {
        self.slotIndex = slotIndex
        self.outputURL = outputURL
    }

    deinit {
        stop()
    }

    // MARK: - Recording Control

    /// Start recording. Creates the AVAssetWriter and waits for SPS/PPS before writing frames.
    func start() throws {
        guard !isRecording else { return }

        // Create directory if needed
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        // Create AVAssetWriter
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        self.assetWriter = writer

        isRecording = true
        Self.logger.info("StreamRecorder[\(self.slotIndex)] started, output: \(self.outputURL.path)")
    }

    /// Seed the recorder with cached SPS/PPS from the decoder.
    /// Call this immediately after start() to ensure the recorder can process frames right away.
    func setCachedParameterSets(sps: Data, pps: Data) {
        self.spsData = sps
        self.ppsData = pps
        Self.logger.debug("Recorder[\(self.slotIndex)] seeded with cached SPS (\(sps.count) bytes) and PPS (\(pps.count) bytes)")
        createFormatDescriptionAndInput()
    }

    /// Stop recording and finalize the MP4 file.
    func stop() {
        guard isRecording else { return }
        isRecording = false

        guard let writer = assetWriter else { return }

        if writer.status == .writing {
            videoInput?.markAsFinished()
            writer.finishWriting { [weak self] in
                guard let self else { return }
                if writer.status == .completed {
                    Self.logger.info("StreamRecorder[\(self.slotIndex)] finished writing to \(self.outputURL.path)")
                } else if let error = writer.error {
                    Self.logger.error("StreamRecorder[\(self.slotIndex)] failed: \(error.localizedDescription)")
                }
            }
        }

        assetWriter = nil
        videoInput = nil
        formatDescription = nil
        spsData = nil
        ppsData = nil
        startTime = nil
        lastPresentationTime = .zero
        frameCounter = 0
    }

    // MARK: - Data Ingestion

    /// Feed raw H.264 NAL data from the AirPlay stream.
    /// - Parameters:
    ///   - nalData: Raw NAL data in Annex-B format (start codes: 0x00 0x00 0x01 or 0x00 0x00 0x00 0x01).
    ///   - ntpTimeLocal: Local NTP timestamp (nanoseconds).
    func appendNALData(_ nalData: UnsafeBufferPointer<UInt8>, ntpTimeLocal: UInt64) {
        guard isRecording else {
            Self.logger.debug("Recorder[\(self.slotIndex)] ignoring data - not recording")
            return
        }

        Self.logger.debug("Recorder[\(self.slotIndex)] received \(nalData.count) bytes")
        
        // Parse NAL units
        let nalUnits = parseAnnexB(Array(nalData))
        Self.logger.debug("Recorder[\(self.slotIndex)] parsed \(nalUnits.count) NAL units")

        // Collect all VCL (Video Coding Layer) NAL units for this frame
        var frameNALs: [ArraySlice<UInt8>] = []
        var isKeyframe = false
        
        for nalUnit in nalUnits {
            guard nalUnit.count > 0 else { continue }
            let nalType = nalUnit[nalUnit.startIndex] & 0x1F  // H.264 NAL type

            switch nalType {
            case 7: // SPS
                let newSPS = Data(nalUnit)
                if spsData != newSPS {
                    Self.logger.info("Recorder[\(self.slotIndex)] got NEW SPS (\(nalUnit.count) bytes) - different from cached")
                    spsData = newSPS
                    if ppsData != nil {
                        // Don't recreate if already have format description
                        if formatDescription == nil {
                            createFormatDescriptionAndInput()
                        }
                    }
                }

            case 8: // PPS
                let newPPS = Data(nalUnit)
                if ppsData != newPPS {
                    Self.logger.info("Recorder[\(self.slotIndex)] got NEW PPS (\(nalUnit.count) bytes) - different from cached")
                    ppsData = newPPS
                    if spsData != nil {
                        // Don't recreate if already have format description
                        if formatDescription == nil {
                            createFormatDescriptionAndInput()
                        }
                    }
                }

            case 5: // IDR (keyframe)
                if videoInput == nil && spsData != nil && ppsData != nil {
                    createFormatDescriptionAndInput()
                }
                frameNALs.append(nalUnit)
                isKeyframe = true

            case 1: // Non-IDR (P/B frame)
                frameNALs.append(nalUnit)

            default:
                // SEI, AUD, filler, etc. - include them in the frame
                if nalType >= 1 && nalType <= 12 {
                    frameNALs.append(nalUnit)
                }
            }
        }
        
        // Write all collected NAL units as one frame
        if !frameNALs.isEmpty {
            let nalTypes = frameNALs.map { $0[$0.startIndex] & 0x1F }
            Self.logger.debug("Recorder[\(self.slotIndex)] writing frame with NAL types: \(nalTypes), isKeyframe=\(isKeyframe)")
            appendVideoFrame(nalUnits: frameNALs, ntpTimeLocal: ntpTimeLocal, isKeyframe: isKeyframe)
        }
    }

    // MARK: - Private Helpers

    private func createFormatDescriptionAndInput() {
        guard let spsData, let ppsData, formatDescription == nil else { return }

        let spsArray = [UInt8](spsData)
        let ppsArray = [UInt8](ppsData)

        var formatDesc: CMFormatDescription?

        let status = spsArray.withUnsafeBufferPointer { spsBuf in
            ppsArray.withUnsafeBufferPointer { ppsBuf in
                let paramSets: [UnsafePointer<UInt8>] = [spsBuf.baseAddress!, ppsBuf.baseAddress!]
                let paramSetSizes: [Int] = [spsArray.count, ppsArray.count]
                return paramSets.withUnsafeBufferPointer { setsBuf in
                    paramSetSizes.withUnsafeBufferPointer { sizesBuf in
                        CMVideoFormatDescriptionCreateFromH264ParameterSets(
                            allocator: kCFAllocatorDefault,
                            parameterSetCount: 2,
                            parameterSetPointers: setsBuf.baseAddress!,
                            parameterSetSizes: sizesBuf.baseAddress!,
                            nalUnitHeaderLength: 4,
                            formatDescriptionOut: &formatDesc
                        )
                    }
                }
            }
        }

        guard status == noErr, let formatDesc else {
            Self.logger.error("Recorder[\(self.slotIndex)] failed to create format description: \(status)")
            return
        }

        self.formatDescription = formatDesc

        // Create AVAssetWriterInput for H.264 passthrough (nil output settings = passthrough)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: formatDesc)
        input.expectsMediaDataInRealTime = true

        guard let writer = assetWriter, writer.canAdd(input) else {
            Self.logger.error("Recorder[\(self.slotIndex)] cannot add video input to writer")
            return
        }

        writer.add(input)
        self.videoInput = input

        // Start writing session
        writer.startWriting()
        if writer.status == .writing {
            writer.startSession(atSourceTime: .zero)
            Self.logger.info("Recorder[\(self.slotIndex)] AVAssetWriter session started successfully")
        } else {
            Self.logger.error("Recorder[\(self.slotIndex)] AVAssetWriter failed to start, status: \(writer.status.rawValue), error: \(writer.error?.localizedDescription ?? "none")")
        }
    }

    private func appendVideoFrame(nalUnits: [ArraySlice<UInt8>], ntpTimeLocal: UInt64, isKeyframe: Bool) {
        guard let input = videoInput, let formatDesc = formatDescription, input.isReadyForMoreMediaData else {
            if videoInput == nil {
                Self.logger.warning("Recorder[\(self.slotIndex)] videoInput is nil, skipping frame (keyframe=\(isKeyframe))")
            } else if formatDescription == nil {
                Self.logger.warning("Recorder[\(self.slotIndex)] formatDescription is nil, skipping frame")
            } else {
                Self.logger.debug("Recorder[\(self.slotIndex)] not ready for more data, skipping frame")
            }
            return
        }

        Self.logger.debug("Recorder[\(self.slotIndex)] appending frame with \(nalUnits.count) NAL units (keyframe=\(isKeyframe))")

        // Frame dropping for 15fps recording: keep keyframes + every other non-keyframe
        frameCounter += 1
        if !isKeyframe && frameCounter % 2 == 0 {
            // Drop this frame to achieve ~15fps from ~30fps input
            return
        }

        // Convert multiple Annex-B NALs to AVCC format (4-byte length prefix per NAL)
        var avccData = Data()
        for nalUnit in nalUnits {
            let nalLength = UInt32(nalUnit.count)
            // Append 4-byte length prefix
            avccData.append(UInt8((nalLength >> 24) & 0xFF))
            avccData.append(UInt8((nalLength >> 16) & 0xFF))
            avccData.append(UInt8((nalLength >> 8) & 0xFF))
            avccData.append(UInt8(nalLength & 0xFF))
            // Append NAL unit data
            avccData.append(contentsOf: nalUnit)
        }

        let avccDataCount = avccData.count

        // Create CMBlockBuffer
        var blockBuffer: CMBlockBuffer?
        avccData.withUnsafeMutableBytes { rawBuf in
            guard let baseAddress = rawBuf.baseAddress else { return }
            let status = CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: nil,
                blockLength: avccDataCount,
                blockAllocator: kCFAllocatorDefault,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: avccDataCount,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
            guard status == kCMBlockBufferNoErr, let bb = blockBuffer else { return }
            CMBlockBufferReplaceDataBytes(
                with: baseAddress,
                blockBuffer: bb,
                offsetIntoDestination: 0,
                dataLength: avccDataCount
            )
        }

        guard let blockBuffer else { return }

        // Create CMSampleBuffer with normalized timestamps
        // Convert NTP time to CMTime
        let currentTime = CMTimeMake(value: Int64(ntpTimeLocal), timescale: 1_000_000_000)
        
        // Normalize to start at zero (subtract first frame timestamp)
        if startTime == nil {
            startTime = currentTime
        }
        
        let normalizedTime = CMTimeSubtract(currentTime, startTime!)
        
        // Calculate duration from last frame
        let duration: CMTime
        if lastPresentationTime != .zero {
            duration = CMTimeSubtract(normalizedTime, lastPresentationTime)
        } else {
            duration = CMTimeMake(value: 1, timescale: 15) // assume 15fps (our target recording rate)
        }
        lastPresentationTime = normalizedTime

        var timingInfo = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: normalizedTime,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        var sampleSize = avccDataCount

        let status = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDesc,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )

        guard status == noErr, let sampleBuffer else {
            Self.logger.error("Recorder[\(self.slotIndex)] failed to create sample buffer: \(status)")
            return
        }

        // Mark keyframe
        if isKeyframe {
            if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) as? NSArray,
               let dict = attachments.firstObject as? NSMutableDictionary {
                dict[kCMSampleAttachmentKey_DependsOnOthers] = false
            }
        }

        // Append to writer
        if input.append(sampleBuffer) {
            Self.logger.debug("Recorder[\(self.slotIndex)] successfully appended frame at time \(CMTimeGetSeconds(normalizedTime))s")
        } else {
            Self.logger.error("Recorder[\(self.slotIndex)] failed to append sample buffer, writer status: \(self.assetWriter?.status.rawValue ?? -1)")
            if let error = assetWriter?.error {
                Self.logger.error("Recorder[\(self.slotIndex)] writer error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Annex-B Parser

    private func parseAnnexB(_ buffer: [UInt8]) -> [ArraySlice<UInt8>] {
        var nalUnits: [ArraySlice<UInt8>] = []
        var i = 0
        let count = buffer.count

        while i < count {
            // Find start code: 0x00 0x00 0x01 or 0x00 0x00 0x00 0x01
            var startCodeLen = 0
            if i + 2 < count && buffer[i] == 0 && buffer[i+1] == 0 && buffer[i+2] == 1 {
                startCodeLen = 3
            } else if i + 3 < count && buffer[i] == 0 && buffer[i+1] == 0 && buffer[i+2] == 0 && buffer[i+3] == 1 {
                startCodeLen = 4
            }

            if startCodeLen > 0 {
                let nalStart = i + startCodeLen
                // Find next start code or end of buffer
                var nalEnd = count
                var j = nalStart + 1
                while j + 2 < count {
                    if buffer[j] == 0 && buffer[j+1] == 0 {
                        if buffer[j+2] == 1 {
                            nalEnd = j
                            break
                        } else if j + 3 < count && buffer[j+2] == 0 && buffer[j+3] == 1 {
                            nalEnd = j
                            break
                        }
                    }
                    j += 1
                }
                if nalStart < nalEnd {
                    nalUnits.append(buffer[nalStart..<nalEnd])
                }
                i = nalEnd
            } else {
                i += 1
            }
        }

        return nalUnits
    }
}
