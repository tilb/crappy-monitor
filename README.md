# Crappy Monitor

**See your app through your user's eyes.**

You design on a gorgeous Apple display. Your users are squinting at a washed-out
TN panel from 2012. Crappy Monitor is a macOS menu bar app that degrades *your*
screen — real gamma-table manipulation, not an Instagram filter — so contrast
bugs, invisible grey labels, and crushed dark-mode gradients show up in design
review instead of in a support ticket.

🌐 **[crappymonitor.ernestmistiaen.com](https://crappymonitor.ernestmistiaen.com)**

## What it does

- **Real display degradation** — applies gamma-table changes at the display level
  (brightness, contrast, color temperature, gamma drift, black-level lift), so
  *every* app on your screen degrades, not just a screenshot.
- **Presets from real monitors** — profiles grounded in ICC data and measured
  panel failure modes, from the Dell U2412M to aged patient monitors.
- **Hold ⌥ to compare** — hold Option to snap back to your pristine display,
  release to return to crappy reality. Instant A/B, no permission dialogs.
- **Low-DPI simulation** — coarse pixel grids that give your hairline borders and
  10px labels the reality check they deserve.
- **Lives in the menu bar** — a small control panel with sliders and presets.
  Crash-safe: your display is always restored.

## Install

Download the latest signed & notarized DMG from
[Releases](https://github.com/tilb/crappy-monitor/releases/latest), drag it to
Applications, and click the menu bar icon.

Requires **macOS 13 Ventura or later** (Apple Silicon & Intel). Not on the App
Store — sandboxing forbids the display-level APIs (`CGSetDisplayTransferByTable`)
that make this work. No data leaves your machine; none is collected.

## Build from source

```sh
brew install xcodegen   # if you don't have it
xcodegen generate       # regenerates MurkyMonitor.xcodeproj from project.yml
open MurkyMonitor.xcodeproj
```

Then build & run the `MurkyMonitor` scheme in Xcode.

> Note: the project is named `MurkyMonitor` internally — that's the original
> codename. The app ships as **Crappy Monitor**.

## Project layout

| Path | What's there |
|------|--------------|
| `MurkyMonitor/App` | App entry point, `AppDelegate`, menu bar setup |
| `MurkyMonitor/Display` | Gamma, display-mode, and pixel-grid controllers |
| `MurkyMonitor/Filters` | Degradation presets & filter settings |
| `MurkyMonitor/ControlPanel` | SwiftUI control panel and preset UI |
| `MurkyMonitor/Resources/Presets.json` | The monitor preset library |
| `docs/` | Source for the landing page (served by GitHub Pages) |

## License

[MIT](LICENSE) © 2026 Ernest Mistiaen
