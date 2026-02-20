import Foundation
import CoreMedia
import Combine
import os.log

// MARK: - StreamSlot

/// Represents one student's AirPlay stream slot.
/// Observable so the UI grid can react to connection/frame changes.
@MainActor
final class StreamSlot: ObservableObject, Identifiable, Equatable {
    let id: Int  // slot index (0-based)
    let serviceName: String

    @Published var isConnected = false
    @Published var clientName: String = ""
    @Published var clientModel: String = ""
    @Published var clientDeviceId: String = ""
    @Published var latestPixelBuffer: CVPixelBuffer?
    @Published var frameCount: UInt64 = 0
    @Published var isRecording = false
    @Published var recordingURL: URL?

    init(id: Int, serviceName: String) {
        self.id = id
        self.serviceName = serviceName
    }
    
    // Equatable conformance
    static func == (lhs: StreamSlot, rhs: StreamSlot) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - StreamManager

/// Manages multiple AirPlayReceiver instances — one per student slot.
/// Each receiver gets a unique Bonjour service name, port, and MAC address.
/// Decoded video frames are published to the corresponding `StreamSlot` for UI display.
@MainActor
final class StreamManager: ObservableObject {

    // MARK: - Properties

    @Published private(set) var slots: [StreamSlot] = []
    @Published private(set) var isRunning = false
    @Published private(set) var isStopping = false  // Track stopping state
    @Published private(set) var activeConnectionCount = 0
    @Published private(set) var isRecordingActive = false
    @Published private(set) var recordingStartTime: Date?
    @Published var currentSessionName: String = ""
    
    // PIN and Security
    @Published private(set) var currentPIN: String = ""
    @Published private(set) var pinEnabled: Bool = false
    let pinAttemptTracker = PINAttemptTracker()
    let connectionLogger = ConnectionLogger()
    
    // Connection tracking for duration logging
    fileprivate var connectionTimes: [String: Date] = [:] // deviceID: connection time

    private var receivers: [AirPlayReceiver] = []
    private var decoders: [Int: VideoDecoder] = [:]  // slotIndex -> VideoDecoder
    private var snapshotRecorders: [Int: SnapshotRecorder] = [:]  // slotIndex -> SnapshotRecorder

    private let slotCount: Int

    /// Base directory for recordings
    private let recordingsDirectory: URL

    private static let logger = Logger(subsystem: "com.aircapture.AirCapture", category: "StreamManager")

    // MARK: - Init

    /// - Parameter slotCount: Number of concurrent AirPlay receiver slots.
    init(slotCount: Int) {
        self.slotCount = slotCount

        // Set up recordings directory from settings
        let settings = AppSettings.shared
        self.recordingsDirectory = settings.getRecordingsDirectory()

        // Create slots with custom name prefix
        let namePrefix = settings.streamNamePrefix.isEmpty ? "AirCapture" : settings.streamNamePrefix
        for i in 0..<slotCount {
            let name = String(format: "%@-%02d", namePrefix, i + 1)
            slots.append(StreamSlot(id: i, serviceName: name))
        }
    }

    // MARK: - Lifecycle

    /// Start all AirPlay receivers.
    func startAll() {
        guard !isRunning else { return }

        Self.logger.info("Starting \(self.slotCount) AirPlay receiver slots...")
        
        // Configure PIN from settings
        let settings = AppSettings.shared
        pinEnabled = settings.pinEnabled
        if pinEnabled {
            currentPIN = settings.pinCode
            Self.logger.info("PIN authentication enabled: \(self.currentPIN)")
        } else {
            currentPIN = ""
            Self.logger.info("PIN authentication disabled")
        }

        for slot in slots {
            let receiver = AirPlayReceiver(slotIndex: slot.id, serviceName: slot.serviceName)
            let decoder = VideoDecoder()

            // Set up the delegate bridge (runs on background thread, posts to main)
            let bridge = ReceiverDelegateBridge(slot: slot, decoder: decoder, manager: self)
            receiver.delegate = bridge
            decoder.delegate = bridge

            // Store the bridge so it stays alive
            bridgeStorage[slot.id] = bridge

            receivers.append(receiver)
            decoders[slot.id] = decoder
            
            // Set PIN before starting (must be done before the receiver starts)
            if pinEnabled {
                receiver.setPIN(currentPIN)
            } else {
                receiver.setPIN(nil as String?)
            }

            do {
                let port = try receiver.start()
                Self.logger.info("Slot \(slot.id) '\(slot.serviceName)' listening on port \(port)")
            } catch {
                Self.logger.error("Failed to start slot \(slot.id): \(error.localizedDescription)")
            }
        }

        isRunning = true
        Self.logger.info("All receivers started")
    }

