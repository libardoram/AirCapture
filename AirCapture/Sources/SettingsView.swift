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

import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case recording = "Recording"
    case security = "Security"
    case advanced = "Advanced"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .recording: return "record.circle"
        case .security: return "lock.shield"
        case .advanced: return "slider.horizontal.3"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSection: SettingsSection = .general
    @State private var selectedQualityPreset: VideoQualityPreset = .medium
    
    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar
            VStack(spacing: 0) {
                Text("Settings")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                List(SettingsSection.allCases, id: \.self) { section in
                    Button(action: {
                        selectedSection = section
                    }) {
                        Label(section.rawValue, systemImage: section.icon)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(selectedSection == section ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(6)
                    .padding(.horizontal, 8)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                
                Spacer()
            }
            .frame(width: 200)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Right detail view
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Section header
                    HStack {
                        Image(systemName: selectedSection.icon)
                            .font(.title)
                            .foregroundStyle(.blue)
                        Text(selectedSection.rawValue)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 30)
                    .padding(.bottom, 20)
                    
                    Divider()
                        .padding(.horizontal, 30)
                    
                    // Section content
                    settingsContent
                        .padding(30)
                }
            }
            .frame(minWidth: 500, maxWidth: .infinity, minHeight: 400)
        }
        .frame(width: 850, height: 650)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear {
            // Determine initial quality preset based on current settings
            if let preset = VideoQualityPreset.allCases.first(where: { $0.bitRate == settings.videoBitRate }) {
                selectedQualityPreset = preset
            }
        }
    }
    
    @ViewBuilder
    private var settingsContent: some View {
        switch selectedSection {
        case .general:
            generalSettings
        case .recording:
            recordingSettings
        case .security:
            securitySettings
        case .advanced:
            advancedSettings
        }
    }
    
    // MARK: - General Settings
    
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingRow(
                title: "Number of Streams",
                description: "Configure how many student devices can connect simultaneously. For best performance with many streams, use a Mac with sufficient RAM and a wired Ethernet connection. Changes require restarting the receivers."
            ) {
                HStack {
                    Stepper("\(settings.streamCount)", value: $settings.streamCount, in: 1...100)
                        .frame(width: 120)
                    
                    Text("(Requires restart)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            SettingRow(
                title: "Stream Name Prefix",
                description: "Customize the prefix for stream names. Streams will appear as [Prefix]-01, [Prefix]-02, etc. when students connect via AirPlay. Changes require restarting the receivers."
            ) {
                HStack {
                    TextField("Stream prefix", text: $settings.streamNamePrefix)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .onChange(of: settings.streamNamePrefix) { _, newValue in
                            // Sanitize input - allow alphanumeric and basic punctuation
                            let filtered = String(newValue.prefix(20).filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" || $0 == "_" })
                            if filtered != newValue {
                                settings.streamNamePrefix = filtered
                            }
                        }
                    
                    if !settings.streamNamePrefix.isEmpty && settings.streamNamePrefix != "AirCapture" {
                        Button("Reset to Default") {
                            settings.streamNamePrefix = "AirCapture"
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.blue)
                    }
                    
                    Text("Example: \(effectiveStreamPrefix)-01")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            SettingRow(
                title: "Default Session Name",
                description: "Set a default name for recording sessions. You can override this when starting a recording."
            ) {
                TextField("e.g., Midterm Exam", text: $settings.sessionName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
            }
            
            Divider()
            
            SettingRow(
                title: "Recordings Location",
                description: "Choose where recording sessions will be saved on your computer."
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(displayPath(settings.recordingsPath))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 300, alignment: .leading)
                        
                        Button("Choose...") {
                            selectRecordingsFolder()
                        }
                        .buttonStyle(.bordered)
                        
                        if !settings.recordingsPath.isEmpty && settings.recordingsPath != defaultRecordingsPath() {
                            Button("Reset to Default") {
                                settings.recordingsPath = defaultRecordingsPath()
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.blue)
                        }
                    }
                    
                    Button(action: {
                        revealInFinder()
                    }) {
                        Label("Show in Finder", systemImage: "folder")
                            .font(.caption)
                    }
                    .buttonStyle(.link)
                }
            }
        }
    }
    
    // MARK: - Recording Settings
    
    private var recordingSettings: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingRow(
                title: "Snapshot Frame Rate",
                description: "How frequently to capture frames from connected devices. Higher frame rates create smoother videos but require significantly more disk space during capture and in final videos."
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Picker("", selection: $settings.snapshotInterval) {
                            Text("0.25 fps (4 seconds)").tag(4.0)
                            Text("0.5 fps (2 seconds)").tag(2.0)
                            Text("1 fps (1 second)").tag(1.0)
                            Text("2 fps (0.5 seconds)").tag(0.5)
                            Text("5 fps (0.2 seconds)").tag(0.2)
                            Text("10 fps (0.1 seconds)").tag(0.1)
                            Text("20 fps (0.05 seconds)").tag(0.05)
                            Text("30 fps (0.033 seconds)").tag(0.0333)
                            Text("50 fps (0.02 seconds)").tag(0.02)
                            Text("60 fps (0.017 seconds)").tag(0.0167)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                        
                        Text("(\(snapshotFrameRate, specifier: "%.2f") fps)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Storage warning
                    HStack(spacing: 6) {
                        Image(systemName: storageWarningIcon)
                            .foregroundStyle(storageWarningColor)
                            .font(.caption)
                        
                        Text(storageWarningText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(storageWarningColor.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            Divider()
            
            SettingRow(
                title: "Video Generation Interval",
                description: "How often to generate video segments from captured snapshots. Shorter intervals create smaller, more manageable files."
            ) {
                Picker("", selection: $settings.videoGenerationInterval) {
                    Text("1 minute").tag(60.0)
                    Text("3 minutes").tag(180.0)
                    Text("5 minutes").tag(300.0)
                    Text("10 minutes").tag(600.0)
                    Text("15 minutes").tag(900.0)
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }
            
            Divider()
            
            SettingRow(
                title: "Video Quality Preset",
                description: "Choose a quality preset that balances video quality with file size. Higher quality produces larger files."
            ) {
                Picker("", selection: $selectedQualityPreset) {
                    ForEach(VideoQualityPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                .onChange(of: selectedQualityPreset) { _, newValue in
                    settings.videoBitRate = newValue.bitRate
                    settings.videoQuality = newValue.jpegQuality
                }
            }
            
            Divider()
            
            SettingRow(
                title: "Video Playback",
                description: "Videos play back in real-time at the captured frame rate, not as timelapse. The playback will be smooth at the frame rate you selected above."
            ) {
                Text("Real-time playback at \(snapshotFrameRate, specifier: "%.2f") fps")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Security Settings
    
    private var securitySettings: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingRow(
                title: "PIN Protection",
                description: "Require students to enter a 4-digit PIN when connecting via AirPlay. The PIN is displayed in the main window when receivers are running."
            ) {
                Toggle("Require PIN for connections", isOn: $settings.pinEnabled)
            }
            
            if settings.pinEnabled {
                Divider()
                
                SettingRow(
                    title: "PIN Code",
                    description: "This 4-digit code must be entered on student devices before they can connect."
                ) {
                    HStack(spacing: 12) {
                        TextField("PIN", text: $settings.pinCode)
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.bold)
                            .frame(width: 100)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                            .onChange(of: settings.pinCode) { _, newValue in
                                // Restrict to 4 digits
                                let filtered = String(newValue.prefix(4).filter { $0.isNumber })
                                if filtered != newValue {
                                    settings.pinCode = filtered
                                }
                            }
                        
                        Button(action: {
                            settings.pinCode = settings.generateNewPin()
                        }) {
                            Label("Generate New PIN", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)
                        
                        if !settings.isValidPin(settings.pinCode) {
                            Label("Must be 4 digits", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Advanced Settings
    
    private var advancedSettings: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Fine-tune recording parameters manually. Most users should use the Quality Presets in Recording settings instead.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            
            Divider()
            
            SettingRow(
                title: "Video Bit Rate",
                description: "Controls H.264 encoding quality in final MP4 files. Higher values mean better quality but larger file sizes."
            ) {
                HStack {
                    Picker("", selection: $settings.videoBitRate) {
                        Text("0.5 Mbps").tag(500_000)
                        Text("1 Mbps").tag(1_000_000)
                        Text("2 Mbps").tag(2_000_000)
                        Text("3 Mbps").tag(3_000_000)
                        Text("4 Mbps").tag(4_000_000)
                        Text("6 Mbps").tag(6_000_000)
                        Text("8 Mbps").tag(8_000_000)
                        Text("10 Mbps").tag(10_000_000)
                        Text("12 Mbps").tag(12_000_000)
                        Text("16 Mbps").tag(16_000_000)
                        Text("20 Mbps").tag(20_000_000)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }
            }
            
            Divider()
            
            SettingRow(
                title: "JPEG Quality",
                description: "Controls snapshot image compression. This sets the quality ceiling - you can't recover lost quality in video encoding."
            ) {
                HStack {
                    Slider(value: $settings.videoQuality, in: 0.5...1.0, step: 0.05)
                        .frame(width: 250)
                    
                    Text(String(format: "%.0f%%", settings.videoQuality * 100))
                        .frame(width: 50)
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private var snapshotFrameRate: Double {
        if settings.snapshotInterval <= 0 {
            return 0
        }
        return 1.0 / settings.snapshotInterval
    }
    
    private var storageWarningIcon: String {
        let fps = snapshotFrameRate
        if fps >= 30 {
            return "exclamationmark.triangle.fill"
        } else if fps >= 10 {
            return "info.circle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }
    
    private var storageWarningColor: Color {
        let fps = snapshotFrameRate
        if fps >= 30 {
            return .red
        } else if fps >= 10 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var storageWarningText: String {
        let fps = snapshotFrameRate
        
        // Calculate approximate storage per minute per stream
        // Assuming ~200KB per JPEG snapshot at medium quality
        let bytesPerSnapshot = 200_000.0
        let snapshotsPerMinute = fps * 60.0
        let mbPerMinutePerStream = (bytesPerSnapshot * snapshotsPerMinute) / 1_000_000.0
        
        if fps >= 60 {
            return String(format: "Very High Storage: ~%.0f MB/min per stream during capture. 60 fps recommended only for very short sessions.", mbPerMinutePerStream)
        } else if fps >= 30 {
            return String(format: "High Storage: ~%.0f MB/min per stream during capture. Use for short important sessions only.", mbPerMinutePerStream)
        } else if fps >= 10 {
            return String(format: "Moderate Storage: ~%.0f MB/min per stream during capture. Good for detailed monitoring.", mbPerMinutePerStream)
        } else if fps >= 2 {
            return String(format: "Normal Storage: ~%.0f MB/min per stream during capture. Balanced for most use cases.", mbPerMinutePerStream)
        } else {
            return String(format: "Low Storage: ~%.0f MB/min per stream during capture. Efficient for long sessions.", mbPerMinutePerStream)
        }
    }
    
    private var effectiveStreamPrefix: String {
        settings.streamNamePrefix.isEmpty ? "AirCapture" : settings.streamNamePrefix
    }
    
    private func defaultRecordingsPath() -> String {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDir.appendingPathComponent("AirCapture Recordings", isDirectory: true).path
    }
    
    private func displayPath(_ path: String) -> String {
        if path.isEmpty {
            return defaultRecordingsPath()
        }
        // Replace home directory with ~
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(homeDir) {
            return path.replacingOccurrences(of: homeDir, with: "~")
        }
        return path
    }
    
    private func selectRecordingsFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a location for recording sessions"
        panel.prompt = "Select"
        
        // Set initial directory
        if !settings.recordingsPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: settings.recordingsPath, isDirectory: true)
        }
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                settings.recordingsPath = url.path
            }
        }
    }
    
    private func revealInFinder() {
        let url = settings.getRecordingsDirectory()
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
}

// MARK: - SettingRow Component

struct SettingRow<Content: View>: View {
    let title: String
    let description: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            content()
                .padding(.top, 4)
        }
    }
}

#Preview {
    SettingsView()
}
