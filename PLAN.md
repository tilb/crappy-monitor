<!-- /autoplan restore point: /Users/ernestmistiaen/.gstack/projects/murky-monitor/main-autoplan-restore-20260514-220816.md -->

# MurkyMonitor — Real-World Fidelity Improvements

**Goal:** Improve MurkyMonitor to better match how real-world monitors actually look and behave. The app works, but the gamma math is a rough approximation and the presets are healthcare-specific inventions. We want presets grounded in real ICC data and physics-accurate color science.

**Context:**
- Existing macOS Swift/SwiftUI app that applies gamma manipulation via `CGSetDisplayTransferByTable`
- Already has: brightness, contrast, colorTempShift (K), gammaExponent, blackLevel, pixelSimulation toggle
- Already has: DisplayModeController (resolution switch) + PixelGridController (overlay grid for Retina)
- 4 presets currently — all healthcare (Philips IntelliVue, GE Carescape, Mindray) — invented values
- No A/B compare toggle yet
- Color temp uses linear approximation centered at 6500K
- Gamma uses simple `pow(v, gammaExponent)` curve

**Design doc:** `~/.gstack/projects/murky-monitor/ernestmistiaen-main-design-20260514-213915.md`

---

## Improvement Areas

### 0. ICC Data Validation Spike (Priority: Blocker — do before anything else)

Before implementing Kang et al. or parameterized gamma:
1. Download the ICC profile for Dell U2412M from TFTCentral
2. Open in ColorSync Utility → Tone Curves tab
3. Compare the R/G/B curves to a calibrated photo of an aged Dell U2412M in real use
4. If curves match aged behavior → ICC data is usable (proceed with Approach A)
5. If curves only describe a new monitor → pivot to failure-mode presets (Approach B): "crushed blacks", "low contrast TN washout", "warm office TN", "dim backlight"

**Decision gate:** spike result determines whether Sections 1-3 implement Kang/parametric math (if useful) or just better-tuned approximation values (if not).

**Time budget:** 2 hours. If outcome is unclear after 2 hours, default to Approach B (failure-mode presets).

### 0.5. Launch-Time Gamma State Recovery (Priority: High — add before other changes)

Force-quit bypasses `applicationWillTerminate`, leaving gamma tables degraded. Add to `applicationDidFinishLaunching` (before `setupMenuBar()`):
```swift
// Restore any stale gamma tables from a prior crash
CGDisplayRestoreColorSyncSettings()
```
This is idempotent on clean launches and a safety net on crashes.

**Files:** `MurkyMonitor/App/AppDelegate.swift`

### 1. A/B Compare Toggle (Priority: High — was priority 4)

When holding the Option key, momentarily restore the display to its real state. Release to re-apply simulation. This gives designers a real-time before/after comparison.

**Implementation:**
- Add `private var isABActive: Bool = false` on `AppDelegate` (main-thread only)
- Add BOTH a global monitor (`NSEvent.addGlobalMonitorForEvents`) AND a local monitor (`NSEvent.addLocalMonitorForEvents`) for `.flagsChanged` — global fires when other apps are frontmost; local fires when MurkyMonitor is frontmost. Both needed.
- In the flagsChanged handler (dispatched to `DispatchQueue.main`):
  - If Option down AND `!isABActive`: set `isABActive = true`, call `gammaController.restore()`, hide PixelGrid overlays, update icon title to "⌥ MM"
  - If Option up AND `isABActive`: set `isABActive = false`, call `gammaController.apply(settings:)`, restore PixelGrid if `pixelSimulation` is on, reset icon title to " MM"
  - Guard against flag spam: skip if state unchanged
- Suppress Combine-sink-driven `apply()` calls while `isABActive == true`:
  ```swift
  DispatchQueue.main.async {
      guard !self.isABActive else { return }
      self.gammaController.apply(settings: self.filterSettings)
  }
  ```
- Add menu bar item "Hold ⌥ to Compare" as disabled `NSMenuItem` (informational text, not clickable fallback)
- Store both monitor tokens; cancel both in `applicationWillTerminate`
- If `addGlobalMonitorForEvents` returns nil: log warning; the local monitor still covers the common case (MurkyMonitor frontmost)

