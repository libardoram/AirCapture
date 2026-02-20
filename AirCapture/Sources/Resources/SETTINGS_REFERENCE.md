# AirCapture Settings Reference

Quick reference for all available settings and their effects.

---

## General Settings

### Number of Streams
- **Range**: 1 to 30
- **Default**: 4
- **Effect**: Number of concurrent AirPlay receiver slots
- **Requires**: App restart to take effect
- **Notes**: Higher numbers use more system resources

### Stream Name Prefix
- **Default**: "AirCapture"
- **Format**: Alphanumeric, spaces, hyphens, underscores (max 20 chars)
- **Effect**: Appears in AirPlay menus (e.g., "Workshop-01")
- **Example**: Change to "Studio" → "Studio-01", "Studio-02", etc.
- **Validation**: Live character count and example preview
- **Reset**: Button to restore default "AirCapture"

### Default Session Name
- **Type**: Text input
- **Effect**: Pre-filled name when starting recordings
- **Example**: "Design Review", "Team Meeting", "Workshop Session"
- **Notes**: Saves time for recurring sessions

### Recordings Location
- **Default**: `~/Documents/AirCapture Recordings`
- **Options**: 
  - **Choose...** - Browse for custom folder
  - **Show in Finder** - Open current location
  - **Reset to Default** - Restore default path
- **Display**: Shows path with `~/` abbreviation
- **Effect**: Where all recordings are saved

---

## Recording Settings

### Snapshot Frame Rate
- **Options**: 0.25, 0.5, 1, 2, 5, 10, 20, 30, 50, 60 fps
- **Default**: 0.2 fps (every 5 seconds)
- **Display**: Shows both fps and time equivalent
  - 0.25 fps = "Every 4 seconds"
  - 1 fps = "Every second"
  - 30 fps = "30 times per second"

**Storage Impact Warnings:**

| Frame Rate | Warning | Storage/min/stream | Use Case |
|------------|---------|-------------------|----------|
| 0.2 fps |  Low | ~2.4 MB | **Default** — very long sessions (8+ hours) |
| 0.25 fps |  Low | ~3 MB | Very long sessions (4+ hours) |
| 0.5 fps |  Low | ~6 MB | Long sessions (2-4 hours) |
| 1 fps |  Normal | ~12 MB | Standard monitoring |
| 2 fps |  Normal | ~24 MB | Standard with detail |
| 5 fps |  Normal | ~60 MB | Detailed monitoring |
| 10 fps |  Moderate | ~120 MB | Good detail (1 hour max) |
| 20 fps |  Moderate | ~240 MB | High detail (30 min max) |
| 30 fps |  High | ~360 MB | Very high quality (short only) |
| 50 fps |  Very High | ~600 MB | Professional quality (10 min max) |
| 60 fps |  Very High | ~720 MB | Maximum quality (5 min max) |

**Example for 4 streams:**
- 0.2 fps for 1 hour = ~0.6 GB total
- 30 fps for 1 hour = ~86.4 GB total

### Video Generation Interval
- **Range**: 1 to 15 minutes
- **Default**: 5 minutes
- **Effect**: How often to create video segments during recording
- **Recommendations**:
  - **1-3 minutes**: Safer (frequent saves) but more processing
  - **5-10 minutes**: Balanced (default recommended)
  - **10-15 minutes**: Less processing, higher risk if crash

### Video Quality Preset
- **Options**:
  - **Low**: 1 Mbps, 70% JPEG - smallest files
  - **Medium**: 2 Mbps, 85% JPEG - balanced (default)
  - **High**: 4 Mbps, 90% JPEG - better quality
  - **Ultra High**: 8 Mbps, 95% JPEG - best quality
- **Effect**: Sets both video bit rate and JPEG quality
- **Notes**: Can fine-tune in Advanced settings

**Storage Impact:**
- Low: 7.5 MB/min per stream
- Medium: 15 MB/min per stream
- High: 30 MB/min per stream
- Ultra High: 60 MB/min per stream

### Video Playback
- **Effect**: Videos play back at the same frame rate they were captured
- **Examples**:
  - 1 fps recording = 1 frame per second playback
  - 30 fps recording = 30 fps playback (smooth real-time)
- **Notes**: This is informational, not a setting

---

## Security Settings

### Enable PIN Protection
- **Type**: Toggle (on/off)
- **Default**: Off
- **Effect**: Requires 4-digit PIN for AirPlay connections
- **Display**: PIN shown in main window toolbar when receivers running

### PIN Code
- **Format**: 4-digit number (0000-9999)
- **Default**: Random on first launch
- **Options**:
  - Manual entry with validation
  - **Copy PIN** - Copy to clipboard
  - **Generate New PIN** - Random 4-digit PIN
- **Validation**: Must be exactly 4 digits

### Failed Attempts
- **Behavior**: Automatic (not a setting)
- **Tracking**: 3 attempts per device
- **Blocking**: After 3 failures, device is blocked
- **Reset**: 
  - Restart app, or
  - Device successfully connects elsewhere
