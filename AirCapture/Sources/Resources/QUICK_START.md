# AirCapture Quick Start Guide

Get up and running with AirCapture in 5 minutes!

---

##  Step 1: Start the Receivers

1. Open **AirCapture**
2. Click the **Start** button in the toolbar
3. You'll see "4/4 slots available" (or your configured number)

 Your Mac is now ready to receive AirPlay streams!

---

##  Step 2: Users Connect Their Devices

**Important:** Users voluntarily stream their device screens to your Mac by selecting AirCapture from their Screen Mirroring menu.

### From iPhone/iPad:

1. Swipe down from top-right to open **Control Center**
2. Tap **Screen Mirroring**
3. Select **"AirCapture-01"** (or any available slot)
4. If prompted, enter the **4-digit PIN** shown in AirCapture's toolbar

### From Mac:

1. Click the **Screen Mirroring** icon in the menu bar
2. Select **"AirCapture-01"** (or any available slot)
3. If prompted, enter the **4-digit PIN** shown in AirCapture's toolbar

 The device screen now appears in AirCapture on your Mac!

---

##  Step 3: Start Recording (Optional)

1. Click the **Record** button in the toolbar
2. Type a **session name** (e.g., "Design Review", "Team Meeting", "Workshop Session")
3. Click **Start Recording**
4. A red "REC" badge appears on active streams
5. Timer shows elapsed time

 Everything is being recorded!

---

##  Step 4: Stop Recording

1. Click the **Stop** button in the toolbar
2. Wait a few moments for video processing
3. Your videos are automatically saved

 Recording complete!

---

##  Step 5: Find Your Recordings

### Quick Access:

1. Click the **gear icon** (Settings)
2. Go to **General** tab
3. Click **Show in Finder**

### Default Location:

```
~/Documents/AirCapture Recordings/YYYY-MM-DD/SessionName/
```

Each stream has its own folder with a consolidated MP4 video file.

 Your recordings are organized by date and session!

---

##  What You Can Do Now

### View Full-Screen
- **Double-click** any stream to view it full-window
- Press **Escape** to exit

### Adjust Settings
- Click the **gear icon** for Settings
- Change frame rate, quality, number of streams, and more
- See the [User Guide](USER_GUIDE.md) for details

### Add PIN Protection
1. Settings → **Security** tab
2. Enable **PIN Protection**
3. Set or generate a 4-digit PIN
4. Devices must enter PIN to connect

### Multiple Devices
- Connect additional devices by selecting "AirCapture-02", "AirCapture-03", etc.
- All streams appear in the grid automatically
- Each records independently

---

##  Quick Tips

### For Best Performance:
- Use **5 GHz Wi-Fi** or wired Ethernet
- Keep devices close to the router
- Start with 2-4 streams before scaling up

### For Long Sessions:
- Use **low frame rates** (0.5-2 fps) to save space
- Default 0.2 fps = ~2.4 MB per minute per stream
- Check available disk space first

### For High Quality:
- Increase frame rate to **10-30 fps**
- Settings → Recording → Video Quality Preset → **High**
- Requires more storage space

---

##  Storage Quick Reference

| Frame Rate | Storage per Stream | Best For |
|------------|-------------------|----------|
| 0.2 fps | ~2.4 MB/min | **Default** — very long sessions (8+ hours) |
| 0.5 fps | ~6 MB/min | Very long sessions (4+ hours) |
| 1 fps | ~12 MB/min | Standard monitoring |
| 5 fps | ~60 MB/min | Detailed monitoring |
| 10 fps | ~120 MB/min | Smooth playback |
| 30 fps | ~360 MB/min | High-quality, short sessions |

**Example:** Recording 4 streams at 0.2 fps for 1 hour = ~0.6 GB

---

##  Common Questions

### Q: What is AirCapture used for?
**A:** Recording and monitoring multiple device screens that are voluntarily streamed to your Mac. Common uses include contest monitoring, design reviews, presentations, training, or any scenario where multiple screens need to be viewed or recorded.

### Q: What happens if my device disconnects?
**A:** The stream pauses and can reconnect. If recording, that stream's recording stops but others continue.

### Q: Can I record some streams but not others?
**A:** Currently, recording is all-or-nothing. Click Record to record all connected streams.

### Q: Where are the snapshot images?
**A:** Hidden in `.images/` folders (invisible in Finder by default). They're automatically deleted after video generation.

### Q: How do I add more stream slots?
**A:** Settings → General → Number of Streams → Set to desired number (1-30) → Restart app

---

## Need Help?

**Something not working?** Check the [Troubleshooting](USER_GUIDE.md#troubleshooting) section in the full User Guide.

**Common issues:**
- **Can't find AirCapture in Screen Mirroring menu?** → Ensure both devices are on the same Wi-Fi network
- **Connection keeps dropping?** → Move closer to router or use 5 GHz Wi-Fi
- **Video files very large?** → Lower the frame rate in Settings

---

##  Learn More

For detailed information about all features, settings, and advanced usage, see the complete [User Guide](USER_GUIDE.md).

---

**That's it! You're ready to use AirCapture.**
