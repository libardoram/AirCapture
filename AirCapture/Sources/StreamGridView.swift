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
import AppKit
import CoreVideo

// MARK: - StreamGridView

/// Displays all stream slots in an adaptive grid layout.
/// Each tile shows either the live video feed or a "waiting" placeholder.
struct StreamGridView: View {
    @ObservedObject var manager: StreamManager
    @Binding var selectedSlotForZoom: StreamSlot?

    private var columns: [GridItem] {
        let count = manager.slots.count
        let cols: Int
        switch count {
        case 1: cols = 1
        case 2...4: cols = 2
        case 5...9: cols = 3
        case 10...16: cols = 4
        case 17...25: cols = 5
        default: cols = 6
        }
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: cols)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(manager.slots) { slot in
                StreamTileView(slot: slot)
                    .onTapGesture(count: 2) {
                        selectedSlotForZoom = slot
                    }
            }
        }
        .padding(8)
    }
}

// MARK: - StreamTileView

/// A single tile in the grid, showing either live video or a waiting state.
struct StreamTileView: View {
    @ObservedObject var slot: StreamSlot
    @State private var isHovered = false

    var body: some View {
        ZStack {
            // Background
            Color.black

            if slot.isConnected, slot.latestPixelBuffer != nil {
                PixelBufferView(pixelBuffer: slot.latestPixelBuffer)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
            } else {
                waitingStateView
            }

            // Overlay badges
            VStack {
                HStack(spacing: 4) {
                    // Slot number badge
                    Text("\(slot.id + 1)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(4)

                    if slot.isRecording {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.red)
                                .frame(width: 6, height: 6)
                            Text("REC")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.red.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(4)
                    }

                    Spacer()
                }

                Spacer()

                HStack {
                    Spacer()
                    // Connection status badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text(slot.clientName)
                            .font(.caption2)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(6)
                }
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    slot.isConnected ? Color.green.opacity(0.7) : Color.white.opacity(0.12),
                    lineWidth: slot.isConnected ? 1.5 : 1
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var waitingStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: slot.isConnected ? "airplayaudio" : "airplayvideo")
                .font(.system(size: 40))
                .foregroundStyle(slot.isConnected ? .green : .white.opacity(0.35))
                .symbolEffect(.pulse, options: .repeating, value: slot.isConnected)

            Text(slot.serviceName.isEmpty ? "Stream \(slot.id + 1)" : slot.serviceName)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))

            if slot.isConnected {
                Text(slot.clientName)
                    .font(.caption)
                    .foregroundStyle(.green.opacity(0.8))
            } else {
                Text("Waiting for connection...")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }
}

// MARK: - PixelBufferView

/// Renders a CVPixelBuffer using an NSView backed by a CALayer.
/// This is an efficient way to display decoded video frames on macOS.
struct PixelBufferView: NSViewRepresentable {
    let pixelBuffer: CVPixelBuffer?

    func makeNSView(context: Context) -> PixelBufferNSView {
        let view = PixelBufferNSView()
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: PixelBufferNSView, context: Context) {
        nsView.updatePixelBuffer(pixelBuffer)
    }
}

/// NSView that draws a CVPixelBuffer into its layer.
final class PixelBufferNSView: NSView {

    private var ciContext = CIContext()

    override var isFlipped: Bool { true }

    override func makeBackingLayer() -> CALayer {
        let layer = CALayer()
        layer.contentsGravity = .resizeAspect
        layer.backgroundColor = NSColor.black.cgColor
        return layer
    }

    func updatePixelBuffer(_ pixelBuffer: CVPixelBuffer?) {
        guard let pixelBuffer else {
            layer?.contents = nil
            return
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer?.contents = cgImage
            CATransaction.commit()
        }
    }
}