**Files:** `MurkyMonitor/App/AppDelegate.swift`

### 2. Real-World Preset Data (Priority: High — contingent on spike result)

Replace invented preset values with values derived from ICC profile data for specific real monitors.

**Target presets (general office + existing healthcare):**
- Dell U2412M (common office IPS monitor, sRGB coverage ~96%)
- HP EliteDisplay E231 (TN panel, very common in enterprise)
- Lenovo ThinkVision T23i (IPS, enterprise standard)
- LG 22M38A (cheap consumer TN, often used in healthcare admin)
- Keep existing 4 healthcare presets

**Data source:** TFTCentral ICC profile database. Extract tone curve data manually from ColorSync Utility (research spike).

**Files:** `MurkyMonitor/Resources/Presets.json`

### 2. Color Temperature Math Accuracy (Priority: High)

Current approach in `GammaController.buildTables()`:
```swift
let t = Float((s.colorTempShift - 6500.0) / 5500.0)
let rMult: Float = t > 0 ? 1.0 - t * 0.30 : 1.0 + (-t) * 0.05
let gMult: Float = 1.0 - abs(t) * 0.05
let bMult: Float = t > 0 ? 1.0 + t * 0.40 : 1.0 - (-t) * 0.40
```

This is a rough linear approximation. Real monitors have specific white point chromaticity coordinates (CIE xy). A physics-based approach uses the D-series illuminant approximation (Kang et al. 2002 formula) or the CIE 1931 color-matching functions.

**Proposed improvement:** Replace linear RGB multipliers with Kang et al. correlated color temperature → CIE XYZ → RGB (sRGB) conversion. Implementation requirements:

- Clamp T to [1667, 25000] before computation
- Use `Double` precision throughout (not `Float`) to preserve accuracy across 256-entry table
- Two piecewise polynomials for x chromaticity:
  - 1667K ≤ T ≤ 4000K: `x = -0.2661239e9/T³ - 0.2343589e6/T² + 0.8776956e3/T + 0.179910`
  - 4000K < T ≤ 25000K: `x = -3.0258469e9/T³ + 2.1070379e6/T² + 0.2226347e3/T + 0.240390`
- Then compute y from x via separate piecewise (also in T)
- Convert xy to XYZ: `X = x/y, Y = 1, Z = (1-x-y)/y`
- Apply Bradford CAT with D65 reference white — compute the 3×3 adaptation matrix ONCE per `buildTables()` call, not per sample, to avoid 256 matrix inversions
- Clamp final per-channel multipliers to a reasonable range (e.g., [0.5, 1.5]) before applying; negative CAT outputs at extreme temperatures must be floored to 0

**Files:** `MurkyMonitor/Display/GammaController.swift`

### 3. Gamma Curve Fidelity (Priority: Medium)

Current: `let g = pow(v, Float(s.gammaExponent))` — pure power function.

Real monitors have:
- A toe region (dark end) where gamma is more linear (sRGB uses a linear segment below 0.04045)
- Panel-specific gamma targets (typically 2.0–2.4, not 1.0)
- Older TN panels often have elevated gamma in midtones (crushed mids)

**Proposed improvement:** Implement a parameterized gamma function:
```
For v < threshold: output = v * linear_coefficient
For v >= threshold: output = a * pow(v, gammaExponent) + offset
```
Parameters `threshold`, `linear_coefficient`, `a`, `offset` derived from ICC tone curves.

Also: add a `gammaDrift` parameter (float 0.0–0.5) simulating the gamma shift of aging TN panels (midtone crush).

**Files:** `MurkyMonitor/Display/GammaController.swift`, `MurkyMonitor/Filters/DegradationPreset.swift`, `MurkyMonitor/Filters/FilterSettings.swift`, `MurkyMonitor/Resources/Presets.json`

### 5. PixelGrid Fidelity (Priority: Low — deferred)