    /// Stop all AirPlay receivers.
    func stopAll() {
        guard isRunning, !isStopping else { return }
        
        // Set stopping state immediately for UI feedback
        isRunning = false
        isStopping = true

        // Stop all recordings first (async, won't block)
        stopAllRecordings()

        // Copy receivers to stop (avoid accessing from detached task)
        let receiversToStop = receivers
        let decodersToTearDown = decoders
        
        // Stop receivers and decoders in background to avoid UI freeze
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            // Stop receivers (might take time)
            for receiver in receiversToStop {
                receiver.stop()
            }
            
            // Tear down decoders
            for (_, decoder) in decodersToTearDown {
                decoder.tearDown()
            }
            
            // Clean up on main thread
            await MainActor.run {
                self.receivers.removeAll()
                self.decoders.removeAll()
                self.bridgeStorage.removeAll()
                
                for slot in self.slots {
                    slot.isConnected = false
                    slot.clientName = ""
                    slot.latestPixelBuffer = nil
                    slot.frameCount = 0
                    slot.isRecording = false
                    slot.recordingURL = nil
                }
                self.activeConnectionCount = 0
                self.isStopping = false  // Clear stopping state
                
                Self.logger.info("All receivers stopped")
            }
        }
    }

    /// Update the count of active connections.
    func updateConnectionCount() {
        activeConnectionCount = slots.filter(\.isConnected).count
    }

    // MARK: - Recording Control

    /// Start recording all connected streams (snapshot mode).
    func startAllRecordings(sessionName: String = "") {
        // Generate session name: use provided, or default from settings, or auto-increment
        let finalSessionName: String
        if !sessionName.isEmpty {
            finalSessionName = sessionName
        } else if !AppSettings.shared.sessionName.isEmpty {
            finalSessionName = AppSettings.shared.sessionName
        } else {
            finalSessionName = generateSessionName()
        }
        
        currentSessionName = finalSessionName
        recordingStartTime = Date()
        
        for slot in slots where slot.isConnected {
            startRecording(for: slot)
        }

        isRecordingActive = !snapshotRecorders.isEmpty
        Self.logger.info("Started snapshot recording for \(self.snapshotRecorders.count) streams in session '\(finalSessionName)'")
    }

