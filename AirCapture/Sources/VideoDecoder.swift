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
import VideoToolbox
import CoreMedia
import os.log

// MARK: - VideoDecoder

/// Decodes H.264 (or H.265) NAL units from the AirPlay stream into CVPixelBuffers
/// using Apple's VideoToolbox hardware decoder.
///
/// Usage:
/// 1. Feed raw NAL unit data from `video_decode_struct.data` via `decode(nalData:...)`.
/// 2. The decoder extracts SPS/PPS, creates a `CMVideoFormatDescription`, and sets up
///    a `VTDecompressionSession` on first keyframe.
/// 3. Decoded frames are delivered to the `delegate`.
final class VideoDecoder {

    // MARK: - Delegate

    protocol Delegate: AnyObject {
        /// Called on a background thread when a frame is decoded.
        func decoder(_ decoder: VideoDecoder, didDecode pixelBuffer: CVPixelBuffer, presentationTime: CMTime)
    }

    // MARK: - Properties

    weak var delegate: Delegate?

    private var formatDescription: CMVideoFormatDescription?
    private var decompressionSession: VTDecompressionSession?

    private var spsData: Data?
    private var ppsData: Data?

    private var isH265 = false

    private static let logger = Logger(subsystem: "com.aircapture.AirCapture", category: "VideoDecoder")

    // MARK: - Public API

    /// Get cached SPS/PPS data for feeding to recorder when it starts mid-stream.
    /// Returns nil if SPS/PPS haven't been received yet.
    func getCachedParameterSets() -> (sps: Data, pps: Data)? {
        guard let sps = spsData, let pps = ppsData else { return nil }
        return (sps, pps)
    }

    /// Set the codec type. Called when `video_set_codec` callback fires.
    func setCodec(isH265: Bool) {
        if self.isH265 != isH265 {
            Self.logger.info("Codec set to \(isH265 ? "H.265" : "H.264")")
            self.isH265 = isH265
            // Reset session when codec changes
            tearDown()
        }
    }

    /// Decode raw NAL unit data from the AirPlay stream.
    ///
    /// The `nalData` pointer contains one or more NAL units in Annex-B format
    /// (start codes: 0x00 0x00 0x00 0x01 or 0x00 0x00 0x01).
    ///
    /// - Parameters:
    ///   - nalData: Raw NAL data buffer (Annex-B format from UxPlay).
    ///   - nalCount: Number of NAL units in the buffer.
    ///   - ntpTimeLocal: Local NTP timestamp.
    func decode(nalData: UnsafeBufferPointer<UInt8>, nalCount: Int, ntpTimeLocal: UInt64) {
        guard nalData.count > 0 else { return }

        // Parse NAL units from Annex-B stream
        let nalUnits = parseAnnexB(nalData)

        for nalUnit in nalUnits {
            guard nalUnit.count > 0 else { continue }
            // ArraySlice preserves parent array indices, so use startIndex instead of [0]
            let firstByte = nalUnit[nalUnit.startIndex]
            let nalType: UInt8
            if isH265 {
                nalType = (firstByte >> 1) & 0x3F  // H.265 NAL type
            } else {
                nalType = firstByte & 0x1F          // H.264 NAL type
            }

            if isH265 {
                handleH265NAL(type: nalType, data: nalUnit, ntpTimeLocal: ntpTimeLocal)
            } else {
                handleH264NAL(type: nalType, data: nalUnit, ntpTimeLocal: ntpTimeLocal)
            }
        }
    }