Current: 18% opacity black lines drawn at 1 physical pixel width. This creates a subtle darkening, not a true pixel grid effect.

Real low-DPI simulation needs:
- Pixel pitch that matches the target PPI (e.g., 82 PPI = 3.2pt on Retina)
- Sub-pixel RGB stripe simulation optional (TN panels show distinct R/G/B stripes)
- The current `step = max(2.0, scaleFactor)` doesn't parameterize to a target PPI

**Proposed improvement:** Add a `targetPPI` parameter to PixelGridController. Compute step = (devicePPI / targetPPI) * scaleFactor. Add optional RGB stripe simulation mode.

**Files:** `MurkyMonitor/Display/PixelGridController.swift`, `MurkyMonitor/Filters/FilterSettings.swift`

---

## Files Modified

| File | Change |
|------|--------|
| `MurkyMonitor/Resources/Presets.json` | Replace invented values with ICC-derived data + add 4 office presets |
| `MurkyMonitor/Display/GammaController.swift` | Replace linear color temp approx with Kang et al. formula; add parameterized gamma toe |
| `MurkyMonitor/Filters/DegradationPreset.swift` | Add `gammaDrift` and `threshold` fields |
| `MurkyMonitor/Filters/FilterSettings.swift` | Add `gammaDrift`, `threshold`, `targetPPI` published properties |
| `MurkyMonitor/App/AppDelegate.swift` | Add Option-key A/B toggle global event monitor |
| `MurkyMonitor/Display/PixelGridController.swift` | Parameterize pixel pitch to target PPI |
| `MurkyMonitor/ControlPanel/ControlPanelView.swift` | Change default picker tab to "Presets"; add A/B active banner ("Comparing — release ⌥"); grey out pixelSimulation toggle when DisplayModeController.isAvailable == false |
| `MurkyMonitor/ControlPanel/PresetListView.swift` | Add checkmark to active preset; add empty-state view when preset list is empty |

---

## Distribution Plan (added — CEO phase)

Without a distribution path, all improvements reach zero users.

- **GitHub Releases:** Upload notarized DMG on each release tag
- **Developer ID notarization:** Sign with Apple Developer ID, notarize via `xcrun notarytool`, staple ticket
- **Homebrew cask:** Submit `murky-monitor.rb` to homebrew-cask (community-maintained)
- **NOT App Store:** App Store requires sandboxing, incompatible with CGSetDisplayTransferByTable
- **CI:** GitHub Actions for build + notarization. Manual trigger for now (no CD pipeline needed at v1).

## TODOS.md Deferred Items (CEO phase)

- [ ] Refactor `activeDisplays()` — duplicated in GammaController and DisplayModeController
- [ ] Automated CI/CD notarization pipeline (manual DMG upload is fine for v1)
- [ ] PixelGrid targetPPI parameterization (PixelGridController)
- [ ] Sleep/wake edge case for Option-key A/B toggle (NSWorkspace notifications)
- [ ] TN viewing angle simulation (physically infeasible via gamma curves — long-term research)
- [ ] Figma / Storybook plugin (significant engineering, different surface)

## NOT in Scope

- Figma / Storybook plugin (deferred)
- Windows or Linux port
- ICC profile ingestion pipeline (manual conversion for now)
- App Store distribution (incompatible with CGSetDisplayTransferByTable + non-sandboxed)
- Automated crowdsourced preset contributions
- TN viewing angle simulation (not achievable via gamma curves)
- `gammaDrift` and `threshold` as user-facing sliders (preset JSON only — UI kept simple)

---

## Success Criteria

- Load "Dell U2412M" preset and the display color shift is perceptibly different from "HP EliteDisplay E231"
- Color temperature at 5000K produces a warm yellow tint that a calibrated eye recognizes as warmer than 6500K
- A/B toggle works without any permission dialog
- At least one designer says "this looks like the actual monitor I use at work"

---

## Decision Audit Trail

