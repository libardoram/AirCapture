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
import os.log

// MARK: - AirPlayReceiver

/// Swift wrapper around the UxPlay C library.
/// Each instance represents one AirPlay receiver (one Bonjour service).
/// Delivers raw H.264 NAL units via a delegate protocol.
final class AirPlayReceiver {

    // MARK: - Types

    /// Delegate for receiving decoded video data and connection events.
    protocol Delegate: AnyObject {
        /// Called when H.264/H.265 NAL unit data arrives from the client.
        func receiver(_ receiver: AirPlayReceiver, didReceiveVideoData data: UnsafeBufferPointer<UInt8>, isH265: Bool, nalCount: Int, ntpTimeLocal: UInt64, ntpTimeRemote: UInt64)

        /// Called when audio data arrives from the client.
        func receiver(_ receiver: AirPlayReceiver, didReceiveAudioData data: UnsafeBufferPointer<UInt8>, codecType: UInt8)

        /// Called when the video codec is set (H.264 or H.265).
        func receiver(_ receiver: AirPlayReceiver, didSetVideoCodec isH265: Bool)

        /// Called when a client connects.
        func receiverDidConnect(_ receiver: AirPlayReceiver, deviceId: String, model: String, name: String)

        /// Called when a client disconnects.
        func receiverDidDisconnect(_ receiver: AirPlayReceiver)
        
        /// Called when UxPlay displays a PIN (informational, PIN is already set via settings)
        func receiver(_ receiver: AirPlayReceiver, shouldDisplayPIN pin: String)
        
        /// Called when a connection attempt is made (before PIN validation)
        func receiver(_ receiver: AirPlayReceiver, connectionAttemptFrom deviceId: String, model: String, name: String) -> Bool
    }

    // MARK: - Properties

    let slotIndex: Int
    let serviceName: String
    private(set) var port: UInt16 = 0
    private(set) var isRunning = false

    weak var delegate: Delegate?

    private var raop: OpaquePointer?     // raop_t*
    private var dnssd: OpaquePointer?    // dnssd_t*

    /// The MAC address bytes for this receiver (6 bytes, each slot gets a unique one).
    private let hwAddr: [UInt8]
    
    /// Current PIN code (kept alive for C callback)
    fileprivate var currentPIN: String?

    private static let logger = Logger(subsystem: "com.aircapture.AirCapture", category: "AirPlayReceiver")

    // MARK: - Init

