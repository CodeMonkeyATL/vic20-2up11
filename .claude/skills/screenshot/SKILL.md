---
name: screenshot
description: Capture the running xvic (VIC-20 emulator) screen and look at it. Use when the user types /screenshot, asks to see or check the emulator screen, or when debugging visual output of the BASIC program.
---

# xvic screenshot

1. Run the capture script from the repo root:

   ```
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File buildtools/screenshot.ps1
   ```

   It asks the running xvic (remote monitor on 127.0.0.1:6510) to save its screen and prints `Screenshot saved: <path>`. Files go to `screenshots/temp/xvic-<timestamp>.png`, which is gitignored.

2. Read the PNG at the printed path and look at it.

3. Reply briefly with what is on screen, the file path, and anything that looks wrong compared with what the code in `src/` should draw. If the user passed text after `/screenshot`, treat it as what to look for.

If the script reports that xvic is not reachable, tell the user to Build (which launches xvic) and try again. To press keys before a screenshot (e.g. play a move, or page through a test program), use `buildtools/keys.ps1 -Keys "<keys>"`. Don't send monitor commands by hand: sending `x`, or disconnecting without reading the reply, wedges VICE's remote monitor.

The user moves screenshots they want to keep from `screenshots/temp/` up to `screenshots/` and commits them; don't move or commit them unless asked.