| # | Phase | Decision | Classification | Principle | Rationale | Rejected |
|---|-------|----------|----------------|-----------|-----------|---------|
| 1 | CEO | Mode: SELECTIVE EXPANSION | Mechanical | P3 | Feature enhancement on existing system | EXPANSION |
| 2 | CEO | Approach: Hybrid (spike first, then A or B) | Mechanical | P3+P6 | 2-hour spike de-risks biggest code change | A-only, B-only |
| 3 | CEO | Add crash recovery (launch-time gamma restore) | Mechanical | P2 | In blast radius, 2 lines, prevents corrupted display | Skip |
| 4 | CEO | Add distribution plan (GitHub Releases + DMG) | Mechanical | P2 | No distribution = no adoption | App Store |
| 5 | CEO | Move A/B toggle to priority 1 | Mechanical | P5 | Both models agree; highest user impact | Keep at priority 4 |
| 6 | CEO | Remove gammaDrift/threshold from UI | Mechanical | P5 | Simpler product; keep in preset JSON only | Surface as sliders |
| 7 | CEO | NaN guard in DegradationPreset.apply() | Mechanical | P2 | JSON could decode NaN; prevents silent corruption | Skip |
| 8 | CEO | PixelGrid hide during A/B toggle | Mechanical | P2 | Undefined interaction currently; 15 min fix | Skip |
| 9 | CEO | Defer targetPPI to TODOS.md | Mechanical | P3 | PixelGrid works; lower priority than presets | Implement now |
| 10 | CEO | Defer sleep/wake A/B edge case to TODOS | Mechanical | P3 | Uncommon; won't block v1 | Implement now |
| 11 | CEO | Add GammaControllerTests.swift with unit tests | Mechanical | P1 | Test directory empty; new math needs tests | Skip |
| 12 | CEO | Add os.log for preset load and display failures | Mechanical | P2 | No observability currently; ~10 min | Skip |
| 13 | Design | Default picker to "Presets" tab | Mechanical | P5 | Presets are the product; filters are secondary | Keep Filters default |
| 14 | Design | A/B active: in-panel banner "Comparing — release ⌥" | Mechanical | P1 | Without indicator, simulation off vs compare are indistinguishable | No indicator |
| 15 | Design | Empty preset: show "No presets loaded" in PresetListView | Mechanical | P1 | Silent blank tab on JSON failure is confusing | Silent blank |
| 16 | Design | Grey pixelSimulation toggle + tooltip when unavailable | Mechanical | P1 | Currently shows toggle that does nothing on non-Retina | Show always |
| 17 | Design | Add checkmark to active preset in PresetListView | Mechanical | P1 | No selection state means users can't tell what's applied | No state |
| 18 | Design | Remove ControlPanelView/gammaDrift slider from scope | Mechanical | P5 | Contradicted by audit decision #6; keep UI simple | Add slider |
| 19 | Design | "Hold ⌥ to Compare" as disabled NSMenuItem (info text) | Mechanical | P5 | Menu toggle fallback must be explicitly sticky vs momentary | Toggle item |
| 20 | Eng | A/B toggle: isABActive flag + suppress Combine sink + both global and local monitors | Mechanical | P5 | Race condition between NSEvent handler and objectWillChange sink; global monitor silent when MurkyMonitor frontmost | Simple global only |
| 21 | Eng | Kang formula: Double precision, piecewise 1667-4000K and 4000-25000K, Bradford matrix once per call, clamp multipliers | Mechanical | P1 | Single-polynomial or Float implementation produces visible tint error near 6500K D65 | Single polynomial |
| 22 | Eng | NSApplication.didChangeScreenParametersNotification: purge stale display IDs from savedModes | Mechanical | P2 | Display hotplug leaves stale CGDirectDisplayID; restore() silently fails on reconnect | Skip |
| 23 | Eng | Gamma toe: reset threshold to nil when user moves slider after preset load | Mechanical | P5 | Preset threshold + manual gammaExponent creates inconsistent toe/body combination | Keep threshold always |
| 24 | Eng | Tests: GammaControllerTests.swift covering monotonicity, NaN/Inf, Kang boundaries, table clamping | Mechanical | P1 | Test directory empty; new math has no validation | No tests |