    /// - Parameters:
    ///   - slotIndex: Unique index (0-based) for this receiver slot.
    ///   - serviceName: Bonjour service name, e.g. "AirCapture-01".
    init(slotIndex: Int, serviceName: String) {
        self.slotIndex = slotIndex
        self.serviceName = serviceName
        // Generate a unique MAC address per slot: AA:BB:CC:DD:00:XX
        self.hwAddr = [0xAA, 0xBB, 0xCC, 0xDD, 0x00, UInt8(slotIndex & 0xFF)]
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    /// Set the PIN code for password authentication
    func setPIN(_ pin: String?) {
        self.currentPIN = pin
    }

    /// Start the AirPlay receiver. Returns the port it's listening on.
    @discardableResult
    func start() throws -> UInt16 {
        guard !isRunning else { return port }

        // 1) Build the C callbacks struct
        var callbacks = raop_callbacks_s()
        // Store `self` as the opaque context pointer
        let unmanaged = Unmanaged.passUnretained(self)
        callbacks.cls = unmanaged.toOpaque()

        // Required callbacks
        callbacks.audio_process = airplay_audio_process
        callbacks.video_process = airplay_video_process_callback

        // Lifecycle callbacks
        callbacks.conn_init = airplay_conn_init
        callbacks.conn_destroy = airplay_conn_destroy
        callbacks.conn_teardown = airplay_conn_teardown

        // Video callbacks
        callbacks.video_set_codec = airplay_video_set_codec
        callbacks.video_flush = airplay_video_flush
        callbacks.video_pause = airplay_video_pause
        callbacks.video_resume = airplay_video_resume
        callbacks.conn_reset = airplay_conn_reset
        callbacks.video_reset = airplay_video_reset
        callbacks.conn_feedback = airplay_conn_feedback

        // Audio callbacks
        callbacks.audio_flush = airplay_audio_flush
        callbacks.audio_set_volume = airplay_audio_set_volume
        callbacks.audio_get_format = airplay_audio_get_format

        // Client admission
        callbacks.report_client_request = airplay_report_client_request
        
        // PIN/Password callbacks — only register if a PIN is actually configured.
        // Registering passwd unconditionally causes raop_handlers to enter the HTTP Digest
        // authentication flow (returning 401 Unauthorized) even when no PIN is set.
        // Apple Silicon Macs on macOS 14/15 do not retry after an unexpected 401, which
        // stalls the RTSP handshake and results in a black screen with no Mirror/Extend dialog.
        if let pin = currentPIN, !pin.isEmpty {
            callbacks.display_pin = airplay_display_pin
            callbacks.passwd = airplay_get_password
        }

        // 2) Initialize raop
        raop = raop_init(&callbacks)
        guard raop != nil else {
            throw AirPlayError.initFailed("raop_init returned nil")
        }

        // 3) Initialize raop2 (pairing, httpd)
        //    device_id format: "AA:BB:CC:DD:00:XX"
        let deviceId = hwAddr.map { String(format: "%02X", $0) }.joined(separator: ":")
        // keyfile: store per-slot key
        let keyDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AirCapture", isDirectory: true)
        try FileManager.default.createDirectory(at: keyDir, withIntermediateDirectories: true)
        let keyFile = keyDir.appendingPathComponent("slot_\(slotIndex).pk").path

        let nohold: Int32 = 1  // NOHOLD: allow new connections to replace existing
        let ret = raop_init2(raop, nohold, deviceId, keyFile)
        guard ret == 0 else {
            raop_destroy(raop)
            raop = nil
            throw AirPlayError.initFailed("raop_init2 returned \(ret)")
        }

        // 4) Set log level
        raop_set_log_level(raop, LOGGER_INFO)
        raop_set_log_callback(raop, airplay_log_callback, unmanaged.toOpaque())

        // 5) Configure plist parameters for screen mirroring
        raop_set_plist(raop, "width", 1920)
        raop_set_plist(raop, "height", 1080)
        raop_set_plist(raop, "refreshRate", 60)
        raop_set_plist(raop, "maxFPS", 30)
        raop_set_plist(raop, "overscanned", 0)
        raop_set_plist(raop, "clientFPSdata", 0)

        // 6) Initialize DNS-SD (Bonjour)
        var dnssdError: Int32 = 0
        dnssd = serviceName.withCString { namePtr in
            hwAddr.withUnsafeBufferPointer { hwBuf in
                let rawPtr = UnsafeRawPointer(hwBuf.baseAddress!).bindMemory(to: CChar.self, capacity: 6)
                return dnssd_init(namePtr, Int32(serviceName.utf8.count), rawPtr, 6, &dnssdError, 0)
            }
        }
        guard dnssd != nil, dnssdError == 0 else {
            raop_destroy(raop)
            raop = nil
            throw AirPlayError.dnssdFailed("dnssd_init error: \(dnssdError)")
        }

        // Set the public key in dnssd
        let pkStr = raop_pk_string(raop)
        if let pkStr {
            dnssd_set_pk(dnssd, pkStr)
        }

        // Link dnssd to raop
        raop_set_dnssd(raop, dnssd)

        // 7) Start the HTTP daemon
        // Note: raop_start_httpd returns 1 for success, 0 for already running, negative for errors
        var httpPort: UInt16 = 0
        let startRet = raop_start_httpd(raop, &httpPort)
        guard startRet == 1 else {
            dnssd_destroy(dnssd)
            dnssd = nil
            raop_destroy(raop)
            raop = nil
            throw AirPlayError.startFailed("raop_start_httpd returned \(startRet)")
        }
        port = httpPort

        // 8) Register DNS-SD services
        let raopReg = dnssd_register_raop(dnssd, httpPort)
        let airplayReg = dnssd_register_airplay(dnssd, httpPort)
        guard raopReg == 0, airplayReg == 0 else {
            raop_stop_httpd(raop)
            dnssd_destroy(dnssd)
            dnssd = nil
            raop_destroy(raop)
            raop = nil
            throw AirPlayError.startFailed("dnssd_register failed: raop=\(raopReg), airplay=\(airplayReg)")
        }

        isRunning = true
        Self.logger.info("AirPlayReceiver[\(self.slotIndex)] started on port \(httpPort) as '\(self.serviceName)'")
        return httpPort
    }

    /// Stop the receiver and unregister Bonjour services.
    func stop() {
        guard isRunning else { return }
        isRunning = false

        if let dnssd {
            dnssd_unregister_raop(dnssd)
            dnssd_unregister_airplay(dnssd)
        }

        if let raop {
            raop_stop_httpd(raop)
            raop_destroy(raop)
        }
        self.raop = nil

        if let dnssd {
            dnssd_destroy(dnssd)
        }
        self.dnssd = nil

        Self.logger.info("AirPlayReceiver[\(self.slotIndex)] stopped")
    }

    // MARK: - Helpers

    /// Extract the public key string from the raop instance.
    /// The pk_str is stored inside raop_s which is opaque, but we can
    /// access it via dnssd after raop_init2 sets it up.
    private func raop_pk_string(_ raop: OpaquePointer?) -> UnsafeMutablePointer<CChar>? {
        // raop_init2 stores the pk_str in raop->pk_str, and the only public
        // way to get it is through raop_get_callback_cls or by inspecting.
        // Since raop_s is opaque we can't access pk_str directly.
        // UxPlay normally reads it internally when setting dnssd.
        // For now, return nil — dnssd_set_pk is optional if we don't need pin auth.
        return nil
    }
}

// MARK: - Errors

enum AirPlayError: Error, LocalizedError {
    case initFailed(String)
    case dnssdFailed(String)
    case startFailed(String)

