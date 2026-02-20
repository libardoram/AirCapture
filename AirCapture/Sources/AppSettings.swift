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

// MARK: - AppSettings

/// Application-wide settings stored in UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    
    static let shared = AppSettings()
    
    // MARK: - Stream Settings
    
    @AppStorage("streamCount") var streamCount: Int = 4 {
        didSet { objectWillChange.send() }
    }
    
    // MARK: - Recording Settings
    
    @AppStorage("videoGenerationInterval") var videoGenerationInterval: Double = 300.0 {  // 5 minutes
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("snapshotInterval") var snapshotInterval: Double = 5.0 {  // Capture every 5 seconds
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("videoQuality") var videoQuality: Double = 0.9 {  // 0.0 - 1.0
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("videoBitRate") var videoBitRate: Int = 2_000_000 {
        didSet { objectWillChange.send() }
    }
    
    // MARK: - Session Settings
    
    @AppStorage("sessionName") var sessionName: String = "" {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("recordingsPath") var recordingsPath: String = "" {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("streamNamePrefix") var streamNamePrefix: String = "AirCapture" {
        didSet { objectWillChange.send() }
    }
    
    // MARK: - Security Settings
    
    @AppStorage("pinEnabled") var pinEnabled: Bool = false {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("pinCode") var pinCode: String = "" {
        didSet { objectWillChange.send() }
    }
    
    private init() {
        // Generate initial PIN if not set
        if pinCode.isEmpty {
            pinCode = generateNewPin()
        }
        
        // Set default recordings path if not set
        if recordingsPath.isEmpty {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            recordingsPath = documentsDir.appendingPathComponent("AirCapture Recordings", isDirectory: true).path
        }
    }
    
    // MARK: - Helper Methods
    
    /// Generate a new random 4-digit PIN code
    func generateNewPin() -> String {
        let pin = Int.random(in: 1000...9999)
        return String(pin)
    }
    
    /// Validate that a PIN is exactly 4 digits
    func isValidPin(_ pin: String) -> Bool {
        return pin.count == 4 && pin.allSatisfy(\.isNumber)
    }
    
    /// Get the recordings directory URL
    func getRecordingsDirectory() -> URL {
        if recordingsPath.isEmpty {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            return documentsDir.appendingPathComponent("AirCapture Recordings", isDirectory: true)
        }
        return URL(fileURLWithPath: recordingsPath, isDirectory: true)
    }
}

// MARK: - Video Quality Preset

enum VideoQualityPreset: String, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case ultraHigh = "Ultra High"
    
    var id: String { rawValue }
    
    var bitRate: Int {
        switch self {
        case .low: return 1_000_000
        case .medium: return 2_000_000
        case .high: return 4_000_000
        case .ultraHigh: return 8_000_000
        }
    }
    
    var jpegQuality: Double {
        switch self {
        case .low: return 0.7
        case .medium: return 0.85
        case .high: return 0.9
        case .ultraHigh: return 0.95
        }
    }
}
