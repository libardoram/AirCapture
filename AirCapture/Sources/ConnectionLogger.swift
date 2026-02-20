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

// MARK: - Connection Event

enum ConnectionEvent {
    case attemptStarted(deviceID: String, deviceName: String, model: String)
    case pinValidationSuccess(deviceID: String, deviceName: String)
    case pinValidationFailed(deviceID: String, deviceName: String, attempt: Int)
    case deviceBlocked(deviceID: String, deviceName: String)
    case connected(deviceID: String, deviceName: String)
    case disconnected(deviceID: String, deviceName: String, duration: TimeInterval)
    
    var description: String {
        let timestamp = DateFormatter.logTimestamp.string(from: Date())
        switch self {
        case .attemptStarted(let deviceID, let deviceName, let model):
            return "[\(timestamp)] ATTEMPT | \(deviceName) (\(model)) | \(deviceID)"
        case .pinValidationSuccess(let deviceID, let deviceName):
            return "[\(timestamp)] PIN_OK | \(deviceName) | \(deviceID)"
        case .pinValidationFailed(let deviceID, let deviceName, let attempt):
            return "[\(timestamp)] PIN_FAIL | \(deviceName) | \(deviceID) | Attempt \(attempt)/3"
        case .deviceBlocked(let deviceID, let deviceName):
            return "[\(timestamp)] BLOCKED | \(deviceName) | \(deviceID) | Too many failed attempts"
        case .connected(let deviceID, let deviceName):
            return "[\(timestamp)] CONNECT | \(deviceName) | \(deviceID)"
        case .disconnected(let deviceID, let deviceName, let duration):
            let durationStr = String(format: "%.1f", duration)
            return "[\(timestamp)] DISCONNECT | \(deviceName) | \(deviceID) | Duration: \(durationStr)s"
        }
    }
}

// MARK: - ConnectionLogger

/// Logs all connection attempts and events to a file with automatic cleanup.
final class ConnectionLogger {
    
    // MARK: - Properties
    
    private let logDirectory: URL
    private let maxLogAgeDays: Int = 5
    
    private static let logger = Logger(subsystem: "com.aircapture.AirCapture", category: "ConnectionLogger")
    
    // MARK: - Init
    
    init() {
        // Use Application Support directory instead of Documents for logs
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupportDir.appendingPathComponent("AirCapture", isDirectory: true)
        self.logDirectory = appDir.appendingPathComponent("Logs", isDirectory: true)
        
        // Create log directory if needed
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        // Clean up old logs
        cleanupOldLogs()
    }
    
    // MARK: - Public Methods
    
    /// Log a connection event
    func log(_ event: ConnectionEvent) {
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            let logEntry = event.description + "\n"
            let logFile = self.getCurrentLogFile()
            
            do {
                // Append to log file
                if FileManager.default.fileExists(atPath: logFile.path) {
                    let fileHandle = try FileHandle(forWritingTo: logFile)
                    defer { try? fileHandle.close() }
                    fileHandle.seekToEndOfFile()
                    if let data = logEntry.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                } else {
                    try logEntry.write(to: logFile, atomically: true, encoding: .utf8)
                }
                
                Self.logger.debug("Logged: \(logEntry.trimmingCharacters(in: .whitespacesAndNewlines))")
            } catch {
                Self.logger.error("Failed to write log entry: \(error.localizedDescription)")
            }
        }
    }
    
    /// Get all log files sorted by date (newest first)
    func getLogFiles() -> [URL] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: logDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        return files
            .filter { $0.pathExtension == "log" }
            .sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                return date1 > date2
            }
    }
    
    /// Get the current log file URL (creates if needed)
    func getCurrentLogFile() -> URL {
        let filename = "connections_\(DateFormatter.logFilename.string(from: Date())).log"
        return logDirectory.appendingPathComponent(filename)
    }
    
    /// Clean up log files older than maxLogAgeDays
    private func cleanupOldLogs() {
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            let calendar = Calendar.current
            let cutoffDate = calendar.date(byAdding: .day, value: -self.maxLogAgeDays, to: Date())!
            
            let logFiles = self.getLogFiles()
            var deletedCount = 0
            
            for logFile in logFiles {
                if let creationDate = (try? logFile.resourceValues(forKeys: [.creationDateKey]))?.creationDate,
                   creationDate < cutoffDate {
                    try? FileManager.default.removeItem(at: logFile)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                Self.logger.info("Cleaned up \(deletedCount) old log file(s)")
            }
        }
    }
}

// MARK: - DateFormatter Extensions

private extension DateFormatter {
    static let logTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    static let logFilename: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