- **Logging**: All attempts logged

---

## Advanced Settings

### Video Bit Rate
- **Options**: 0.5, 1, 2, 3, 4, 6, 8, 10, 12, 16, 20 Mbps
- **Default**: 2 Mbps
- **Effect**: H.264 encoding quality for MP4 videos
- **Guidelines**:
  - **0.5-1 Mbps**: Low quality, small files
  - **2-4 Mbps**: Standard quality (recommended)
  - **6-10 Mbps**: High quality, large files
  - **12-20 Mbps**: Very high quality, very large files
- **Notes**: Higher = better quality, larger files

**File Size Impact (1 hour @ 1 fps):**
- 0.5 Mbps: ~225 MB
- 2 Mbps: ~900 MB (default)
- 10 Mbps: ~4.5 GB
- 20 Mbps: ~9 GB

### JPEG Quality
- **Range**: 50% to 100%
- **Default**: 85%
- **Effect**: Compression quality for snapshot images
- **Guidelines**:
  - **50-60%**: Highest compression, smallest temp files
  - **70-80%**: Balanced (recommended)
  - **85-95%**: Low compression, better quality
  - **95-100%**: Minimal compression, largest temp files
- **Notes**: Only affects intermediate snapshots, not final video

---

## Settings Interaction

### Video Quality Preset vs Advanced
- **Presets** automatically set both:
  - Video Bit Rate
  - JPEG Quality
- **Advanced settings** override preset values
- **Recommendation**: Use presets unless you need fine control

### Frame Rate vs Storage
- **Primary factor** for storage usage
- **Examples** (per stream, Medium quality):
  - 1 fps: ~12 MB/min
  - 10 fps: ~120 MB/min
  - 30 fps: ~360 MB/min
- **Multiply by**: Number of streams  duration (minutes)

### Generation Interval vs Safety
- **Shorter intervals** (1-3 min):
  -  More frequent saves (safer)
  -  More processing overhead
  -  Better for unreliable systems
- **Longer intervals** (10-15 min):
  -  Less processing
  -  More data loss if crash
  -  Better for stable systems

---

## Recommended Configurations

### Contest Monitoring (2 hours, 10 participants)
```
Frame Rate: 1 fps
Generation Interval: 5 minutes
Quality Preset: Medium
PIN Protection: Enabled
Expected Storage: ~14.4 GB
```

### Short Presentation (30 min, 4 streams)
```
Frame Rate: 10 fps
Generation Interval: 3 minutes
Quality Preset: High
PIN Protection: Disabled
Expected Storage: ~14.4 GB
```

### All-Day Workshop (6 hours, 6 streams)
```
Frame Rate: 0.5 fps
Generation Interval: 10 minutes
Quality Preset: Low
PIN Protection: Enabled
Expected Storage: ~13.5 GB
```

### High-Quality Demo (15 min, 2 streams)
```
Frame Rate: 30 fps
Generation Interval: 2 minutes
Quality Preset: Ultra High
PIN Protection: Disabled
Expected Storage: ~21.6 GB
```

---

## Quick Calculation Formulas

### Storage Estimation
```
Storage (GB) = Streams  Minutes  FPS  Quality Factor

Quality Factors (MB per frame):
- Low: 0.125 MB
- Medium: 0.200 MB
- High: 0.333 MB
- Ultra High: 0.667 MB

Example: 4 streams  60 min  1 fps  0.200 = 48 MB = 2.88 GB
```

### Maximum Session Duration (100 GB available)
```
Max Minutes = 100,000 MB / (Streams  FPS  Quality Factor)

Example: 100,000 / (10  1  0.200) = 50,000 minutes = 833 hours
Example: 100,000 / (4  30  0.200) = 4,167 minutes = 69 hours
```

---

## Performance Tips

### For Macs with 8 GB RAM
- Limit to 4-6 streams
- Use 0.5-2 fps
- Low or Medium quality
- Avoid 30+ fps

### For Modern Macs (16 GB+ RAM, Apple Silicon)
- Can handle 10-20 streams
- 1-10 fps recommended
- High quality is fine
- 30 fps for 2-4 streams

### Network Requirements
- **Per stream bandwidth**: ~10-20 Mbps (varies by device)
- **Recommended**:
  - 1-4 streams: 5 GHz Wi-Fi
  - 5-10 streams: Dedicated 5 GHz AP
  - 10+ streams: Wired Ethernet + managed switch

---

## Settings File Location

Settings are stored in:
```
~/Library/Preferences/com.aircapture.AirCapture.plist
```

**Do not manually edit** - use the Settings UI to avoid corruption.

---

## Restoring Defaults

To reset all settings to defaults:

1. Quit AirCapture
2. Delete settings file:
   ```bash
   rm ~/Library/Preferences/com.aircapture.AirCapture.plist
   ```
3. Relaunch AirCapture

Alternatively, use individual **Reset to Default** buttons in Settings.

---

**Last Updated**: February 2026  
**Version**: 1.3
