# Lens window: design handoff for the first prototype

_Status: design approved for prototyping · Last updated: 2026-11-01_
_Owner: Ernest · Source canvas: Claude Design artifact "Crappy Monitor — Lens Window" (rows D1–D5 are the prototype scope; rows 1–7 and A–C are explorations, see the decision log)_

This document is the brief for building a **throwaway prototype** of the new
interaction design. The goal is to learn, not to ship: keep the existing menu bar
app working, build the prototype next to it, and cut corners on anything that
isn't being tested.

Screens are in `screens/` (2× PNG, 2560 × 1600). They are mockups drawn in HTML,
so treat measurements as intent, not pixel law. Use native AppKit/SwiftUI
controls; never recreate the mock styling by hand.

---

## 1. What we want to learn

| # | Question | How the prototype answers it |
|---|----------|------------------------------|
| H1 | Do designers understand "pick a monitor from a strip, look through the lens" without explanation? | First-use test with 3–5 designers |
| H2 | Is **hover = preview in the big lens, click = choose** clear, or does it surprise people? | Watch whether people hover-scan the strip |
| H3 | Should the lens **follow the pointer** or stay put? (Ernest is unsure) | Toggle in the toolbar; try both in tests |
| H4 | Are live thumbnails worth their cost, or are still snapshots enough? | Build with a setting: live (1–2 fps) vs still |
| H5 | Is the global **Age** control understood next to model names? | Ask people to "make it look like a 7-year-old screen" |

Out of scope for the prototype: backend, sharing, community library, photo
matching, questions wizard, room conditions, the "where people use it" data.

---

## 2. Decision log (what we decided and why)

**From menu bar to a lens window (like Sim Daltonism).**
The app moves out of the status bar into a regular window: a lens you drag over
any part of the screen that shows what's underneath through the chosen monitor.
The existing whole-screen mode stays as a second mode.
- A lens limited to one region *is* technically possible: Sim Daltonism does it
  with ScreenCaptureKit (`SCStreamConfiguration.sourceRect` +
  `SCContentFilter(display:excludingWindows:)` to leave its own window out), with
  a `CGWindowListCreateImage(... .optionOnScreenBelowWindow ...)` fallback. The
  API exists since macOS 12.3, so our macOS 13 target is fine.
- Our current whole-screen effect uses gamma tables (`CGSetDisplayTransferByTable`),
  which always affect the whole display. **The lens needs a second pipeline:
  capture → filter → draw.** Whole Screen keeps the gamma-table pipeline.
- The lens needs **Screen Recording permission**; Whole Screen does not. (The
  README's "no permission dialogs" claim only stays true for Whole Screen.)
- Upside: in lens mode the app's own controls are never degraded.

**Monitors are named by brand and model, shown large.**
We explored price tiers, quality tiers (Premium/Business/Basic), work settings
and room conditions. Ernest chose brand + model as the primary label. "Situations
where this monitor is common" may be added later from user input (a
Hoodmaps-style idea), not now.