    var errorDescription: String? {
        switch self {
        case .initFailed(let msg): return "AirPlay init failed: \(msg)"
        case .dnssdFailed(let msg): return "DNS-SD failed: \(msg)"
        case .startFailed(let msg): return "AirPlay start failed: \(msg)"
        }
    }
}

// MARK: - C Callback Functions (top-level, not closures)

// These are C-compatible function pointers. They extract the AirPlayReceiver
// from the `cls` void pointer and forward to the delegate.

private func airplay_video_process_callback(_ cls: UnsafeMutableRawPointer?, _ ntp: OpaquePointer?, _ data: UnsafeMutablePointer<video_decode_struct>?) {
    guard let cls, let data else { return }
    let receiver = Unmanaged<AirPlayReceiver>.fromOpaque(cls).takeUnretainedValue()
    let vd = data.pointee
    guard vd.data_len > 0, let rawData = vd.data else { return }
    let buffer = UnsafeBufferPointer(start: rawData, count: Int(vd.data_len))
    receiver.delegate?.receiver(receiver, didReceiveVideoData: buffer, isH265: vd.is_h265, nalCount: Int(vd.nal_count), ntpTimeLocal: vd.ntp_time_local, ntpTimeRemote: vd.ntp_time_remote)
}

private func airplay_audio_process(_ cls: UnsafeMutableRawPointer?, _ ntp: OpaquePointer?, _ data: UnsafeMutablePointer<audio_decode_struct>?) {
    guard let cls, let data else { return }
    let receiver = Unmanaged<AirPlayReceiver>.fromOpaque(cls).takeUnretainedValue()
    let ad = data.pointee
    guard ad.data_len > 0, let rawData = ad.data else { return }
    let buffer = UnsafeBufferPointer(start: rawData, count: Int(ad.data_len))
    receiver.delegate?.receiver(receiver, didReceiveAudioData: buffer, codecType: ad.ct)
}

private func airplay_video_set_codec(_ cls: UnsafeMutableRawPointer?, _ codec: video_codec_t) -> Int32 {
    guard let cls else { return -1 }
    let receiver = Unmanaged<AirPlayReceiver>.fromOpaque(cls).takeUnretainedValue()
    let isH265 = (codec == VIDEO_CODEC_H265)
    receiver.delegate?.receiver(receiver, didSetVideoCodec: isH265)
    return 0
}

private func airplay_conn_init(_ cls: UnsafeMutableRawPointer?) {
    // Connection initialized — no action needed yet
}

private func airplay_conn_destroy(_ cls: UnsafeMutableRawPointer?) {
    guard let cls else { return }
    let receiver = Unmanaged<AirPlayReceiver>.fromOpaque(cls).takeUnretainedValue()
    receiver.delegate?.receiverDidDisconnect(receiver)
}

private func airplay_conn_teardown(_ cls: UnsafeMutableRawPointer?, _ teardown_96: UnsafeMutablePointer<Bool>?, _ teardown_110: UnsafeMutablePointer<Bool>?) {
    // Set both teardown flags to true to allow clean shutdown
    teardown_96?.pointee = true
    teardown_110?.pointee = true
}

private func airplay_video_flush(_ cls: UnsafeMutableRawPointer?) {
    // Video flush — decoder should clear its buffers
}

private func airplay_video_pause(_ cls: UnsafeMutableRawPointer?) {
    // Video paused by client
}

private func airplay_video_resume(_ cls: UnsafeMutableRawPointer?) {
    // Video resumed by client
}

private func airplay_conn_reset(_ cls: UnsafeMutableRawPointer?, _ reason: Int32) {
    // Connection reset
}

private func airplay_video_reset(_ cls: UnsafeMutableRawPointer?, _ resetType: reset_type_t) {
    // Video reset
}

private func airplay_conn_feedback(_ cls: UnsafeMutableRawPointer?) {
    // Connection feedback — keep-alive
}

private func airplay_audio_flush(_ cls: UnsafeMutableRawPointer?) {
    // Audio flush
}

private func airplay_audio_set_volume(_ cls: UnsafeMutableRawPointer?, _ volume: Float) {
    // Audio volume changed
}

private func airplay_audio_get_format(_ cls: UnsafeMutableRawPointer?, _ ct: UnsafeMutablePointer<UInt8>?, _ spf: UnsafeMutablePointer<UInt16>?, _ usingScreen: UnsafeMutablePointer<Bool>?, _ isMedia: UnsafeMutablePointer<Bool>?, _ audioFormat: UnsafeMutablePointer<UInt64>?) {
    // Report audio format; set defaults
    ct?.pointee = 8         // AAC-ELD
    spf?.pointee = 480
    usingScreen?.pointee = true
    isMedia?.pointee = false
    audioFormat?.pointee = 0
}

private func airplay_report_client_request(_ cls: UnsafeMutableRawPointer?, _ deviceId: UnsafeMutablePointer<CChar>?, _ model: UnsafeMutablePointer<CChar>?, _ name: UnsafeMutablePointer<CChar>?, _ admit: UnsafeMutablePointer<Bool>?) {
    guard let cls else { return }
    let receiver = Unmanaged<AirPlayReceiver>.fromOpaque(cls).takeUnretainedValue()

    let devStr = deviceId.map { String(cString: $0) } ?? "unknown"
    let modelStr = model.map { String(cString: $0) } ?? "unknown"
    let nameStr = name.map { String(cString: $0) } ?? "unknown"

    // Ask delegate if this connection should be admitted (called from background thread)
    let shouldAdmit = receiver.delegate?.receiver(receiver, connectionAttemptFrom: devStr, model: modelStr, name: nameStr) ?? true
    admit?.pointee = shouldAdmit
    
    // If admitted, notify connection established
    if shouldAdmit {
        receiver.delegate?.receiverDidConnect(receiver, deviceId: devStr, model: modelStr, name: nameStr)
    }
}

private func airplay_display_pin(_ cls: UnsafeMutableRawPointer?, _ pin: UnsafeMutablePointer<CChar>?) {
    guard let cls, let pin else { return }
    let receiver = Unmanaged<AirPlayReceiver>.fromOpaque(cls).takeUnretainedValue()
    let pinStr = String(cString: pin)
    
    let logger = Logger(subsystem: "com.aircapture.AirCapture", category: "AirPlayReceiver")
    logger.info("PIN authentication active for slot \(receiver.slotIndex): \(pinStr)")
    receiver.delegate?.receiver(receiver, shouldDisplayPIN: pinStr)
}

private func airplay_get_password(_ cls: UnsafeMutableRawPointer?, _ len: UnsafeMutablePointer<Int32>?) -> UnsafePointer<CChar>? {
    guard let cls else { return nil }
    let receiver = Unmanaged<AirPlayReceiver>.fromOpaque(cls).takeUnretainedValue()
    
    // Use the PIN that was set via setPIN() method (called from main thread before starting)
    guard let pinCode = receiver.currentPIN, !pinCode.isEmpty else {
        return nil // No PIN required
    }
    
    len?.pointee = Int32(pinCode.count)
    
    // Return pointer to PIN string using strdup to create a C-owned copy
    return pinCode.withCString { (ptr: UnsafePointer<CChar>) -> UnsafePointer<CChar>? in
        return UnsafePointer(strdup(ptr))
    }
}

private func airplay_log_callback(_ cls: UnsafeMutableRawPointer?, _ level: Int32, _ msg: UnsafePointer<CChar>?) {
    guard let msg else { return }
    let message = String(cString: msg)
    let logger = Logger(subsystem: "com.aircapture.AirCapture", category: "UxPlay")

    switch level {
    case 0...3:  // EMERG..ERR
        logger.error("\(message, privacy: .public)")
    case 4:      // WARNING
        logger.warning("\(message, privacy: .public)")
    case 5...6:  // NOTICE, INFO
        logger.info("\(message, privacy: .public)")
    default:     // DEBUG
        logger.debug("\(message, privacy: .public)")
    }
}
