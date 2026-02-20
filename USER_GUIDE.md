# AirCapture User Guide

## Table of Contents
- [Overview](#overview)
- [Getting Started](#getting-started)
- [Main Interface](#main-interface)
- [Recording Sessions](#recording-sessions)
- [Settings](#settings)
- [Security Features](#security-features)
- [File Organization](#file-organization)
- [Tips & Best Practices](#tips--best-practices)
- [Troubleshooting](#troubleshooting)

---

## Overview

**AirCapture** is an AirPlay screen mirroring receiver and recording application for macOS. It allows you to receive and record screen mirroring streams from iOS, iPadOS, and macOS devices that voluntarily connect to your Mac.

### Key Features
- **Multiple Concurrent Streams**: Support for 1-30 simultaneous AirPlay connections
- **High-Quality Recording**: Configurable frame rates and video quality
- **Session Management**: Organized recording sessions with automatic file management
- **PIN Protection**: Optional security with device blocking after failed attempts
- **Smart Storage**: Hidden image folders with automatic video consolidation
- **Connection Logging**: Comprehensive tracking of all connection events

### How It Works
Users voluntarily stream their device screens to your Mac by selecting AirCapture from their device's Screen Mirroring menu. You can view these streams in real-time and optionally record them for later review.

---

## Getting Started

### First Launch

1. **Open AirCapture**
   - The app will show a grid of empty stream slots
   - By default, 4 slots are available (configurable in Settings)

2. **Start the Receivers**
   - Click the **Start** button in the toolbar
   - Each slot becomes a Bonjour service (e.g., "AirCapture-01", "AirCapture-02")
   - These appear in the AirPlay menu on iOS/macOS devices

3. **Users Connect Their Devices** (Voluntary)
   - On iOS/iPhone/iPad: Open Control Center → Screen Mirroring
   - On Mac: Click the Screen Mirroring icon in menu bar
   - User selects "AirCapture-01" (or any available slot)
   - If PIN protection is enabled, user enters the 4-digit PIN shown in your toolbar

4. **View the Stream**
   - The user's device screen appears in the corresponding slot on your Mac
   - A green border indicates an active connection
   - Double-click any stream to view it full-window

---

## Main Interface

### Toolbar

**Left Side:**
- **App Name**: "AirCapture"
- **Connection Counter**: Shows active connections (e.g., "2/4 Connected")
- **PIN Display**: 4-digit PIN code when receivers are running (if enabled)
  - Click the copy button to copy PIN to clipboard

**Right Side:**
- **Recording Timer**: Shows session duration during recording (e.g., "Recording: 00:05:23")
- **Start/Stop Button**: Toggle all AirPlay receivers on/off
- **Record Button**: Start/stop a recording session
- **Settings Button**: Open Settings window (gear icon)

### Stream Grid

- **Adaptive Layout**: Automatically adjusts columns based on stream count
  - 1 stream: 1 column
  - 2-4 streams: 2 columns
  - 5-9 streams: 3 columns
  - 10-16 streams: 4 columns
  - 17-25 streams: 5 columns
  - 26-30 streams: 6 columns

- **Stream Tiles**: Each slot shows:
  - Live video feed (when connected)
  - Stream name (e.g., "AirCapture-01")
  - Connection status (green border when active)
  - Recording indicator (red "REC" badge when recording)
  - "Waiting for connection..." placeholder when empty

### Zoom View

- **Double-click** any stream tile to enter full-window zoom mode
- **Escape key** or **Close button** to exit zoom view
- Displays stream name, device info, and recording status

---

## Recording Sessions

### Starting a Recording

1. Click the **Record** button in the toolbar
2. Enter a **Session Name** (e.g., "Design Review", "Workshop Session", "Team Meeting")
3. Click **Start Recording**
4. All connected streams begin recording immediately
5. New devices that connect during recording will auto-start recording

### During Recording

- **Recording Timer**: Shows elapsed time in toolbar
- **Red REC Badge**: Appears on each recording stream
- **Auto-save**: Video segments are generated automatically every 1-15 minutes (configurable)
- **Continue Working**: Recording happens in the background

### Stopping a Recording

1. Click the **Stop** button in the toolbar
2. Recording stops for all streams
3. Final video consolidation begins automatically
4. Files are saved to your recordings location

### Recording Behavior

- **Auto-start**: New connections during a recording session automatically start recording
- **Auto-stop**: Disconnected devices automatically stop recording
- **Independent Recording**: Each stream records to its own file
- **Video Consolidation**: Multiple video segments are merged into a single file per session

---

## Settings

Access settings by clicking the **gear icon** in the toolbar.

### General Settings

**Number of Streams**
- Range: 1-30 slots
- Default: 4 streams
- **Requires app restart** to take effect
- Higher numbers use more system resources

**Stream Name Prefix**
- Default: "AirCapture"
- Customize what appears in AirPlay menus (e.g., "Workshop", "Studio", "Team")
- Example: "Workshop-01", "Workshop-02"
- Maximum 20 characters (alphanumeric, spaces, hyphens, underscores)
- Click "Reset to Default" to restore "AirCapture"

**Default Session Name**
- Pre-filled name when starting a recording
- Save time by setting common session names

**Recordings Location**
- Default: `~/Documents/AirCapture Recordings`
- Click **Choose...** to select a custom folder
- Click **Show in Finder** to open the recordings folder
- Click **Reset to Default** to restore default location

### Recording Settings

**Snapshot Frame Rate**
- How often the app captures a frame from each stream
- Options: 0.25, 0.5, 1, 2, 5, 10, 20, 30, 50, 60 fps
- Default: 0.2 fps (every 5 seconds)

**Storage Impact Warnings:**
- **Green (0.25-5 fps)**: Low/Normal storage, efficient for long sessions
  - 0.25 fps: ~3 MB/min per stream
  - 5 fps: ~60 MB/min per stream
- **Orange (10-20 fps)**: Moderate storage, good for detailed monitoring
  - 10 fps: ~120 MB/min per stream
  - 20 fps: ~240 MB/min per stream
- **Red (30-60 fps)**: High/Very High storage, only for short critical sessions
  - 30 fps: ~360 MB/min per stream
  - 60 fps: ~720 MB/min per stream

**Video Generation Interval**
- How often to create video segments during recording
- Range: 1-15 minutes
- Default: 5 minutes
- Shorter intervals = more frequent saves (safer) but more processing

**Video Quality Preset**
- **Low**: 1 Mbps, 70% JPEG quality - smallest files
- **Medium**: 2 Mbps, 85% JPEG quality - balanced (default)
- **High**: 4 Mbps, 90% JPEG quality - better quality
- **Ultra High**: 8 Mbps, 95% JPEG quality - best quality, largest files

**Video Playback**
- Videos play back at the captured frame rate
- 0.2 fps recording = 1 frame every 5 seconds playback
- 30 fps recording = smooth real-time playback

### Security Settings

**Enable PIN Protection**
- Toggle on/off
- When enabled, devices must enter a 4-digit PIN to connect

**PIN Code**
- 4-digit number (e.g., 1234)
- Displayed in main window toolbar when receivers are running
- Click **Copy PIN** to copy to clipboard
- Click **Generate New PIN** for a random PIN

**Failed Attempt Blocking**
- Devices are blocked after 3 failed PIN attempts
- Blocked devices cannot reconnect until:
  - You restart the app, or
  - The device successfully connects to a different service

### Advanced Settings

**Video Bit Rate**
- H.264 encoding quality for final videos
- Options: 0.5, 1, 2, 3, 4, 6, 8, 10, 12, 16, 20 Mbps
- Default: 2 Mbps
- Higher = better quality, larger files

**JPEG Quality**
- Compression quality for snapshot images
- Range: 50-100%
- Default: 75%
- Higher = less compression, larger intermediate files

---

## Security Features

### PIN Protection

**How It Works:**
1. Enable PIN protection in Settings → Security
2. Start the receivers
3. PIN appears in the toolbar (e.g., "PIN: 1234")
4. When a device connects, they must enter the PIN
5. Incorrect PIN entry is logged and counted

**Failed Attempts:**
- Each device gets 3 attempts
- After 3 failures, the device is blocked
- Connection logs track all attempts
- Blocked status persists until app restart or successful connection elsewhere

**Best Practices:**
- Share PIN verbally or via secure channel
- Generate a new PIN for each session
- Monitor connection logs for unauthorized attempts

### Connection Logging

**All connection events are logged:**
- Connection attempts (device name, model, ID)
- PIN validation success/failure
- Device blocking events
- Connection/disconnection with duration

**Log Location:**
- `~/Library/Application Support/AirCapture/Logs/`
- Files: `connections_YYYY-MM-DD.log`
- Automatic cleanup after 5 days

**Log Format:**
```
[2026-02-16 14:30:15] ATTEMPT | John's iPhone (iPhone15,2) | ABC123
[2026-02-16 14:30:18] PIN_OK | John's iPhone | ABC123
[2026-02-16 14:30:20] CONNECT | John's iPhone | ABC123
[2026-02-16 14:45:30] DISCONNECT | John's iPhone | ABC123 | Duration: 910.5s
```

---

## File Organization

### Recording Folder Structure

```
~/Documents/AirCapture Recordings/
├── 2026-02-16/
│   ├── Design Review/
│   │   ├── AirCapture-01/
│   │   │   ├── .images/                    (hidden folder, cleared after each segment)
│   │   │   │   ├── 2026-02-16_14-30-00_frame_00001.jpg
│   │   │   │   ├── 2026-02-16_14-30-05_frame_00002.jpg
│   │   │   │   └── ...
│   │   │   └── AirCapture-01_CONSOLIDATED.mp4
│   │   ├── AirCapture-02/
│   │   │   ├── .images/
│   │   │   └── AirCapture-02_CONSOLIDATED.mp4
│   │   └── AirCapture-03/
│   │       └── ...
│   └── Team Meeting/
│       └── ...
└── 2026-02-17/
    └── ...
```

### File Types

**JPEG Snapshots** (`.images/` folder)
- Temporary files during recording
- Hidden from Finder (dot prefix)
- Automatically deleted after video generation
- Named with timestamp and frame number

**MP4 Video Segments**
- Generated every 1-15 minutes during recording
- Immediately merged into `_CONSOLIDATED.mp4` via rolling consolidation
- Deleted after merging — only 1-2 files exist on disk at any time

**Consolidated Video**
- The single output file per stream: `StreamName_CONSOLIDATED.mp4`
- Updated automatically after each segment (rolling consolidation)
- Always contains all footage up to the last consolidation cycle
- Segment files are deleted as they are merged — no accumulation

---

## Tips & Best Practices

### For Long Recording Sessions

 **DO:**
- Use **low frame rates** (0.5-2 fps) to conserve storage
- Set **video generation interval** to 5-10 minutes for safety
- Use **Medium quality** preset (balanced performance/quality)
- Ensure adequate **disk space** (check before starting)
- Use external drive for large recordings

 **DON'T:**
- Use 30-60 fps for sessions longer than 10-15 minutes
- Set generation interval above 10 minutes (risk of data loss)
- Record to a nearly full drive

### For High-Quality Capture

 **DO:**
- Use **10-30 fps** for smooth playback
- Select **High or Ultra High** quality preset
- Use **higher video bit rates** (6-10 Mbps)
- Increase **JPEG quality** to 90-95%
- Ensure fast storage (SSD recommended)

 **DON'T:**
- Exceed 60 fps (diminishing returns)
- Use Ultra High preset for routine recordings

### For Multiple Streams

 **DO:**
- Start with 4 streams and increase as needed
- Monitor system resources (Activity Monitor)
- Use consistent naming for your stream prefix
- Test with 1-2 streams before scaling up

 **DON'T:**
- Start with 30 streams on older Macs
- Mix very different quality settings

### Network Recommendations

 **DO:**
- Use **5 GHz Wi-Fi** or **wired Ethernet** for best performance
- Ensure **strong Wi-Fi signal** for all devices
- Limit other network traffic during recording
- Use a **dedicated access point** for many devices

 **DON'T:**
- Use 2.4 GHz Wi-Fi for more than 2-3 streams
- Record over weak/congested Wi-Fi

---

## Troubleshooting

### Device Can't Find AirCapture

**Problem**: AirPlay menu doesn't show "AirCapture-01"

**Solutions:**
1. Ensure receivers are **started** (click Start button)
2. Check both devices are on the **same Wi-Fi network**
3. Disable **VPN** on either device
4. Restart **both devices**
5. Check **Firewall settings** (allow incoming connections)

### Connection Drops During Recording

**Problem**: Stream disconnects unexpectedly

**Solutions:**
1. Move closer to **Wi-Fi router**
2. Switch to **5 GHz Wi-Fi** or wired Ethernet
3. Reduce **number of active streams**
4. Lower **frame rate** (reduces bandwidth)
5. Close other **bandwidth-heavy apps**

### Low Frame Rate / Stuttering

**Problem**: Video appears choppy or low FPS

**Solutions:**
1. This is **expected** for low snapshot rates (0.5-2 fps)
2. Increase **snapshot frame rate** to 10-30 fps
3. Remember: frame rate ≠ video smoothness, it's snapshot frequency
4. Check **Activity Monitor** for CPU/memory constraints

### Video Files Not Found

**Problem**: Can't find recorded videos

**Solutions:**
1. Check **Settings → General → Recordings Location**
2. Click **Show in Finder** to open recordings folder
3. Look in date folder: `YYYY-MM-DD/SessionName/StreamName/`
4. Videos are generated **after recording stops** (may take minutes)
5. Check **Console.app** logs for errors

### PIN Not Working

**Problem**: Correct PIN is rejected

**Solutions:**
1. Ensure **PIN protection is enabled** in Settings
2. Verify the **PIN shown in toolbar** (not remembered PIN)
3. Check **connection logs** for PIN_FAIL entries
4. Click **Generate New PIN** and try again
5. If device is **blocked**, restart AirCapture

### High Storage Usage

**Problem**: Recordings taking too much space

**Solutions:**
1. Lower **snapshot frame rate** (biggest impact)
2. Reduce **video bit rate** in Advanced settings
3. Use **Low or Medium** quality preset
4. Decrease **JPEG quality** to 60-70%
5. **Delete old recordings** regularly
6. Consider **external storage** for archives

### App Crashes or Freezes

**Problem**: AirCapture becomes unresponsive

**Solutions:**
1. Check **Activity Monitor** (CPU, memory, disk usage)
2. Reduce **number of streams**
3. Lower **frame rate** (reduces processing load)
4. Ensure macOS is **up to date**
5. Try **restarting the app**
6. Check **Console.app** for error logs

### Hidden .images Folder Visible

**Problem**: `.images` folder appears in Finder

**Solutions:**
1. This happens if **Finder shows hidden files** (Cmd+Shift+.)
2. The folder is **automatically deleted** after recording stops
3. Don't manually delete during recording
4. Toggle hidden files off: **Cmd+Shift+.** again

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **Escape** | Close zoom view or settings window |
| **Return** | Confirm settings (when Settings window is focused) |
| **Cmd+Shift+.** | Toggle hidden files in Finder (macOS default) |
| **Double-click stream** | Enter full-window zoom mode |

---

## System Requirements

- **macOS**: 15.0 (Sequoia) or later
- **Processor**: Apple Silicon (M1 or later) — Intel is not supported
- **Memory**: 8 GB RAM minimum, 16 GB recommended for 8+ streams
- **Storage**: SSD recommended for smooth recording
- **Network**: Wi-Fi 5 GHz or Ethernet recommended for multiple streams

---

## Support & Feedback

### Logs for Debugging

**Connection Logs:**
- Location: `~/Library/Application Support/AirCapture/Logs/`
- Contains: All connection events, PIN attempts, errors

**System Logs:**
- Open **Console.app**
- Search for: "com.aircapture.AirCapture"
- Contains: Detailed app operations and errors

**Share when reporting issues:**
1. Connection log files
2. Console.app filtered logs
3. Steps to reproduce
4. macOS version and Mac model

---

## Version Information

**Current Version**: 1.3  
**Last Updated**: February 2026

---

## Quick Reference Card

### Common Tasks

| Task | Steps |
|------|-------|
| **Start receiving** | Click **Start** in toolbar |
| **Connect device** | Open Screen Mirroring → Select "AirCapture-XX" |
| **Start recording** | Click **Record** → Enter session name → Start |
| **Stop recording** | Click **Stop** |
| **Zoom stream** | Double-click stream tile |
| **Copy PIN** | Click copy button next to PIN in toolbar |
| **Change settings** | Click gear icon → Modify → Done |
| **Find recordings** | Settings → General → Show in Finder |

### Default Settings

| Setting | Default Value |
|---------|---------------|
| Number of Streams | 4 |
| Stream Name Prefix | "AirCapture" |
| Snapshot Frame Rate | 0.2 fps (every 5 seconds) |
| Video Generation Interval | 5 minutes |
| Video Quality Preset | Medium (2 Mbps, 85% JPEG) |
| PIN Protection | Disabled |
| Recordings Location | ~/Documents/AirCapture Recordings |

---

**Thank you for using AirCapture!**