    /// Stop all active recordings and generate videos.
    func stopAllRecordings() {
        guard !snapshotRecorders.isEmpty else { return }
        
        Self.logger.info("Stopping all recordings and generating final videos...")
        
        // Store recorders to stop (avoid modifying dict during iteration)
        let recordersToStop = snapshotRecorders
        
        // Clear state immediately (UI feedback)
        snapshotRecorders.removeAll()
        isRecordingActive = false
        recordingStartTime = nil
        currentSessionName = ""
        
        // Stop all recorders in background (won't block UI)
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            await withTaskGroup(of: Void.self) { group in
                for (slotIndex, recorder) in recordersToStop {
                    group.addTask {
                        await withCheckedContinuation { continuation in
                            recorder.stop {
                                continuation.resume()
                            }
                        }
                        
                        // Update slot state on main thread
                        if let slot = await MainActor.run(body: { self.slots.first(where: { $0.id == slotIndex }) }) {
                            await MainActor.run {
                                slot.isRecording = false
                            }
                        }
                    }
                }
            }
            
            await MainActor.run {
                Self.logger.info("All recordings stopped and videos consolidated")
            }
        }
    }

    /// Start snapshot recording for a specific slot.
    private func startRecording(for slot: StreamSlot) {
        let settings = AppSettings.shared
        
        let recorder = SnapshotRecorder(
            slotIndex: slot.id,
            serviceName: slot.serviceName,
            baseDirectory: recordingsDirectory,
            streamSlot: slot,
            sessionName: currentSessionName
        )
        
        // Apply settings
        recorder.videoGenerationInterval = settings.videoGenerationInterval
        recorder.snapshotInterval = settings.snapshotInterval
        recorder.videoQuality = Float(settings.videoQuality)
        recorder.videoBitRate = settings.videoBitRate
        
        do {
            try recorder.start()
            snapshotRecorders[slot.id] = recorder
            
            Task { @MainActor in
                slot.isRecording = true
            }
            Self.logger.info("Started snapshot recording for slot \(slot.id)")
        } catch {
            Self.logger.error("Failed to start snapshot recording for slot \(slot.id): \(error.localizedDescription)")
        }
    }
    
    /// Start recording for a slot if global recording is active.
    func startRecordingIfActive(for slot: StreamSlot) {
        guard isRecordingActive, slot.isConnected else { return }
        
        // Don't start if already recording
        guard snapshotRecorders[slot.id] == nil else { return }
        
        Self.logger.info("Auto-starting recording for newly connected slot \(slot.id)")
        startRecording(for: slot)
    }
    
    /// Stop recording for a specific slot.
    func stopRecording(for slot: StreamSlot) {
        guard let recorder = snapshotRecorders[slot.id] else { return }
        
        Self.logger.info("Stopping recording for slot \(slot.id) and generating final video...")
        
        // Stop recording and generate final video
        recorder.stop {
            Task { @MainActor in
                slot.isRecording = false
            }
        }
        
        snapshotRecorders.removeValue(forKey: slot.id)
        
        Self.logger.info("Stopped recording for slot \(slot.id)")
    }
    
    // MARK: - Session Name Generation
    
    /// Generate auto-incremented session name (Session01, Session02, etc.) for today's date.
    private func generateSessionName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())
        let todayDir = recordingsDirectory.appendingPathComponent(todayString, isDirectory: true)
        
        // Check if today's folder exists
        guard FileManager.default.fileExists(atPath: todayDir.path) else {
            return "Session01"
        }
        
        // Find existing session folders
        let existingSessions = (try? FileManager.default.contentsOfDirectory(atPath: todayDir.path)) ?? []
        let sessionNumbers = existingSessions.compactMap { folderName -> Int? in
            guard folderName.hasPrefix("Session") else { return nil }
            let numericPart = String(folderName.dropFirst("Session".count))
            let numStr = numericPart.prefix(while: { $0.isNumber })
            guard !numStr.isEmpty, let num = Int(numStr) else { return nil }
            return num
        }
        
        let nextNumber = (sessionNumbers.max() ?? 0) + 1
        return String(format: "Session%02d", nextNumber)
    }

    // MARK: - Bridge Storage

    /// Holds strong references to delegate bridges so they're not deallocated.
    private var bridgeStorage: [Int: ReceiverDelegateBridge] = [:]
}

// MARK: - ReceiverDelegateBridge

/// Bridges C callback thread → main thread for UI updates.
/// Conforms to both `AirPlayReceiver.Delegate` and `VideoDecoder.Delegate`.
///
/// Callbacks from UxPlay arrive on background threads. This bridge:
/// 1. Forwards raw NAL data to the `VideoDecoder` (on the callback thread — decoding is fast).
/// 2. Posts decoded `CVPixelBuffer`s to the `StreamSlot` on the main actor for UI display.
private final class ReceiverDelegateBridge: AirPlayReceiver.Delegate, VideoDecoder.Delegate, @unchecked Sendable {

    private let slot: StreamSlot
    private let decoder: VideoDecoder
    private weak var manager: StreamManager?

    init(slot: StreamSlot, decoder: VideoDecoder, manager: StreamManager) {
        self.slot = slot
        self.decoder = decoder
        self.manager = manager
    }

    // MARK: - AirPlayReceiver.Delegate

    func receiver(_ receiver: AirPlayReceiver, didReceiveVideoData data: UnsafeBufferPointer<UInt8>, isH265: Bool, nalCount: Int, ntpTimeLocal: UInt64, ntpTimeRemote: UInt64) {
        // Decode for UI display (hardware-accelerated, very fast)
        decoder.decode(nalData: data, nalCount: nalCount, ntpTimeLocal: ntpTimeLocal)
    }

    func receiver(_ receiver: AirPlayReceiver, didReceiveAudioData data: UnsafeBufferPointer<UInt8>, codecType: UInt8) {
        // Audio handling will be implemented later
    }

    func receiver(_ receiver: AirPlayReceiver, didSetVideoCodec isH265: Bool) {
        decoder.setCodec(isH265: isH265)
    }
    
    func receiver(_ receiver: AirPlayReceiver, connectionAttemptFrom deviceId: String, model: String, name: String) -> Bool {
        guard let manager = manager else { return true }
        
        // Log the connection attempt
        manager.connectionLogger.log(.attemptStarted(deviceID: deviceId, deviceName: name, model: model))
        
        // Check if device is blocked (thread-safe)
        if manager.pinAttemptTracker.isBlocked(deviceID: deviceId) {
            manager.connectionLogger.log(.deviceBlocked(deviceID: deviceId, deviceName: name))
            let logger = Logger(subsystem: "com.aircapture.AirCapture", category: "StreamManager")
            logger.warning("Blocked connection attempt from \(name) (\(deviceId)) - too many failed PIN attempts")
            return false
        }
        
        return true // Admit the connection (PIN validation happens separately via passwd callback)
    }
    