**Profiles are based on specifications, and we say so.**
Exact per-model fidelity is false precision: two units of the same model differ
more by age, settings and room light than two models do. So:
- A profile is generated from specs (panel type, contrast ratio, max brightness,
  colour gamut, resolution + size → ppi, year). Open source for EDID data:
  [linuxhw/EDID](https://github.com/linuxhw/EDID) (CC-BY-4.0).
- The UI says "All monitors are based on their specifications" and the info
  popover explains it. No trust badges, confirmations or ratings in v1.
- Later: validate the *spec → effect formula* with a colourimeter on 10–15
  representative monitors, rather than checking every monitor by hand.

**Age is a global control, applied on top of any monitor.**
Spec-based profiles describe a new monitor. Age (New / 3 / 6 / 10 years) adds
wear: dimmer backlight, lower contrast, warmer/yellowed white, raised black
level. Default: 6 years.

**No backend in v1.** The monitor list ships inside the app
(`CrappyMonitor/Resources/Presets.json`) and updates with app releases. Requests
and corrections go to GitHub issues.

**Native macOS, as if Apple shipped it.** HIG, system controls, SF Pro, SF
Symbols, system accent colour, light/dark, increased contrast and reduced
transparency handled automatically. Fully keyboard and VoiceOver operable.
States never rely on colour alone (the degraded screen kills colour first).

---

## 3. Screens

### D1 · Monitor strip (default) — `screens/D1-strip.png`
Window ≈ 1040 × 730 pt, resizable. Three zones:

1. **Unified toolbar (52 pt)**: Lens | Whole Screen (segmented control) ·
   Follow Pointer (toggle button, `cursorarrow`) · title = active monitor name ·
   Hide/Show Strip toggle · search field (≈ 220 pt, "Search brand or model").
2. **Lens**: fills the space between toolbar and strip. Shows the screen
   content underneath the window, filtered with the active monitor + age.
3. **Strip (≈ 170 pt)**, left to right:
   - **Last used** — one fixed tile, always the monitor that's active now.
   - Divider.
   - **Favourites** — user-ordered tiles (drag to reorder), plus a caption on
     the right: "All monitors are based on their specifications".
   - **More…** tile (dashed) — opens the full monitor list.
   - **Side column**: **Age** pop-up button (New / 3 years / 6 years / 10 years)
     and an **Adjust** button (opens the existing sliders as a popover).

**Tile** (≈ 132 pt wide): thumbnail 124 × 70 pt + name (12 pt semibold,
truncates with …). The thumbnail is a **1:1 crop** of the screen under the lens
(not the whole lens scaled down), so the difference between monitors stays
visible. Active tile: 2.5 pt accent ring + white checkmark badge + the word
**Active** under the name.

### D2 · Hover preview — `screens/D2-hover-preview.png`
- Pointer rests on a tile for **~300 ms** → the big lens temporarily renders
  that monitor; a dark capsule appears at the top of the lens:
  "**Preview: Samsung S24F350** · Click to use · ⓘ for details".
- Pointer leaves the strip → lens returns to the active monitor, no animation
  beyond a short cross-fade.
- The hovered tile gets a subtle background and shows an **ⓘ button** in the
  thumbnail's top-right corner.
- The delay stops the lens flickering while the pointer travels across tiles.

### D3 · Search — `screens/D3-search.png`
- Typing filters the strip (Last used stays; favourites caption becomes
  "Matches in favourites").
- A results list drops down under the search field: **In your favourites**
  (selectable) and **Not in favourites yet** (each with an **Add** button),
  "Show all N results", and "Not listed? Request it on GitHub…".
- ↑/↓ moves through results, ↩ uses the selected one, ⎋ clears.

### D4 · Monitor info (ⓘ) — `screens/D4-info.png`
Popover above the tile. Opened by the tile's ⓘ button, **⌘I** on the selected
tile, or right-click → Show Info.
- Title (brand + model) and "Shown at 6 years old · change the age in the strip".
- Spec table: Panel type, Resolution, Size + ppi, Contrast, Brightness, Colour
  range, Released. (Values in the mock are placeholders.)
- Explanation: "**Based on specifications.** Built from the datasheet and the
  monitor's own display data (EDID). The age you pick adds wear on top. Real
  monitors also vary with their settings and the light in the room."
- Footer: "Looks wrong? Report it" (opens a GitHub issue) · Remove from Favourites.

### D5 · Collapsed strip — `screens/D5-collapsed.png`
Strip hidden (toolbar toggle or ⌥⌘S). A small lens window (≈ 440 × 330 pt) with
a one-line footer: ✓ + active monitor name · **Change…** (shows the strip again,
or a menu of favourites) · Adjust. Shown here with Follow Pointer on: the window
moves so the lens stays centred on the pointer. **This is hypothesis H3: test
it, don't assume it.**

### Existing states to keep (controls in these mocks are outdated)
- `screens/state-option-compare.png` — hold ⌥: lens shows the original screen,
  capsule "⌥ Showing original", title "Original".
- `screens/state-permission.png` — empty state when Screen Recording isn't
  allowed: explanation + "Open System Settings…" + "Learn More".
- `screens/state-whole-screen.png` — Whole Screen mode: the window becomes a
  small controller ("Your whole screen is degraded", Stop ⌃⌘W). In Whole Screen
  the app's own window is degraded too, so it must stay readable.

---

## 4. Interaction spec

| Input | Result |
|-------|--------|
| Click tile | Make it active. It moves into the **Last used** slot; favourites keep their order. |
| Hover tile ≥ 300 ms | Temporary preview in the lens + capsule. Leaving reverts. |
| Click ⓘ on tile / ⌘I / right-click → Show Info | Info popover (D4). |
| Right-click tile | Use · Show Info · Move Left/Right · Remove from Favourites |
| Drag tile | Reorder favourites. |
| Click More… | Full monitor list (simple sheet or popover in the prototype). |
| Age pop-up | Applies to whatever monitor is active (and to previews). |
| Adjust | Popover with existing sliders (brightness, contrast, colour temp, gamma, black level, non-retina pixels) + Reset. Changes mark the title "— Edited". |
| Hold ⌥ | Lens shows the original while held (in Whole Screen: restore gamma, as today). |
| Lens / Whole Screen | Switch mode. Whole Screen uses the existing gamma pipeline. |
| Follow Pointer | Window follows the pointer; lens stays centred on it. Window must ignore its own mouse events in this mode, or it can't be clicked through. |

**Keyboard:** ⌘1–⌘9 = favourites by position · ⌘0 = last used · ⌘F = search ·
⌘I = info · ⌥⌘S = show/hide strip · ⌃⌘L = Lens · ⌃⌘W = Whole Screen ·
⌃⌘P = Follow Pointer · ⌥⌘A = Adjust · hold ⌥ = compare. Strip tiles are
focusable with Tab/arrow keys; VoiceOver label: "Philips 241V8, favourite 2"
and "Dell P2419H, active".

---

## 5. Implementation notes (suggestions, not requirements)

- **App type:** the prototype needs a normal window and Dock icon. `Info.plist`
  currently has `LSUIElement: true` (menu bar only). Prototype option: keep the
  status item but switch the activation policy to `.regular` when the lens
  window opens.
- **Capture:** `SCStream` on the display under the window, `sourceRect` = window
  frame (plus a margin so moving doesn't show edges), excluding our own window.
  Update `sourceRect` on window move. Show the permission empty state (`screens/state-permission.png`) when
  `SCShareableContent` access is denied.
- **One filter, two pipelines:** build the effect from the same maths as
  `GammaController.buildTables(_:)` so Lens and Whole Screen match. E.g. turn
  the three 256-entry tables into a `CIColorCube`/`CIColorCurves` filter or a
  small Metal shader. `PresetsStore.applyGamma(to:)` already applies the tables
  on the CPU for thumbnails; fine for tiles, too slow for the lens.
- **Non-retina pixels in the lens:** downsample to 1× then upscale with
  nearest-neighbour sampling, instead of the overlay grid used in Whole Screen.
- **Thumbnails (H4):** reuse the lens frame; crop 124 × 70 pt around the pointer
  (or lens centre) at 1:1; apply each favourite's filter; refresh 1–2 fps, pause
  when the window isn't key or the strip is hidden. Add a debug toggle for
  "still snapshots, refresh every 3 s" to compare.
- **Age model (placeholder, tune by eye):** per year of age, roughly
  brightness −0.015, contrast −0.02, colour temperature −60 K (warmer),
  black level +0.004, clamped to the existing `FilterSettings` ranges.
- **Monitor data:** extend `DegradationPreset` with optional `panelType`,
  `contrastRatio`, `maxBrightness`, `gamutSRGB`, `sizeInches`; keep the
  existing fields. Prototype can hand-fill 6–8 monitors.

---

## 6. Open questions

1. Follow Pointer on or off by default (H3)?
2. Live vs still thumbnails (H4)?
3. What does "More…" become: a sheet with a searchable list, or the D3 results list opened empty?
4. Does Whole Screen also get the strip, or only the compact controller?
5. Formula from specs → filter parameters: who defines it, and when do we validate it with a colourimeter?
