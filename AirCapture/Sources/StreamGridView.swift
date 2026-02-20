import SwiftUI
import AppKit
import CoreVideo

// MARK: - StreamGridView

/// Displays all stream slots in an adaptive grid layout.
/// Each tile shows either the live video feed or a "waiting" placeholder.
struct StreamGridView: View {
    @ObservedObject var manager: StreamManager
    @Binding var selectedSlotForZoom: StreamSlot?

    /// Number of columns adapts based on slot count.
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
        return Array(repeating: GridItem(.flexible(), spacing: 2), count: cols)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(manager.slots) { slot in
                StreamTileView(slot: slot)
                    .onTapGesture(count: 2) {
                        // Double-click to show fullscreen
                        selectedSlotForZoom = slot
                    }
            }
        }
        .padding(2)
    }
}

// MARK: - StreamTileView

/// A single tile in the grid, showing either live video or a waiting state.
struct StreamTileView: View {
    @ObservedObject var slot: StreamSlot

    var body: some View {
        ZStack {
            // Background
            Color.black

            if slot.isConnected, slot.latestPixelBuffer != nil {
                // Live video display
                PixelBufferView(pixelBuffer: slot.latestPixelBuffer)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
            } else {
                // Waiting state
                VStack(spacing: 8) {
                    Image(systemName: slot.isConnected ? "airplayaudio" : "airplayvideo")
                        .font(.system(size: 32))
                        .foregroundStyle(slot.isConnected ? .green : .secondary)

                    Text(slot.serviceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if slot.isConnected {
                        Text(slot.clientName)
                            .font(.caption2)
                            .foregroundStyle(.green)
                    } else {
                        Text("Waiting for connection...")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Overlay: connection info badge and recording indicator
            if slot.isConnected {
                VStack {
                    HStack {
                        // Recording indicator (top-left)
                        if slot.isRecording {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 8, height: 8)
                                Text("REC")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.red.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(4)
                        }
                        
                        Spacer()
                        
                        // Connection status (top-right)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text(slot.clientName)
                                .font(.caption2)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(4)
                    }
                    Spacer()
                }
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(slot.isConnected ? Color.green.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
        )
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
        
        // CRITICAL: Lock pixel buffer before accessing its memory to prevent crashes
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        
        // Convert CVPixelBuffer to CGImage via CIImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer?.contents = cgImage
            CATransaction.commit()
        }
    }
}
