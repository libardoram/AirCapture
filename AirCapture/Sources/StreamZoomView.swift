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

// MARK: - StreamZoomView

/// Full-screen zoom view for a single stream.
struct StreamZoomView: View {
    @ObservedObject var slot: StreamSlot
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Video content
            if slot.isConnected, slot.latestPixelBuffer != nil {
                PixelBufferView(pixelBuffer: slot.latestPixelBuffer)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
            } else {
                // Not connected state
                VStack(spacing: 16) {
                    Image(systemName: slot.isConnected ? "airplayaudio" : "airplayvideo")
                        .font(.system(size: 64))
                        .foregroundStyle(slot.isConnected ? .green : .secondary)
                    
                    Text(slot.serviceName)
                        .font(.title)
                        .foregroundStyle(.secondary)
                    
                    if slot.isConnected {
                        Text(slot.clientName)
                            .font(.headline)
                            .foregroundStyle(.green)
                    } else {
                        Text("Waiting for connection...")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            // Overlay: header with info and controls
            VStack {
                HStack {
                    // Stream info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(slot.serviceName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        if slot.isConnected {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 8, height: 8)
                                Text(slot.clientName)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                                if !slot.clientModel.isEmpty {
                                    Text("•")
                                        .foregroundStyle(.white.opacity(0.5))
                                    Text(slot.clientModel)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Spacer()
                    
                    // Recording indicator
                    if slot.isRecording {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.red)
                                .frame(width: 10, height: 10)
                            Text("RECORDING")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.red.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Spacer()
                    
                    // Close button
                    Button(action: {
                        isPresented = false
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                            Text("Close")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(16)
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