    func receiver(_ receiver: AirPlayReceiver, shouldDisplayPIN pin: String) {
        // PIN is already configured from settings, this is just informational
        let logger = Logger(subsystem: "com.aircapture.AirCapture", category: "StreamManager")
        logger.info("PIN authentication confirmed for slot \(receiver.slotIndex): \(pin)")
    }

    func receiverDidConnect(_ receiver: AirPlayReceiver, deviceId: String, model: String, name: String) {
        Task { @MainActor in
            guard let manager = manager else { return }
            
            // If a different device was previously occupying this slot, treat it as
            // implicitly disconnected now (nohold replaced it without a disconnect event
            // reaching us before this connect). Stop its recording and log the duration.
            if slot.isConnected, slot.clientDeviceId != deviceId {
                let oldDeviceId = slot.clientDeviceId
                let oldDeviceName = slot.clientName
                if let connectTime = manager.connectionTimes[oldDeviceId] {
                    let duration = Date().timeIntervalSince(connectTime)
                    manager.connectionLogger.log(.disconnected(deviceID: oldDeviceId, deviceName: oldDeviceName, duration: duration))
                    manager.connectionTimes.removeValue(forKey: oldDeviceId)
                }
                manager.stopRecording(for: slot)
            }
            
            // Record successful connection
            manager.pinAttemptTracker.recordSuccessfulConnection(deviceID: deviceId)
            manager.connectionLogger.log(.connected(deviceID: deviceId, deviceName: name))
            manager.connectionTimes[deviceId] = Date()
            
            slot.isConnected = true
            slot.clientName = name
            slot.clientModel = model
            slot.clientDeviceId = deviceId
            manager.updateConnectionCount()
            
            // Auto-start recording if recording is active
            manager.startRecordingIfActive(for: slot)
        }
    }

    func receiverDidDisconnect(_ receiver: AirPlayReceiver) {
        // The C callback thread calls conn_destroy (which triggers this) AFTER
        // calling report_client_request for the new client (which triggered
        // receiverDidConnect). Both post Tasks to @MainActor. Because Swift's
        // MainActor processes tasks in FIFO order:
        //   1. receiverDidConnect task runs → slot.isConnected = true, slot.clientDeviceId = newId
        //   2. THIS task runs
        //
        // So if we arrive here and slot.isConnected is still true, a new client
        // already took over (nohold replacement) and we must not reset the slot.
        // We still need to log/clean up the evicted client's connection-time entry.
        Task { @MainActor in
            guard let manager = manager else { return }

            if slot.isConnected {
                // Nohold replacement: receiverDidConnect for the new client already ran
                // (it was queued first) and cleaned up the old owner's connection-time
                // entry. The slot is correctly owned by the new client — do not reset it.
                return
            }

            // Normal disconnect — no replacement.
            let deviceId = slot.clientDeviceId
            let deviceName = slot.clientName
            if let connectTime = manager.connectionTimes[deviceId] {
                let duration = Date().timeIntervalSince(connectTime)
                manager.connectionLogger.log(.disconnected(deviceID: deviceId, deviceName: deviceName, duration: duration))
                manager.connectionTimes.removeValue(forKey: deviceId)
            }
            
            manager.stopRecording(for: slot)

            slot.isConnected = false
            slot.clientName = ""
            slot.latestPixelBuffer = nil
            slot.frameCount = 0
            manager.updateConnectionCount()
        }
    }

    // MARK: - VideoDecoder.Delegate

    func decoder(_ decoder: VideoDecoder, didDecode pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        // CRITICAL: Copy the pixel buffer data to prevent use-after-free
        // VideoToolbox may reuse the buffer after this callback returns
        // We create a copy to safely pass to the main thread
        guard let pixelBufferCopy = createPixelBufferCopy(pixelBuffer) else {
            return
        }
        
        Task { @MainActor in
            slot.latestPixelBuffer = pixelBufferCopy
            slot.frameCount += 1
        }
    }
    
    /// Create a deep copy of a pixel buffer to safely pass across threads
    private func createPixelBufferCopy(_ source: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        let format = CVPixelBufferGetPixelFormatType(source)
        
        var pixelBufferCopy: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue!
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
}
