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
import SwiftUI
import os.log

// MARK: - PINAttemptTracker

/// Tracks failed PIN attempts per device and manages blocking.
/// Thread-safe implementation using NSLock.
final class PINAttemptTracker: ObservableObject {
    
    // MARK: - Properties
    
    @Published private(set) var failedAttempts: [String: Int] = [:] // deviceID: count
    @Published private(set) var blockedDevices: Set<String> = [] // deviceIDs that are blocked
    
    private let maxAttempts = 3
    private let lock = NSLock()
    
    private static let logger = Logger(subsystem: "com.aircapture.AirCapture", category: "PINAttemptTracker")
    
    // MARK: - Public Methods
    
    /// Record a failed PIN attempt for a device
    func recordFailedAttempt(deviceID: String, deviceName: String) {
        lock.lock()
        defer { lock.unlock() }
        
        let attempts = failedAttempts[deviceID, default: 0] + 1
        failedAttempts[deviceID] = attempts
        
        Self.logger.warning("Failed PIN attempt \(attempts)/\(self.maxAttempts) from \(deviceName) (\(deviceID))")
        
        if attempts >= maxAttempts {
            blockedDevices.insert(deviceID)
            Self.logger.error("Device \(deviceName) (\(deviceID)) blocked after \(attempts) failed attempts")
        }
    }
    
    /// Record a successful connection (resets failed attempts for device)
    func recordSuccessfulConnection(deviceID: String) {
        lock.lock()
        defer { lock.unlock() }
        
        if failedAttempts[deviceID] != nil {
            failedAttempts.removeValue(forKey: deviceID)
            Self.logger.info("Cleared failed attempts for \(deviceID) after successful connection")
        }
    }
    
    /// Check if a device is blocked due to too many failed attempts
    func isBlocked(deviceID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return blockedDevices.contains(deviceID)
    }
    
    /// Get the number of failed attempts for a device
    func getAttemptCount(deviceID: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return failedAttempts[deviceID, default: 0]
    }
    
    /// Unblock a specific device
    func unblockDevice(deviceID: String) {
        lock.lock()
        defer { lock.unlock() }
        
        blockedDevices.remove(deviceID)
        failedAttempts.removeValue(forKey: deviceID)
        Self.logger.info("Manually unblocked device \(deviceID)")
    }
    
    /// Reset all failed attempts and unblock all devices
    func resetAll() {
        lock.lock()
        defer { lock.unlock() }
        
        let blockedCount = blockedDevices.count
        failedAttempts.removeAll()
        blockedDevices.removeAll()
        Self.logger.info("Reset all PIN attempts and unblocked \(blockedCount) devices")
    }
    
    /// Get formatted summary of failed attempts
    func getSummary() -> String {
        lock.lock()
        defer { lock.unlock() }
        
        if failedAttempts.isEmpty {
            return "No failed attempts"
        }
        let blocked = blockedDevices.count
        let total = failedAttempts.count
        return "\(total) device(s) with failed attempts, \(blocked) blocked"
    }
}
