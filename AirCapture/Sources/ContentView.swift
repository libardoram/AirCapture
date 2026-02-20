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
            HStack {
                Text("AirCapture")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                // Connection count
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                    Text("\(streamManager.activeConnectionCount) / \(streamManager.slots.count)")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                
                // PIN display (if enabled and running)
                if streamManager.isRunning && streamManager.pinEnabled {
                    Divider()
                        .frame(height: 20)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                        
                        Text("PIN:")
                            .font(.caption)
                        
                        Text(streamManager.currentPIN)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(streamManager.currentPIN, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Copy PIN to clipboard")
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.blue)
                    .cornerRadius(6)
                }
                
                // Recording duration (if recording)
                if streamManager.isRecordingActive, let startTime = streamManager.recordingStartTime {
                    Divider()
                        .frame(height: 20)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                        Text(formatDuration(from: startTime, to: currentTime))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                }

                Spacer()

                // Start / Stop button
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
                
                // Record / Stop Recording button (only enabled when running)
                Button(action: {
                    if streamManager.isRecordingActive {
                        streamManager.stopAllRecordings()
                    } else {
                        // Show session name dialog
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
                
                // Settings button
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            // Stream grid
            if streamManager.isRunning {
                ScrollView {
                    StreamGridView(manager: streamManager, selectedSlotForZoom: $selectedSlotForZoom)
                }
            } else {
                // Not started state
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "airplayvideo")
                        .font(.system(size: 64))
                        .foregroundStyle(.tertiary)

                    Text("AirPlay Receiver")
                        .font(.title)
                        .foregroundStyle(.secondary)

                    Text("Click Start to begin receiving AirPlay screen mirroring streams.")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                Spacer()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .overlay {
            // Full-window zoom view overlay
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
