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

struct ContentView: View {
    @ObservedObject var settings = AppSettings.shared
    @StateObject private var streamManager: StreamManager
    @State private var showingSettings = false
    @State private var showingSessionNameDialog = false
    @State private var sessionNameInput = ""
    @State private var currentTime = Date()
    @State private var selectedSlotForZoom: StreamSlot?

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init() {
        let settings = AppSettings.shared
        _streamManager = StateObject(wrappedValue: StreamManager(slotCount: settings.streamCount))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Text("AirCapture")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                startStopButton
                recordButton
                settingsButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            statusStrip
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .underPageBackgroundColor))

            Divider()

            // Stream grid or idle state
            if streamManager.isRunning {
                ScrollView {
                    StreamGridView(manager: streamManager, selectedSlotForZoom: $selectedSlotForZoom)
                        .background(Color(nsColor: .underPageBackgroundColor))
                }
            } else {
                idleStateView
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .overlay {
            if let slot = selectedSlotForZoom {
                StreamZoomView(slot: slot, isPresented: Binding(
                    get: { selectedSlotForZoom != nil },
                    set: { if !$0 { selectedSlotForZoom = nil } }
                ))
                .transition(.opacity)
                .zIndex(999)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedSlotForZoom != nil)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .alert("Start Recording Session", isPresented: $showingSessionNameDialog) {
            TextField("Session Name (optional)", text: $sessionNameInput)
            Button("Cancel", role: .cancel) { }
            Button("Start Recording") {
                streamManager.startAllRecordings(sessionName: sessionNameInput)
            }
        } message: {
            Text("Enter a name for this recording session (e.g., 'Midterm Exam' or 'Quiz 3')")
        }
        .onReceive(timer) { time in
            currentTime = time
        }
    }

    // MARK: - Toolbar Items

    private var startStopButton: some View {
        Button(action: {
            if streamManager.isRunning {
                streamManager.stopAll()
            } else {
                streamManager.startAll()
            }
        }) {
            HStack(spacing: 4) {
                if streamManager.isStopping {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: streamManager.isRunning ? "stop.fill" : "play.fill")
                }
                Text(streamManager.isStopping ? "Stopping..." : (streamManager.isRunning ? "Stop" : "Start"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(streamManager.isRunning ? .red : .green)
        .disabled(streamManager.isStopping)
    }

    private var recordButton: some View {
        Button(action: {
            if streamManager.isRecordingActive {
                streamManager.stopAllRecordings()
            } else {
                sessionNameInput = settings.sessionName
                showingSessionNameDialog = true
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: streamManager.isRecordingActive ? "stop.circle.fill" : "record.circle")
                Text(streamManager.isRecordingActive ? "Stop Recording" : "Record")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(streamManager.isRecordingActive ? .orange : .blue)
        .disabled(!streamManager.isRunning)
    }

    private var settingsButton: some View {
        Button(action: { showingSettings = true }) {
            Image(systemName: "gear")
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Status Strip

    private var statusStrip: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                Text("\(streamManager.activeConnectionCount) / \(streamManager.slots.count) streams")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if streamManager.isRunning && streamManager.pinEnabled {
                Divider()
                    .frame(height: 12)

                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                    Text("PIN:")
                        .font(.caption2)
                    Text(streamManager.currentPIN)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(streamManager.currentPIN, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .help("Copy PIN to clipboard")
                }
                .foregroundStyle(.secondary)
            }

            if streamManager.isRecordingActive, let startTime = streamManager.recordingStartTime {
                Divider()
                    .frame(height: 12)

                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text(formatDuration(from: startTime, to: currentTime))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            if streamManager.isRunning {
                Text("\(settings.streamCount)-stream mode")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Idle State

    private var idleStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            idleIcon

            VStack(spacing: 8) {
                Text("AirPlay Receiver")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text("Receive screen mirroring from iPhones, iPads, and Macs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            Button(action: { streamManager.startAll() }) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text("Start AirPlay Receiver")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)

            VStack(spacing: 4) {
                Text("Configured for \(settings.streamCount) simultaneous stream\(settings.streamCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if streamManager.pinEnabled {
                    Text("PIN protection enabled — tap Start to begin")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var idleIcon: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 120, height: 120)

            Image(systemName: "airplayvideo")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse, options: .repeating)
        }
    }

    // MARK: - Helper Methods

    private func formatDuration(from start: Date, to end: Date) -> String {
        let duration = Int(end.timeIntervalSince(start))
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}