    /// Tear down the decoder session and release resources.
    func tearDown() {
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
            decompressionSession = nil
        }
        formatDescription = nil
        spsData = nil
        ppsData = nil
    }

    deinit {
        tearDown()
    }

    // MARK: - H.264 NAL Handling

    private func handleH264NAL(type: UInt8, data: ArraySlice<UInt8>, ntpTimeLocal: UInt64) {
        switch type {
        case 7: // SPS
            spsData = Data(data)
            Self.logger.debug("Got H.264 SPS (\(data.count) bytes)")

        case 8: // PPS
            ppsData = Data(data)
            Self.logger.debug("Got H.264 PPS (\(data.count) bytes)")

            // Try to create format description once we have both
            if spsData != nil {
                createH264FormatDescription()
            }

        case 5: // IDR (keyframe)
            if decompressionSession == nil && spsData != nil && ppsData != nil {
                createH264FormatDescription()
            }
            if decompressionSession != nil {
                decodeNALUnit(data: data, ntpTimeLocal: ntpTimeLocal)
            }

        case 1: // Non-IDR (P/B frame)
            if decompressionSession != nil {
                decodeNALUnit(data: data, ntpTimeLocal: ntpTimeLocal)
            }

        default:
            break
        }
    }

    // MARK: - H.265 NAL Handling

    private func handleH265NAL(type: UInt8, data: ArraySlice<UInt8>, ntpTimeLocal: UInt64) {
        // H.265 NAL types: VPS=32, SPS=33, PPS=34, IDR_W_RADL=19, IDR_N_LP=20, TRAIL_R=1
        switch type {
        case 32: // VPS — needed for H.265 but we store it with SPS
            // For H.265, we'd need VPS+SPS+PPS. Simplified: store VPS as part of SPS.
            spsData = Data(data)
            Self.logger.debug("Got H.265 VPS (\(data.count) bytes)")

        case 33: // SPS
            // Append to VPS if we have it
            if var existing = spsData {
                // Store VPS separately, this is the real SPS
                existing.append(contentsOf: data)
                spsData = existing
            } else {
                spsData = Data(data)
            }
            Self.logger.debug("Got H.265 SPS (\(data.count) bytes)")

        case 34: // PPS
            ppsData = Data(data)
            Self.logger.debug("Got H.265 PPS (\(data.count) bytes)")

        case 19, 20: // IDR
            if decompressionSession != nil {
                decodeNALUnit(data: data, ntpTimeLocal: ntpTimeLocal)
            }

        case 1: // TRAIL_R (non-IDR)
            if decompressionSession != nil {
                decodeNALUnit(data: data, ntpTimeLocal: ntpTimeLocal)
            }

        default:
            break
        }
    }

    // MARK: - Format Description Creation

    private func createH264FormatDescription() {
        guard let spsData, let ppsData else { return }

        let spsArray = [UInt8](spsData)
        let ppsArray = [UInt8](ppsData)

        var formatDesc: CMVideoFormatDescription?

        let status = spsArray.withUnsafeBufferPointer { spsBuf in
            ppsArray.withUnsafeBufferPointer { ppsBuf in
                let paramSets: [UnsafePointer<UInt8>] = [spsBuf.baseAddress!, ppsBuf.baseAddress!]
                let paramSetSizes: [Int] = [spsArray.count, ppsArray.count]
                return paramSets.withUnsafeBufferPointer { setsBuf in
                    paramSetSizes.withUnsafeBufferPointer { sizesBuf in
                        CMVideoFormatDescriptionCreateFromH264ParameterSets(
                            allocator: kCFAllocatorDefault,
                            parameterSetCount: 2,
                            parameterSetPointers: setsBuf.baseAddress!,
                            parameterSetSizes: sizesBuf.baseAddress!,
                            nalUnitHeaderLength: 4,
                            formatDescriptionOut: &formatDesc
                        )
                    }
                }
            }
        }

        guard status == noErr, let formatDesc else {
            Self.logger.error("Failed to create H.264 format description: \(status)")
            return
        }

        self.formatDescription = formatDesc
        createDecompressionSession()
    }

    // MARK: - Decompression Session

    private func createDecompressionSession() {
        guard let formatDescription else { return }

        // Tear down existing session
        if let existing = decompressionSession {
            VTDecompressionSessionInvalidate(existing)
            decompressionSession = nil
        }

        // Output pixel buffer attributes
        let pixelBufferAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]

        var session: VTDecompressionSession?
        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDescription,
            decoderSpecification: nil,
            imageBufferAttributes: pixelBufferAttrs as CFDictionary,
            outputCallback: nil,
            decompressionSessionOut: &session
        )

        guard status == noErr, let session else {
            Self.logger.error("Failed to create VTDecompressionSession: \(status)")
            return
        }

        // Set real-time decoding
        VTSessionSetProperty(session, key: kVTDecompressionPropertyKey_RealTime, value: kCFBooleanTrue)

        decompressionSession = session
        Self.logger.info("VTDecompressionSession created successfully")
    }

    // MARK: - Decoding

    private func decodeNALUnit(data: ArraySlice<UInt8>, ntpTimeLocal: UInt64) {
        guard let session = decompressionSession, let formatDescription else { return }

        // Convert Annex-B NAL to AVCC format: replace start code with 4-byte length prefix
        let nalLength = UInt32(data.count)
        var avccData = Data(count: 4 + data.count)
        avccData[0] = UInt8((nalLength >> 24) & 0xFF)
        avccData[1] = UInt8((nalLength >> 16) & 0xFF)
        avccData[2] = UInt8((nalLength >> 8) & 0xFF)
        avccData[3] = UInt8(nalLength & 0xFF)
        avccData.replaceSubrange(4..<(4 + data.count), with: data)

        let avccDataCount = avccData.count

        // Create block buffer
        var blockBuffer: CMBlockBuffer?
        avccData.withUnsafeMutableBytes { rawBuf in
            guard let baseAddress = rawBuf.baseAddress else { return }
            let status = CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: nil,
                blockLength: avccDataCount,
                blockAllocator: kCFAllocatorDefault,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: avccDataCount,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
            guard status == kCMBlockBufferNoErr, let bb = blockBuffer else { return }
            CMBlockBufferReplaceDataBytes(
                with: baseAddress,
                blockBuffer: bb,
                offsetIntoDestination: 0,
                dataLength: avccDataCount
            )
        }

        guard let blockBuffer else { return }

        // Create sample buffer
        var sampleBuffer: CMSampleBuffer?
        var sampleSize = avccDataCount
        let status = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 0,
            sampleTimingArray: nil,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )

        guard status == noErr, let sampleBuffer else {
            Self.logger.error("Failed to create CMSampleBuffer: \(status)")
            return
        }

        // Decode
        let presentationTime = CMTimeMake(value: Int64(ntpTimeLocal), timescale: 1_000_000_000)

        VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sampleBuffer,
            flags: [._EnableAsynchronousDecompression],
            infoFlagsOut: nil
        ) { [weak self] status, infoFlags, imageBuffer, presentationTimeStamp, presentationDuration in
            guard status == noErr,
                  let self,
                  let pixelBuffer = imageBuffer else {
                return
            }
            self.delegate?.decoder(self, didDecode: pixelBuffer, presentationTime: presentationTime)
        }
    }

    // MARK: - Annex-B Parser

    /// Parse an Annex-B byte stream into individual NAL units (without start codes).
    private func parseAnnexB(_ buffer: UnsafeBufferPointer<UInt8>) -> [ArraySlice<UInt8>] {
        let bytes = Array(buffer)
        var nalUnits: [ArraySlice<UInt8>] = []
        var i = 0
        let count = bytes.count

        while i < count {
            // Find start code: 0x00 0x00 0x01 or 0x00 0x00 0x00 0x01
            var startCodeLen = 0
            if i + 2 < count && bytes[i] == 0 && bytes[i+1] == 0 && bytes[i+2] == 1 {
                startCodeLen = 3
            } else if i + 3 < count && bytes[i] == 0 && bytes[i+1] == 0 && bytes[i+2] == 0 && bytes[i+3] == 1 {
                startCodeLen = 4
            }

            if startCodeLen > 0 {
                let nalStart = i + startCodeLen
                // Find next start code or end of buffer
                var nalEnd = count
                var j = nalStart + 1
                while j + 2 < count {
                    if bytes[j] == 0 && bytes[j+1] == 0 {
                        if bytes[j+2] == 1 {
                            nalEnd = j
                            break
                        } else if j + 3 < count && bytes[j+2] == 0 && bytes[j+3] == 1 {
                            nalEnd = j
                            break
                        }
                    }
                    j += 1
                }
                if nalStart < nalEnd {
                    nalUnits.append(bytes[nalStart..<nalEnd])
                }
                i = nalEnd
            } else {
                i += 1
            }
        }

        return nalUnits
    }
}
