# AirCapture

**AirPlay Screen Mirroring Receiver & Recording Application for macOS**

AirCapture allows you to receive and record multiple AirPlay screen mirroring streams simultaneously on a single Mac. Users voluntarily stream their iOS, iPadOS, or macOS devices to your Mac for monitoring, recording, or display purposes.

![macOS](https://img.shields.io/badge/macOS-15.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

##  Features

### Core Capabilities
-  **Multiple Simultaneous Streams** - Support for 1-30 concurrent AirPlay connections
-  **High-Quality Recording** - Configurable frame rates (0.25-60 fps) with smart storage warnings
-  **PIN Protection** - Optional 4-digit PIN with automatic device blocking after failed attempts
-  **Adaptive Grid Layout** - Automatically adjusts columns based on number of active streams
-  **Full-Window Zoom** - Double-click any stream for detailed view
-  **Session Management** - Organized recordings by date and session name
-  **Connection Logging** - Comprehensive tracking of all connection events

### Recording Features
- **Snapshot-based recording** with configurable intervals
- **Automatic video consolidation** for long sessions
- **Hidden intermediate files** (`.images` folders)
- **Multiple quality presets** (Low, Medium, High, Ultra High)
- **Smart storage warnings** based on frame rate and stream count
- **Independent per-stream recording** with automatic start/stop

### Security & Monitoring
- **PIN authentication** with failed attempt tracking
- **Device blocking** after 3 failed PIN attempts
- **Connection logs** with timestamps and device details
- **Auto-cleanup** of old logs (5-day retention)

---

##  Requirements

- **macOS**: 15.0 (Sequoia) or later
- **Processor**: Apple Silicon (M1/M2/M3) or Intel with hardware H.264 encoding
- **Memory**: 8 GB RAM minimum, 16 GB recommended for 8+ streams
- **Storage**: SSD recommended for smooth recording
- **Network**: 5 GHz Wi-Fi or Ethernet recommended for multiple streams

---

##  Quick Start

### Installation

1. Download the latest release
2. Move `AirCapture.app` to your Applications folder
3. Launch AirCapture

### First Use

1. **Start the Receivers**
   - Click the **Start** button in the toolbar
   - AirCapture services appear in AirPlay menus (e.g., "AirCapture-01", "AirCapture-02")

2. **Users Connect Their Devices** (Voluntary)
   - **iOS/iPadOS**: Control Center → Screen Mirroring → Select "AirCapture-01"
   - **macOS**: Menu bar → Screen Mirroring → Select "AirCapture-01"
   - Users enter PIN if prompted (their device screen is now streaming to your Mac)

3. **Start Recording** (Optional)
   - Click **Record** button
   - Enter session name
   - Click **Start Recording**

4. **Access Recordings**
   - Settings → General → **Show in Finder**
   - Default: `~/Documents/AirCapture Recordings/`

For detailed instructions, see the [Quick Start Guide](QUICK_START.md).

---

##  Documentation

- **[Quick Start Guide](QUICK_START.md)** - Get up and running in 5 minutes
- **[User Guide](USER_GUIDE.md)** - Comprehensive documentation covering:
  - Main interface overview
  - Recording sessions
  - All settings explained
  - Security features
  - File organization
  - Tips & best practices
  - Troubleshooting

---

##  Use Cases

### Education & Training
- **Contest Proctoring** - Educators can monitor participants and keep evidence during competitions
- **Classroom Demonstrations** - Display multiple student devices simultaneously
- **Training Sessions** - Monitor trainee progress and provide real-time feedback
- **Remote Teaching** - Record student presentations for review

### Professional & Business
- **Design Reviews** - Review team progress on multiple devices in real-time
- **Quality Assurance** - Test apps across multiple devices simultaneously
- **Client Demonstrations** - Show work from multiple team members' devices
- **Workshops & Presentations** - Capture all participant screens for later review

### Personal & Creative
- **Multi-device Recording** - Record from multiple iOS/iPad devices at once
- **Family Sharing** - Display photos/videos on big screen from multiple devices
- **Gaming** - Record multiple players' perspectives simultaneously
- **Creative Projects** - Collaborate and review work across multiple devices

---

##  Key Settings

### General
- **Number of Streams**: 1-30 concurrent connections (default: 4)
- **Stream Name Prefix**: Customize AirPlay service names (default: "AirCapture")
- **Recordings Location**: Choose where to save recordings

### Recording
- **Snapshot Frame Rate**: 0.25-60 fps with storage warnings
- **Video Generation Interval**: 1-15 minutes between segments
- **Video Quality Preset**: Low/Medium/High/Ultra High
- **JPEG Quality**: 50-100% compression

### Security
- **PIN Protection**: Optional 4-digit authentication
- **Failed Attempt Blocking**: Automatic device blocking after 3 failures

### Advanced
- **Video Bit Rate**: 0.5-20 Mbps for H.264 encoding
- **JPEG Quality**: Fine-tune snapshot compression

---

##  File Organization

Recordings are organized by date and session:

```
~/Documents/AirCapture Recordings/
├── 2026-02-16/
│   ├── Design Review/
│   │   ├── AirCapture-01/
│   │   │   ├── .images/                              (hidden, auto-deleted)
│   │   │   └── AirCapture-01_CONSOLIDATED.mp4       (final video)
│   │   ├── AirCapture-02/
│   │   │   └── AirCapture-02_CONSOLIDATED.mp4
│   │   └── ...
│   └── Team Session/
│       └── ...
└── ...
```

**Logs**: `~/Library/Application Support/AirCapture/Logs/`

---

##  Pro Tips

### For Best Performance
 Use 5 GHz Wi-Fi or wired Ethernet  
 Start with 2-4 streams before scaling up  
 Keep devices close to the Wi-Fi router  

### For Long Sessions
 Use low frame rates (0.5-2 fps) to conserve storage  
 Default 1 fps ≈ 12 MB/min per stream  
 Set video generation interval to 5-10 minutes  

### For High Quality
 Increase frame rate to 10-30 fps  
 Use High or Ultra High quality preset  
 Ensure adequate disk space (check before starting)  

---

##  Building from Source

### Prerequisites

- Xcode 15.0 or later
- macOS 15.0 SDK
- Dependencies in `/vendor/uxplay/`

### Build Steps

```bash
# Clone the repository
git clone https://github.com/yourusername/AirCapture.git
cd AirCapture

# Build with Xcode
cd AirCapture
xcodebuild -project AirCapture.xcodeproj \
  -scheme AirCapture \
  -configuration Release \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO

# Run the app
open build/Release/AirCapture.app
```

### Project Structure

```
AirCapture/
├── AirCapture.xcodeproj/        # Xcode project
├── Sources/                     # Swift source files
│   ├── AirCaptureApp.swift     # App entry point
│   ├── ContentView.swift       # Main UI
│   ├── StreamManager.swift     # Stream orchestration
│   ├── AirPlayReceiver.swift   # UxPlay wrapper
│   ├── VideoDecoder.swift      # H.264 decoding
│   ├── SnapshotRecorder.swift  # Recording engine
│   ├── SettingsView.swift      # Settings UI
│   └── ...
├── vendor/                     # Third-party libraries
│   └── uxplay/                 # AirPlay server library
└── ...
```

---

##  Technologies Used

- **SwiftUI** - Modern declarative UI framework
- **AVFoundation** - Video encoding/decoding
- **Combine** - Reactive state management
- **UxPlay** - Open-source AirPlay server implementation
- **Bonjour/mDNS** - Service discovery
- **os.log** - System logging framework

---

##  Troubleshooting

### Common Issues

**Device can't find AirCapture**
- Ensure both devices are on the same Wi-Fi network
- Check firewall settings (allow incoming connections)
- Restart both devices

**Connection drops during recording**
- Move closer to Wi-Fi router
- Switch to 5 GHz Wi-Fi or wired Ethernet
- Reduce number of active streams or lower frame rate

**High storage usage**
- Lower snapshot frame rate (biggest impact)
- Use Low or Medium quality preset
- Check Settings → Recording for storage warnings

See the [User Guide](USER_GUIDE.md#troubleshooting) for detailed troubleshooting.

---

##  Storage Examples

| Scenario | Frame Rate | Duration | Streams | Total Size |
|----------|-----------|----------|---------|------------|
| Short session | 1 fps | 1 hour | 4 | ~2.9 GB |
| Long session | 0.5 fps | 3 hours | 4 | ~4.3 GB |
| High quality | 10 fps | 30 min | 2 | ~3.6 GB |
| Many streams | 2 fps | 2 hours | 10 | ~28.8 GB |

*Based on Medium quality preset (2 Mbps, 75% JPEG)*

---

##  Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Swift API Design Guidelines
- Add documentation for public APIs
- Test with multiple streams before submitting
- Update USER_GUIDE.md for user-facing changes

---

##  License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

##  Acknowledgments

- **UxPlay** - Open-source AirPlay server implementation
- **OpenSSL** - Cryptographic library
- **libplist** - Apple property list handling

---

##  Support

### Getting Help

- Read the [User Guide](USER_GUIDE.md)
- Check [Troubleshooting](USER_GUIDE.md#troubleshooting)
- Review [Quick Start Guide](QUICK_START.md)

### Reporting Issues

When reporting bugs, please include:
- macOS version and Mac model
- Number of streams and frame rate
- Steps to reproduce
- Connection logs (`~/Library/Application Support/AirCapture/Logs/`)
- Console.app logs (filter: "com.aircapture.AirCapture")

---

##  Roadmap

### Planned Features
- [ ] Audio recording support
- [ ] Custom stream labels/names
- [ ] Recording start/stop per stream
- [ ] Export quality presets
- [ ] Keyboard shortcuts
- [ ] Dark mode improvements
- [ ] Performance metrics dashboard

### Under Consideration
- [ ] Cloud backup integration
- [ ] Real-time annotations
- [ ] Stream switching/reordering
- [ ] Multi-window support
- [ ] Network statistics display

---

##  Related Documentation

- [Product Requirements Document](PRD.md) - Original vision and technical architecture
- [Quick Start Guide](QUICK_START.md) - 5-minute setup guide
- [User Guide](USER_GUIDE.md) - Complete feature documentation

---

**Made with  for anyone who needs to receive multiple AirPlay streams**

*AirCapture - Receive, Monitor, Record*
