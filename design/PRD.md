# Crappy Monitor 2: the lens app (PRD)

_Status: in engineering review · Owner: Ernest · Last updated: 2026-11-02_
_Sources: `design/lens-window/HANDOFF.md` (design brief, D1–D5), the prototype on
branch `prototype/lens-window` (commits `fba00f3`, `90c44b9`), `PLAN.md` (v1 fidelity
plan), decisions logged on 2026-11-02, and the engineering review at the end of this
document._

---

## 1. Summary

Crappy Monitor shows designers what their app looks like on the monitors their users
actually have. Version 1 is a menu bar app that degrades the whole screen with gamma
tables. Version 2 replaces it with a regular Mac app built around a **lens**: a window you
put over any part of the screen that shows what is underneath through a chosen monitor,
at a chosen age. To see more, you make the lens bigger. Whole-screen degradation is
dropped (decided in review, 2026-11-02): stretching the lens is good enough, and a
**click-through** mode lets you keep working in your app while you look through the lens.

The prototype proved the hard parts work: live capture with ScreenCaptureKit, the filter
in a Metal shader, the monitor strip, search, info and the collapsed lens. Ernest is
satisfied with it, so 2.0 is built now; open interaction questions get answered by a
beta instead of a test round before building.

## 2. Goals and non-goals

**Goals for 2.0**
1. A designer can pick a common monitor by brand and model and look through it at their
   own design within 10 seconds of first launch (after granting Screen Recording).
2. The lens and the strip thumbnails show exactly the same result for the same monitor,
   age and edits, because one renderer draws both.
3. Every monitor in the library is backed by sourced specifications, and the formula from
   specifications to filter is written down and tested.
4. The app looks and behaves as if Apple shipped it (HIG, system controls, SF Symbols,
   light/dark, increased contrast, reduced transparency, VoiceOver, full keyboard use).
5. Available on the Mac App Store, updated through it, without losing the Screen Recording
   permission across updates.

**Non-goals for 2.0**
Whole-screen degradation (v1's gamma-table mode), a menu bar item, backend or accounts,
sharing, a community library service, matching a photo of a monitor, a questions wizard,
room conditions as a user setting, "where people use this monitor" data, Windows or
Linux, a separate direct-download build.

## 3. Users and jobs

Primary user: a product designer or front-end developer on a high-end Mac display who
ships to people on ordinary office monitors (enterprise, healthcare, education).

| Job | How 2.0 serves it |
|-----|-------------------|
| "Will this grey label still be readable on my users' screens?" | Put the lens over it, pick the monitor, set the age. |
| "Which of our customers' monitors breaks this?" | Compare several monitors through the strip thumbnails. |
| "Let me keep working while I check" | Click-through mode: work in your app through the lens. |
| "Show the team" | Share the lens window, or the screen with the lens on it. |
| "Is it the monitor or my design?" | Hold ⌥ to see the original. |

## 4. Decisions carried into 2.0

| Decision | Source |
|----------|--------|
| The app is a lens window only. Whole Screen and the v1 menu bar item are removed. | Review, 2026-11-02 (Vraag 2) |
| Click-through mode: the lens lets clicks, scrolls and hover through to the app below, so hover and focus states can be checked through the lens; hold ⌘ to use the lens window itself. | Review, 2026-11-02 (Vraag 2) |
| Regular app with Dock icon and main menu. | Handoff §2, §5 |
| Monitors are named by brand and model. Profiles are based on specifications, and the UI says so. No trust badges. | Handoff §2 |
| Age is a global control (New / 3 / 6 / 10 years), default 6, applied on top of any monitor. The wear model is redefined in §7.3. | Handoff §2; this PRD |
| Gamut (colour range) is simulated in 2.0. Reconsider only if research cannot find the values (§8.1). | Review, 2026-11-02 (Vraag 3) |
| One `MonitorFilter` computes the parameters; one Metal renderer draws the lens and the thumbnails. A CPU version of the filter exists only in tests, as a reference. | Review, 2026-11-02 (Vraag 4) |
| No hover preview. Hover shows a subtle tile background and the ⓘ button; the lens changes on click. | Prototype demo, 2026-11-02 |
| Follow Pointer is removed: an unproven idea (H3) with the most edge cases; click-through covers checking hover and focus states. | Design review, 2026-11-02 (1C) |
| Strip thumbnails are live at 2 fps; "still every 3 s" is a hidden setting for comparison. | Prototype decision, 2026-11-01 |
| "More…" opens the search results list with all monitors. | Prototype decision, 2026-11-01 |
| Non-retina simulation averages pixel blocks (a real downsample), never picks one pixel per block. | Prototype fix `90c44b9` |
| The lens window floats above other windows, can sit over full-screen apps and moves along to the active Space. | Prototype; review, 2026-11-02 (Vraag 10) |
| Build now; a beta replaces the pre-build designer test round. | Ernest, 2026-11-02 |
| Mac App Store (sandboxed) with a TestFlight beta, like Sim Daltonism. A sandbox spike opens M0; if it fails, fall back to a Developer ID DMG. Replaces the earlier Developer ID decision, whose premise (the gamma API) went with Whole Screen. | Review, 2026-11-02 (Vraag 8) |
| Library v1: AI-assisted research into the 10 most-used monitors of the last 15 years, every value sourced. Ask for input at launch; in-app submission later. | Ernest, 2026-11-02 |

## 5. Experience

The screens and states are specified in `design/lens-window/HANDOFF.md` §3–4 and are not
repeated here. Changes against that brief:

- **Whole Screen is gone.** The Lens | Whole Screen control, `state-whole-screen.png` and
  ⌃⌘W are removed from the design.
- **Toolbar (D1):** Click-through toggle · title · strip toggle · search field. Click-through
  uses `cursorarrow.rays` (§5.3) and the tooltip "Click Through (⌃⌘T) — hold ⌘ to use this
  window".
- **D2 (hover preview) is removed.** Hover shows the tile background and the ⓘ button.
  The preview capsule is gone. Keyboard focus on a tile does not preview either.
- **D5 toolbar** shows only Click-through and the strip toggle; no title
  and no search field (they push the buttons into the overflow menu at 440 pt).
- **Click-through state is always visible:** while it is on, the toolbar toggle is on and
  the window shows a thin accent border, so a user never wonders why clicks "don't work".
- **The monitor's specs in D4** show their source as a footnote link ("Source: Dell
  datasheet"), so a wrong value can be traced. Estimated values are marked as such.
- **"Report it" and "Request it on GitHub…"** open prefilled GitHub issue forms (issue
  templates, see §8.3).

- **Adjust popover** starts with the same Age control as the strip (New / 3 / 6 / 10
  years), so age can be changed in the collapsed lens too (design review, 7.2A).

Keyboard shortcuts, VoiceOver labels and the interaction table stay as in Handoff §4,
except: "Hover tile ≥ 300 ms", ⌘0 (design review, 7.1B) and ⌃⌘W are removed, ⌃⌘L becomes "show the lens window",
and ⌃⌘T toggles click-through. ⌃⌘P (Follow Pointer) is removed. ⌃⌘L and ⌃⌘T work
system-wide (Carbon hot keys,
which need no Accessibility permission; they do not fire when the front app consumes the
key itself, e.g. a terminal).

### 5.1 States (design review, 2026-11-02)

What the user sees, per feature. "Handoff" and "prototype" rows restate existing
contracts; the rest were decided in the design review (2.1–2.3).

```
FEATURE         | LOADING                       | EMPTY                          | ERROR                          | SUCCESS               | PARTIAL
----------------|-------------------------------|--------------------------------|--------------------------------|-----------------------|-------------------------------
Lens            | window background; after 0.5 s| —                              | permission screen (Handoff     | filtered screen       | display without capture: n/a
                | a small spinner + "Starting   |                                | state-permission.png); stream  |                       | (both displays captured, R5)
                | the lens…" (2.2)              |                                | stopped: "The lens stopped" +  |                       |
                |                               |                                | Try Again (prototype)          |                       |
Strip tiles     | neutral tile until the first  | no favourites: "Add the        | —                              | live thumbnail        | —
                | frame (prototype)             | monitors you check often" +    |                                |                       |
                |                               | "Choose Monitors…" opens the   |                                |                       |
                |                               | full list (2.1)                |                                |                       |
Search (D3)     | —                             | "No monitors match "…"" +      | —                              | results list          | —
                |                               | "Not listed? Request it on     |                                |                       |
                |                               | GitHub…" (prototype)           |                                |                       |
Info (D4)       | —                             | missing value: "—", VoiceOver  | —                              | sourced value         | estimated value: "≈ 95% sRGB"
                |                               | "Unknown" (2.3)                |                                |                       | + footnote "≈ estimated from
                |                               |                                |                                |                       | the datasheet" (2.3)
Click-through   | —                             | —                              | —                              | toggle on + accent    | —
                |                               |                                |                                | border (Vraag 7)      |
Compare (⌥)     | —                             | —                              | —                              | "Showing original"    | —
                |                               |                                |                                | capsule (Handoff)     |
```

### 5.2 First run and journey (design review, 2026-11-02)

**First run (3.1A).** The lens window opens on the permission screen (Handoff
`state-permission.png`) with a **Continue** button; only then does the app ask macOS for
Screen Recording. After the user grants it, macOS offers "Quit & Reopen"; the app
reopens straight into the lens with the most common monitor from the research (§8.1,
rank 1) active and the window where it was. If the user picks "Later", the permission
screen notices the grant is there but not yet active and shows "Permission granted.
Relaunch Crappy Monitor to start the lens." with a **Relaunch** button that quits and
reopens this same app (review 2, Vraag 17). If the user declines, the permission screen
stays with "Open System Settings…".

**Discovering click-through (3.2A).** Each time click-through is switched on, a capsule
appears at the top of the lens for 3 seconds: "Clicks go to the app below · hold ⌘ to use
the lens" (same style as the ⌥ "Showing original" capsule; with Reduce Motion it appears
and disappears without a fade).

| Step | User does | User feels | Plan specifies |
|------|-----------|-----------|----------------|
| 1 | Opens the app for the first time | curious | permission screen with Continue (3.1A) |
| 2 | Clicks Continue, macOS asks for Screen Recording | informed, not ambushed | 3.1A |
| 3 | Turns it on in System Settings, chooses Quit & Reopen | minor hassle | relaunch lands in the lens (3.1A) |
| 4 | Sees their screen through the most common monitor | "aha" (5-second visceral) | rank-1 monitor active (3.1A) |
| 5 | Drags the lens over their design, tries other tiles | engaged | D1, strip |
| 6 | Sets Age to 10 years | insight | Age control, §7.3 |
| 7 | Wants to check a hover state, turns on click-through | in control | capsule explains ⌘ (3.2A), accent border |
| 8 | Holds ⌥ to compare | convinced (5-minute behavioural) | ⌥ compare |
| 9 | A month later macOS asks to re-confirm Screen Recording | mild annoyance | permission state handles it (§9) |
| 10 | Keeps using it before every release (5-year reflective) | trusts the tool | sourced specs, "Looks wrong? Report it" |

### 5.3 Design system: native macOS (design review, 2026-11-02, 5.1A)

No DESIGN.md: the system is the design system. The website's retro style stays on the
website.

| Token | Value |
|-------|-------|
| Colour | System colours only: `controlAccentColor` (active ring, "Active", click-through border), `labelColor` / `secondaryLabelColor`, `separatorColor`, `windowBackgroundColor`. No custom colours; light and dark follow the system. |
| Type | SF Pro through the standard text styles. Tile name 12 pt semibold (Handoff), strip headers caption semibold uppercase in `secondaryLabelColor`, window title from the system. |
| Materials | Capsules (⌥ original, click-through hint, loading) use `.regularMaterial`; popovers and sheets are system popovers. Reduce Transparency is handled by the system. |
| Symbols | Click-through `cursorarrow.rays` · strip toggle `rectangle.bottomthird.inset.filled` · Adjust `slider.horizontal.3` · tile info `info.circle.fill` · active badge `checkmark.circle.fill` · More… `plus` · permission `rectangle.dashed.badge.record` · compare capsule `option`. Search uses the system search toolbar item. Each symbol is checked against SF Symbols for macOS 13 at build time. |
| Click-through border | 2 pt `controlAccentColor` just inside the window edge, around content and toolbar; 3 pt with Increase Contrast. |
| Sizes (Handoff) | Window ≈ 1040 × 730 pt; strip 170 pt; tile 132 pt wide, thumbnail 124 × 70 pt, active ring 2.5 pt; D5 window ≈ 440 × 330 pt. |
| Shapes | System window corners; tile thumbnails 6 pt continuous corners (prototype). |

### 5.4 Window sizes and accessibility (design review, 2026-11-02)

**Green button (6.1A).** The lens window never enters native full screen (that would put
it on its own empty Space and the lens would show nothing). The green button zooms the
window to fill the visible area of its display (menu bar and Dock stay visible); clicking
it again restores the previous frame. "Enter Full Screen" is not in the View menu.

**Filled lens (6.2A).** When the window is zoomed to fill its display, the strip collapses
to the D5 footer automatically; un-zooming brings the strip back. A manual ⌥⌘S choice
made while zoomed is kept until the window is un-zoomed. **Collapsing is not shrinking**
(review 2, Vraag 18): collapsing only turns the strip into the footer; the window shrinks
to the D5 size only when the strip is collapsed by hand while the lens is not zoomed, and
un-zooming restores the earlier frame and strip state. These rules live in one
window-layout state machine with table tests.

**Accessibility (6.3A),** in addition to Handoff §4 (keyboard shortcuts, tile focus with
Tab and arrow keys, tile VoiceOver labels):
- Click-through toggles are announced: "Click-through on. Clicks go to the app below." /
  "Click-through off."
- Lens capsules (⌥ original, click-through hint, loading) are announced when they appear.
- The lens view's label: "Lens through [monitor], [age]" (no app name; review 2, Vraag 19).
- Focus order: toolbar → lens → strip (Last used, favourites, More…) → Age → Adjust.
- ⌃⌘T is the alternative for anyone who cannot hold ⌘; holding ⌘ also works with Sticky
  Keys.
- Increase Contrast thickens the click-through border to 3 pt (§5.3); Reduce Motion
  removes capsule fades (§5.2); states never rely on colour alone (Handoff §2).

## 6. Rendering pipeline

```
   MonitorProfile (specs + sources)      Age (global)      Adjust edits (active monitor)
              │                              │                     │
              └──────────────┬───────────────┴─────────────────────┘
                             ▼
                MonitorFilter (pure Swift value)
                  specs → base parameters      (§7.2)
                  base + age → aged parameters (§7.3)
                  + edits
                             │  FilterParameters: tone LUT (3 × 256), wear terms,
                             │  gamut matrix, uniformity, block size
                             ▼
   ScreenCaptureKit frame ──► LensRenderer (Metal, one shader)
   (display under window,        │                      │
    this app excluded,           ▼                      ▼
    30 fps, sRGB)            lens view (30 fps)    strip thumbnails (offscreen,
                                                    2 fps, one pass per tile)

   Tests only: CPU reference of the shader, compared against offscreen GPU renders.
```

- **One formula, one renderer.** `MonitorFilter` is the only place that turns a profile,
  age and edits into parameters, and `LensRenderer` is the only place that applies them.
  The thumbnails are small offscreen renders of the same shader.
- **Capture** follows the prototype: one `SCStream` per display the lens overlaps, full
  display at backing resolution, this app's windows excluded, sRGB on both ends so pixel
  values pass through unchanged. Moving the window only changes the crop; streams start
  and stop as the lens enters or leaves a display, and the shader samples the capture of
  the display under each pixel (review, Vraag 9). Each stream holds 3 frames, the
  minimum (review, Vraag 14).
- **Click-through** sets `ignoresMouseEvents` and watches ⌘ to hand the window back.
- **Hold ⌥** shows the unfiltered capture in the lens and the thumbnails.
- **No display state is changed.** 2.0 never touches gamma tables or display modes, so
  quitting or crashing cannot leave the user's screen degraded.

### 6.1 Code plan (review, Vraag 11)

| Code | 2.0 |
|------|-----|
| `Display/GammaController.swift` | **Delete**, except `colorMultipliers(for:)` (Kang white point), which moves into MonitorFilter with its existing tests. |
| `Display/DisplayModeController.swift`, `Display/PixelGridController.swift` | **Delete.** 2.0 never changes display modes or draws overlays. |
| `ControlPanel/*` (control panel, preset list, banners) | **Delete.** Replaced by the strip, search, info and Adjust. |
| `App/AppDelegate.swift` status item, gamma sink, ⌥ handler | **Rewrite**: no status item, no gamma; the ⌥ compare drives the lens only. |
| `Filters/DegradationPreset.swift`, `Resources/Presets.json` | **Rewrite** to the §7.1 profile schema with a version number. |
| `LensPrototype/ScreenCapture.swift` | **Promote**, extended to one stream per display under the lens. |
| `LensPrototype/HotKeys.swift` | **Promote** (⌃⌘L, ⌃⌘T). The Follow Pointer code in the window controller is **deleted**. |
| `LensPrototype/LensRenderer.swift` (shader approach) | **Promote the approach**, rewrite for MonitorFilter parameters, two displays and offscreen thumbnails. |
| `LensPrototype/LensModel.swift`, `LensWindowController.swift`, views | **Rewrite** with tests; the prototype is the reference for behaviour. |
| `LensPrototype/Thumbnailer.swift` | **Delete** (thumbnails move to the renderer, Vraag 4). |
| `LensPrototype/LensSnapshots.swift` | **Keep as a debug tool** for layout checks. |

## 7. Monitor model

### 7.1 What a profile contains

| Field | Example | Notes |
|-------|---------|-------|
| id, brand, model | `dell-p2419h`, Dell, P2419H | Brand + model is the UI label. |
| released | 2018 | |
| panelType | IPS / VA / TN / PLS | Drives tone-curve and drift defaults. |
| backlight | W-LED / CCFL | Drives wear rate and tint direction. |
| sizeInches, resolution | 23.8, 1920×1080 | → ppi → non-retina block size. |
| contrastRatio | 1000 | Static, from the datasheet. |
| maxBrightness | 250 cd/m² | Used for the office-light term in §7.3. |
| gamut | red/green/blue/white xy primaries (EDID or review measurements) | Drives the gamut matrix. |
| sources | one URL per value; `estimated: true` where a value is estimated | Required. |

### 7.2 From specifications to filter (MonitorFilter, part 1)

Version 1 of the formula, written so it can be calibrated later with a colourimeter
(Handoff §2):

- **Tone curve:** sRGB-like curve per panel type. TN adds midtone drift (existing
  `gammaDrift`); VA adds crushed shadow detail near black; IPS neither.
- **Black floor:** `1 / contrastRatio` of white, in linear light.
- **Gamut:** a 3×3 matrix in linear light from the monitor's primaries to sRGB, so
  colours outside the monitor's range lose saturation the way they would on that panel.
- **Non-retina:** block size = the user's display ppi divided by the monitor's ppi, with
  area averaging (fractional, not just 2×2).
- **Colour temperature:** the white point from the primaries, or 6500 K if unknown.

### 7.3 Age and wear (MonitorFilter, part 2), replacing the handoff's placeholder

**Why it changes.** The handoff's placeholder (brightness −0.015, contrast −0.02,
temperature −60 K and black +0.004 per year) is applied in the current code as a fixed
subtraction from every value (`GammaController.swift:35`). For the Dell P2419H that makes
black *darker* with age (0.010 new → 0.005 at 6 years → 0.003 at 10 years, measured with
the current formula), the opposite of the intended "raised black level". It also lowers
panel contrast, which backlight ageing does not do.

**The model.** All terms in linear light, relative to the new monitor's white:

```
L_out(v) = w(t) · L_panel(v) + a          (then re-encode)

w(t) = 1 − k · t                          backlight output after t years
         k = 0.015 / year for W-LED       (≈ 0.85 at 10 years)       [estimated]
         k = 0.030 / year for CCFL        (≈ 0.70 at 10 years)       [estimated]
a    = 1.6 cd/m² / maxBrightness          light reflected by the screen in an ordinary
                                          office (~500 lux, matte panel); a constant,
                                          not a user setting                [estimated]
T(t) = T_new − 60 K · t                   white point drifts warmer (yellowing light guide
                                          and plastics); direction per backlight type
                                                                            [estimated]
u(t) = 0.01 · t                           brightness falloff towards the corners (10 % at
                                          10 years), radial from the centre of the
                                          display under the lens            [estimated]
```

What this does:
1. **Brightness drops by a factor**, not by subtraction, so dark detail is kept.
2. **Panel contrast stays the same.** White and panel black dim together.
3. **Blacks look lifted** because the reflected office light `a` stays while white dims,
   so effective contrast falls with age, which is what people actually see.
4. **White drifts warmer.**
5. **Corners get darker** (uniformity), the most recognisable sign of an old monitor.
   Measured across the whole display under the lens, not across the lens, so moving the
   lens does not move the dark corners.

Constants are starting values and should be calibrated later. Unit tests check direction,
not exact numbers: white falls with age, black relative to white rises with age, panel
contrast without `a` is unchanged, the curve stays monotonic, and New equals the unaged
profile.

### 7.4 What the designer sees on their own display

A dimmer monitor looks dimmer on a bright Mac, while its own user would have adapted to
it. The lens shows absolute dimming; the info popover says "Brightness loss is shown
as-is; people using this monitor get used to it." No compensation in 2.0.

## 8. Monitor library

### 8.1 Research: the ten most-used monitors of the last 15 years

An AI-assisted research task produces the first ten profiles:
1. **Shortlist** the ten most common office and consumer monitors sold 2011–2026, with
   evidence for each (sales rankings, enterprise standard models, market reports). Say
   how strong that evidence is; "most used" has no single public source.
2. **Specs** for each: every field in §7.1 with a source URL (manufacturer datasheet
   first, then reviews such as TFTCentral/RTINGS, then EDID from linuxhw/EDID,
   CC-BY-4.0, credited).
3. **Colour coordinates** (primaries) for each, from EDID or measured reviews. If they
   cannot be found for most of the ten, Ernest reconsiders gamut for 2.0 (Vraag 3).
4. **Review by Ernest** before the profiles ship. Unsourced values stay empty.

The eight prototype monitors are replaced. The v1 failure-mode presets ("Crushed blacks"
etc.) and the medical IntelliVue presets have no brand + model or specs and are not in
the 2.0 library (open question 3).

### 8.2 Storage

`Presets.json` ships in the app bundle (no backend) and updates with app releases. It
lists monitors in research rank order; the first entry is the first-run default (review 2
correction). The
schema carries a version number; a unit test fails the build when the bundled file does
not decode or has an unknown version. (Review correction: a runtime fallback is pointless
when the bundled copy is the only copy.)

### 8.3 Input from users

- **At launch:** GitHub issue templates "Request a monitor" and "Profile looks wrong",
  opened prefilled from the app (search "Not listed?", D4 "Looks wrong?").
- **Later (not 2.0):** submitting a monitor from inside the app.

## 9. Platform, distribution, privacy

- **macOS 13 or later**, Apple Silicon and Intel.
- **Mac App Store**, sandboxed, free, with the beta on TestFlight. The App Store handles
  updates; every release is signed by the same team, which keeps the Screen Recording
  permission across updates. Sim Daltonism ships the same way (free, open source, App
  Store). ScreenCaptureKit needs no special entitlement in a sandboxed app (Apple DTS,
  developer.apple.com/forums/thread/778616).
- **Sandbox spike first (M0):** a few hours proving capture (including two displays), the
  floating lens over full-screen apps and across Spaces, what the green button does with
  the full-screen-auxiliary behaviour (it must zoom, never enter full screen; review 2),
  click-through and the Carbon hot keys in a sandboxed build. If any of it
  fails, 2.0 ships as a Developer ID DMG with Sparkle 2.7.2 or later instead.
- **The source stays on GitHub** (MIT); building from source keeps working.
- **Debug builds use their own bundle ID** (`com.crappymonitor.app.debug`) so they never
  share or steal the Screen Recording permission of the release app. In the prototype
  session a second copy with the same ID made macOS relaunch the wrong app after
  granting permission and invalidated the permission on every rebuild.
- **Permissions:** Screen Recording is required; without it the app shows the permission
  state (Handoff `state-permission.png`). macOS 15 asks users to re-confirm Screen
  Recording monthly, also for ScreenCaptureKit apps; the app handles a revoked or
  expired permission while running. The README's "no permission dialogs" line is removed.
- **Privacy:** captured frames stay in memory and are never written or sent. The app makes
  no network requests of its own; only links the user opens. No telemetry. The App Store
  privacy label is "Data Not Collected".

## 10. Quality bar

- Unit tests for MonitorFilter (formula, wear directions, gamut matrix, edits), profile
  decoding with missing fields, search and favourites.
- Regression contract (review, Vraag 12): the 6 Kang white-point tests and the 3 tone-table
  invariants (in [0,1], monotonic, finite) move unchanged from `GammaControllerTests` and
  test MonitorFilter.
- Pure-function tests for the ⌘ hand-back decision, the displays a lens rect overlaps,
  capture state transitions (including "granted, needs relaunch"), and the window-layout
  state machine (zoom, auto-collapse, manual collapse, un-zoom restore; review 2).
- Shader tests: render known frames offscreen and compare with the CPU reference, for the
  lens and for a thumbnail-sized target.
- Manual test script for the beta: permission flow (grant, deny, revoke while running,
  "Quit & Reopen", monthly re-confirm), two displays, display unplugged while capturing,
  sleep/wake, lens over a full-screen app and after switching Spaces, a lens spanning two
  displays, click-through (including ⌘ hand-back and hover states seen through the lens), ⌥ compare,
  increased contrast, VoiceOver, keyboard only.
- Performance: lens at up to 30 fps on a 5K display without dropping frames on an M1;
  it redraws only when the screen under it, a setting or ⌥ changes, or the window moves,
  and capture pauses while the window is miniaturised or fully covered (review, Vraag 13).
  CPU, GPU, memory and energy measured in Instruments before beta.

## 11. Milestones

| # | Milestone | Done when |
|---|-----------|-----------|
| M0 | Foundations | Sandbox spike passes; App Store Connect record, release and debug bundle IDs, CI build + upload to TestFlight. |
| M1 | Monitor research | Ten sourced profiles including primaries, reviewed by Ernest. Can run in parallel with M2. |
| M2 | Production pipeline | MonitorFilter, capture, LensRenderer (lens + thumbnails), tests (§10). |
| M3 | Production UI | D1, D3, D4, D5, click-through, permission state, keyboard, VoiceOver. |
| M4 | Beta | TestFlight beta to 10–20 designers; H1, H4, H5 from the handoff answered from feedback (H3 settled: Follow Pointer removed). |
| M5 | Launch 2.0 | Fixes from beta, App Store review passed, README and website updated, issue templates live. |

## 12. Open questions

1. ~~Follow Pointer~~: decided, removed (design review, 2026-11-02, 1C).
2. Live thumbnails: keep 2 fps, or switch to stills if energy use is too high (H4)?
3. Do the medical IntelliVue presets come back for the healthcare audience, and in what form?
4. Who calibrates MonitorFilter with a colourimeter, and when (Handoff Q5)?
5. Does the strip's "Last used" slot remember more than one monitor?

## 13. Out of scope for 2.0

Everything in §2 non-goals, plus: in-app monitor submission, room-condition settings,
compensation for the viewer's brightness adaptation, viewing-angle simulation (not
possible with a flat image), a direct-download build (unless the sandbox spike fails), and
any Figma or Storybook plugin.

---

## Engineering review (2026-11-02)

_Target: `design/PRD.md` (this document), reviewed with /plan-eng-review. Evidence: the
prototype on `prototype/lens-window` (`fba00f3`, `90c44b9`), `design/lens-window/HANDOFF.md`,
`PLAN.md`, `README.md`._

### Scope record

feature answers: Vraag 1 (defer gamut) answered with "Whole Screen is not essential, stretching the lens window is good enough"; Vraag 2 = "Schrappen + doorklikken" (remove Whole Screen, add a click-through lens mode); Vraag 3 = gamut in 2.0, colour-coordinate research planned in M1, reconsider only if research cannot find the values; structure: Vraag 4 = A "Eén plek" (Smaller arrangement: one MonitorFilter value type + one Metal renderer for lens and thumbnails, CPU filter only as a test reference); accepted scope: 2.0 = lens only (no Whole Screen mode, no gamma-table pipeline, no Whole Screen controller, no ⌃⌘W, no uniformity overlay window), plus a click-through lens mode reusing the Follow Pointer mechanism (hold ⌘ to use the window), gamut simulation in the lens, MonitorFilter + single Metal renderer; pending remedies: none

### Scope Challenge findings

1. [P2] (confidence: 8/10) design/PRD.md §9 — Sparkle versions before 2.7.2 have a TCC bypass (CVE-2025-10015); the rewritten §9 already names 2.7.2 but that was not approved. Ledger R1.
2. [P2] (confidence: 7/10) design/PRD.md §5 — the click-through shortcut ⌃⌘T and the accent border were added beyond the approved scope record. Ledger R2 (shortcut) and R3 (visible state).
3. [P3] (confidence: 9/10) README.md:21,34 — "no permission dialogs" and "download the signed DMG from Releases" are false for 2.0 (no releases exist yet). Disposition: already covered by M5 "README and website updated".
4. [P3] (confidence: 9/10) design/PRD.md §8.2 — "falls back to the bundled copy" can never happen; corrected in place (factual correction, no behaviour change).

## Decision ledger

### R1: Minimum Sparkle version
Finding: 1, P2, confidence 8/10, design/PRD.md §9, reviewer: Claude (web search: cvefeed.io CVE-2025-10015)
Plan baseline: original proposal "Updates through Sparkle (signed appcast)", no version
Runtime evidence: unknown (Sparkle not in the project yet)
Comparison grid:
| Choice | Current | A | B |
|---|---|---|---|
| R1 Sparkle minimum | unspecified | 2.7.2 or later, checked in CI | unspecified |
| R2 click-through shortcut | pending | pending | pending |
| R3 click-through visible state | pending | pending | pending |
Question D1:
Vraag 5. De PRD gebruikt Sparkle voor updates. Versies van Sparkle vóór 2.7.2 hebben een lek waarmee een andere app de toestemmingen van Crappy Monitor (zoals schermopname) kan misbruiken (CVE-2025-10015). Leggen we een minimumversie vast? Recommendation: A, because it costs nothing and closes a known hole in exactly the permission this app depends on.
Header: Sparkle
Options:
A) Minimaal 2.7.2 (recommended)
De PRD schrijft Sparkle 2.7.2 of nieuwer voor, en de build controleert dat. Kost niets extra; voorkomt een bekend lek in precies de toestemming waar deze app van afhangt.
B) Geen versie vastleggen
De PRD noemt alleen Sparkle. Iets minder tekst, maar een oude versie kan er per ongeluk in komen.

State: closed as irrelevant (no answer needed)
Actual answer: none; R4 = A removed Sparkle from 2.0
Accepted scope: none. Reopens only if the M0 sandbox spike fails and distribution falls back to a Developer ID DMG.
History: D1 sent twice. First reply "wat is sparkle?" (clarification); second reply asked whether many users fail the requirement and whether App Store updates are easier (clarification, no choice). Explained that the minimum applies to the bundled library, not users. R1 now waits for R4: if 2.0 ships only through the App Store, Sparkle is not used and R1 becomes irrelevant.

### R2: Click-through shortcut
Finding: 2, P2, confidence 7/10, design/PRD.md §5, reviewer: Claude
Plan baseline: Vraag 2 approved "click-through lens mode reusing the Follow Pointer mechanism (hold ⌘ to use the window)"; no shortcut approved
Runtime evidence: prototype registers system-wide Carbon hot keys ⌃⌘L/W/P (HotKeys.swift, LensWindowController.registerHotKeys); none for click-through
Comparison grid:
| Choice | Current | A | B |
|---|---|---|---|
| R1 Sparkle minimum | closed (irrelevant under R4 = A) | unchanged | unchanged |
| R4 channel | approved: App Store + TestFlight (Vraag 8) | unchanged | unchanged |
| R2 click-through shortcut | none | ⌃⌘T, system-wide | none (toolbar button only) |
| R3 click-through visible state | pending | pending | pending |
Question D2:
Vraag 6. De doorklik-stand is goedgekeurd, maar zonder sneltoets. Als doorklikken aan staat en je zit in een andere app, kun je hem nu alleen uitzetten door ⌘ ingedrukt te houden en op de knop te klikken. Krijgt hij een sneltoets die overal werkt? Recommendation: A, because switching click-through off from any app is the main way out of it.
Header: Sneltoets
Options:
A) ⌃⌘T, overal (recommended)
⌃⌘T zet doorklikken aan en uit, ook als een andere app vooraan staat, net als ⌃⌘P voor muis volgen. Een paar regels werk; de snelste weg terug naar de lens.
B) Geen sneltoets
Alleen de knop in de werkbalk (met ⌘ ingedrukt). Eén sneltoets minder om te onthouden, maar omslachtiger om uit te zetten.

State: approved
Actual answer: A) ⌃⌘T, overal (recommended), Vraag 6, 2026-11-02
Accepted scope: ⌃⌘T toggles click-through system-wide (Carbon hot key, like ⌃⌘P), as already written in PRD §5.
History: split from the earlier combined R2 (shortcut + border) on 2026-11-02 before asking; no answer existed. D2 sent once; the user replied "you can still use the app outside the lens, right?" (clarification, no choice). Explained: yes; the shortcut matters for operating the lens window itself and when the lens is stretched large. Question re-sent unchanged.

### R3: Click-through visible state
Finding: 2, P2, confidence 7/10, design/PRD.md §5, reviewer: Claude
Plan baseline: Vraag 2 approved click-through; no visual state approved
Runtime evidence: prototype Follow Pointer shows only the toolbar toggle state (LensWindowController.updateChrome)
Comparison grid:
| Choice | Current | A | B |
|---|---|---|---|
| R1 Sparkle minimum | closed (irrelevant under R4 = A) | unchanged | unchanged |
| R4 channel | approved: App Store + TestFlight (Vraag 8) | unchanged | unchanged |
| R2 click-through shortcut | approved: ⌃⌘T system-wide (Vraag 6) | unchanged | unchanged |
| R3 click-through visible state | toolbar toggle only | toolbar toggle + thin accent border around the window | toolbar toggle only |
Question D3:
Vraag 7. Hoe zie je dat doorklikken aan staat? Zonder duidelijk teken denkt iemand al snel dat de app hangt, omdat klikken op de lens 'niets doen'. Recommendation: A, because a visible border explains at a glance why clicks go through.
Header: Zichtbaarheid
Options:
A) Rand in accentkleur (recommended)
Zolang doorklikken aan staat, krijgt het venster een dunne rand in de systeemaccentkleur, naast de aan-stand van de knop. Klein werk; je ziet altijd waarom klikken doorgaan.
B) Alleen de knop
Alleen de knop in de werkbalk staat aan. Rustiger beeld, maar minder opvallend, vooral als de werkbalk buiten beeld is.

State: approved
Actual answer: A) Rand in accentkleur (recommended), Vraag 7, 2026-11-02
Accepted scope: while click-through is on, the window shows a thin border in the system accent colour in addition to the toolbar toggle's on state, as already written in PRD §5.
History: split from the earlier combined R2 on 2026-11-02 before asking; no answer existed.

### R4: Distribution channel (reopened)
Finding: 5, P1, confidence 7/10, design/PRD.md §9 and §2 non-goals ("App Store distribution"), README.md:34, reviewer: Claude
Plan baseline: Developer ID + notarization, DMG on GitHub Releases, Sparkle updates (Ernest, 2026-11-02, decision log b89c6a20). App Store excluded because "the sandbox forbids the display-level gamma API" (README.md:34, PLAN.md §Distribution).
Reason to reopen: changed assumption. Vraag 2 removed Whole Screen, the only user of CGSetDisplayTransferByTable. 2.0 uses ScreenCaptureKit, which Apple DTS says needs no special entitlement in sandboxed apps (developer.apple.com/forums/thread/778616); Carbon hot keys are reported sandbox-safe. Not yet verified in a sandboxed build.
Runtime evidence: unknown (no sandboxed build exists; project has no App Sandbox entitlement, CrappyMonitor.entitlements is an empty dict)
Comparison grid:
| Choice | Current | A | B | C |
|---|---|---|---|---|
| R4 channel | Developer ID DMG + Sparkle | Mac App Store + TestFlight beta; sandbox spike first in M0, fall back to B if the spike fails | Developer ID DMG + Sparkle (unchanged) | both: App Store and Developer ID DMG |
| R4 update mechanism | Sparkle | App Store | Sparkle | App Store + Sparkle (two builds) |
| R1 Sparkle minimum | pending | irrelevant unless spike fails | pending | pending |
| R2 click-through shortcut | pending | pending | pending | pending |
| R3 click-through visible state | pending | pending | pending | pending |
Question D4:
Vraag 8. Nu Whole Screen weg is, kan Crappy Monitor waarschijnlijk wel in de Mac App Store. Hoe verspreiden we 2.0? Recommendation: A, because the App Store handles updates, trust and the beta (TestFlight) for a free tool, as long as a short sandbox test at the start confirms the lens works there.
Header: Verspreiding
Options:
A) App Store + TestFlight (recommended)
De app gaat via de Mac App Store; de bèta via TestFlight. Apple regelt updates, dus geen Sparkle en geen eigen updatefeed. Eerst een korte test (een paar uur) of de lens, doorklikken en sneltoetsen werken binnen de App Store-regels; lukt dat niet, dan wordt het B. Nadeel: elke update wacht op Apples keuring (meestal 1–2 dagen).
B) Zelf verspreiden (DMG)
Zoals nu in de PRD: ondertekende DMG op GitHub, updates via Sparkle. Je brengt uit wanneer je wilt, zonder keuring, maar je onderhoudt zelf de updatefeed en sleutels, en installeren is een stap omslachtiger.
C) Allebei
App Store én een DMG voor wie de App Store niet wil. Bereikt iedereen, maar je onderhoudt twee varianten van elke release.

State: approved
Actual answer: A) App Store + TestFlight (recommended), Vraag 8, 2026-11-02
Accepted scope: 2.0 ships through the Mac App Store, sandboxed, with the beta on TestFlight; no Sparkle and no own update feed. M0 starts with a sandbox spike (a few hours) proving capture, the floating lens, click-through/Follow Pointer and the Carbon hot keys inside the App Sandbox; if it fails, distribution falls back to B (Developer ID DMG + Sparkle) and R1 reopens.
History: reopens the logged decision b89c6a20 (Developer ID + notarization) because its premise changed; the earlier answer stays on record. D4 sent once; the user asked what Sim Daltonism does (clarification, no choice). Answer: Sim Daltonism ships free on the Mac App Store and is open source on GitHub (Apache 2.0) (apps.apple.com id693112260, github.com/michelf/sim-daltonism). Question re-sent unchanged.

Scope Challenge result: scope reduced per recommendation (Whole Screen removed, Vraag 2). Approved in this stage: R2, R3, R4; R1 closed as irrelevant.

### Section 1: Architecture findings

1. [P2] (confidence: 9/10) CrappyMonitor/LensPrototype/LensRenderer.swift (shader) — `return float4(0.0, 0.0, 0.0, 1.0);   // lens hangs off the display`. Capture covers only the display under most of the window, so any part of the lens over a second display renders black. With "stretch the lens" replacing Whole Screen (PRD §1), spanning two displays becomes a normal case. Ledger R5.
2. [P2] (confidence: 7/10) CrappyMonitor/LensPrototype/LensWindowController.swift — `window.level = .floating` with no `collectionBehavior`. The lens does not appear over full-screen apps or follow the user to another Space, so it cannot be used over Figma or a browser in full screen. PRD §6 is silent. Ledger R6.

### R5: Lens spanning two displays
Finding: Section 1 #1, P2, confidence 9/10, LensRenderer.swift shader, reviewer: Claude
Plan baseline: PRD §6 "one SCStream for the display under the window … Switching displays restarts the stream" (original proposal)
Runtime evidence: prototype shader returns black outside the captured display (static read)
Comparison grid:
| Choice | Current | A | B |
|---|---|---|---|
| R2, R3, R4 (approved: ⌃⌘T, accent border, App Store + TestFlight) | approved | unchanged | unchanged |
| R5 lens across displays | black over the second display | one stream per display under the window; the shader picks the right capture per pixel | the part over another display shows a neutral pattern with "Move the lens onto one display" |
| R6 full screen / Spaces | pending | pending | pending |
Question D5:
Vraag 9. Als je de lens over twee schermen sleept, is het deel op het tweede scherm nu zwart. Nu een grote lens Whole Screen vervangt, gebeurt dat vaker. Wat moet de lens daar laten zien? Recommendation: A, because a stretched lens is now the main way to see more, and the extra capture stream is a contained change.
Header: Twee schermen
Options:
A) Beide schermen tonen (recommended)
De app neemt elk scherm op waar de lens overheen ligt en toont overal het juiste beeld. Ongeveer een dag werk (CC: ~30 min), wat meer rekenwerk zolang de lens over twee schermen hangt.
B) Duidelijke melding
Het deel op het andere scherm toont een rustig patroon met "Zet de lens op één scherm". Minder werk, maar wie de lens oprekt over twee schermen ziet maar de helft.

State: approved
Actual answer: A) Beide schermen tonen (recommended), Vraag 9, 2026-11-02
Accepted scope: capture every display the lens overlaps (one SCStream per display, started and stopped as the window moves); the shader samples the capture of the display under each pixel; uniformity is computed per display. Plus a test that a lens spanning two displays samples both captures.
History: none

### R6: Lens over full-screen apps and other Spaces
Finding: Section 1 #2, P2, confidence 7/10, LensWindowController.swift init, reviewer: Claude
Plan baseline: PRD §4 "The lens window floats above other windows" (original proposal); Spaces and full screen unspecified
Runtime evidence: prototype sets only `window.level = .floating`; behaviour over full-screen apps not tested (static read)
Comparison grid:
| Choice | Current | A | B |
|---|---|---|---|
| R2, R3, R4 (approved: ⌃⌘T, accent border, App Store + TestFlight) | approved | unchanged | unchanged |
| R5 lens across displays | approved: capture every display under the lens (Vraag 9) | unchanged | unchanged |
| R6 full screen / Spaces | lens stays on its own Space, not over full-screen apps | lens can sit over full-screen apps and moves along to the active Space | unchanged: lens stays on the Space where it was opened |
Question D6:
Vraag 10. Kan de lens over een app in volledig scherm (bijvoorbeeld Figma) en gaat hij mee als je naar een ander bureaublad (Space) wisselt? Nu niet. Recommendation: A, because designers often work in full-screen apps and a lens that cannot reach them misses the main use.
Header: Volledig scherm
Options:
A) Ja, overal beschikbaar (recommended)
De lens kan boven apps in volledig scherm liggen en verhuist mee naar het bureaublad waar je bent. Een paar regels werk; moet in de sandboxtest van M0 meegetest worden.
B) Nee, zoals nu
De lens blijft op het bureaublad waar je hem opende en kan niet over apps in volledig scherm. Geen werk, maar wie in volledig scherm ontwerpt, kan de lens daar niet gebruiken.

State: approved
Actual answer: A) Ja, overal beschikbaar (recommended), Vraag 10, 2026-11-02
Accepted scope: the lens window can sit over full-screen apps and moves to the active Space (collection behaviour for full-screen auxiliary + move to active Space); included in the M0 sandbox spike; manual test in the beta script.
History: none

Section 1 dispositions: #1 accepted (R5 = A, Vraag 9); #2 accepted (R6 = A, Vraag 10).

### Section 2: Code quality findings

1. [P2] (confidence: 9/10) CrappyMonitor/App/AppDelegate.swift — `statusItem = NSStatusBar.system.statusItem(...)` and the ⌥ handler calls `gammaController.restore()`. The PRD removes the menu bar item and all display-gamma use, but never says what happens to v1 code (GammaController, DisplayModeController, PixelGridController, ControlPanel, the status item) or which prototype code is promoted. Left implicit, gamma calls and the status item survive into 2.0, and the sandbox spike can trip over APIs the product no longer needs. Ledger R7.
2. No other code-quality findings: error states for capture (permission, stream stop) exist in the prototype and are carried by the PRD; the bundled-library fallback was corrected in Scope Challenge #4.

### R7: Code plan (keep, rewrite, delete)
Finding: Section 2 #1, P2, confidence 9/10, AppDelegate.swift, reviewer: Claude
Plan baseline: PRD has no code plan (original proposal)
Runtime evidence: v1 code present: GammaController.swift, DisplayModeController.swift, PixelGridController.swift, ControlPanel/*, AppDelegate status item and gamma calls; prototype code in LensPrototype/ (static read)
Comparison grid:
| Choice | Current | A | B |
|---|---|---|---|
| R2–R6 (approved) | approved | unchanged | unchanged |
| R7 code plan | none | PRD gets a "Code plan" table: delete v1 gamma, display-mode, pixel-grid, control panel and status-item code; move the Kang white-point function into MonitorFilter; promote ScreenCapture, HotKeys and the shader approach from the prototype; rewrite LensModel and the window controller with tests | none; decided during implementation |
Question D7:
Vraag 11. De PRD zegt niet wat er met de oude code gebeurt (gamma-tabellen, menubalk-item, bedieningspaneel) en welke prototypecode doorgaat. Zonder plan blijft oude code makkelijk hangen, en die gebruikt dingen die in de App Store niet mogen. Recommendation: A, because writing down what goes and what stays prevents dead v1 code from leaking into a sandboxed 2.0.
Header: Oude code
Options:
A) Codeplan in de PRD (recommended)
Een tabel in de PRD: oude gamma-, schermmodus-, pixelraster-, bedieningspaneel- en menubalkcode gaat weg; de kleurtemperatuurberekening verhuist naar MonitorFilter; opname, sneltoetsen en de shader-aanpak uit het prototype gaan door; het model en het venster worden netjes herschreven met tests. Een half uur schrijfwerk.
B) Tijdens het bouwen beslissen
Geen tabel; de bouwer bepaalt het onderweg. Sneller nu, maar de kans is groot dat oude code blijft hangen.

State: approved
Actual answer: A) Codeplan in de PRD (recommended), Vraag 11, 2026-11-02
Accepted scope: PRD §6.1 "Code plan" table as described in option A.
History: none

Section 2 dispositions: #1 accepted (R7 = A, Vraag 11).

### Section 3: Test review

Framework: XCTest (`CrappyMonitorTests`, scheme `CrappyMonitor`); CLAUDE.md has no testing section. Existing tests read in full: `CrappyMonitorTests/GammaControllerTests.swift`, `CrappyMonitorTests/LensPrototypeTests.swift`.

```
CODE PATHS (2.0, planned)                              USER FLOWS
[+] MonitorFilter                                      [+] First launch
  ├── specs → tone curve per panel type  [GAP]           ├── [GAP] [manual] grant Screen Recording → lens shows screen
  ├── black floor from contrast ratio    [GAP]           ├── [GAP] [manual] deny → permission state → Open System Settings
  ├── primaries → gamut matrix           [GAP]           └── [GAP] [manual] macOS 15 monthly re-confirm while running
  ├── ppi → block size (fractional)      [GAP]         [+] Look through a monitor
  ├── wear: w, a, T, u by age            [GAP]           ├── [★★ prototype] pick tile → lens + title change
  ├── Adjust edits on active only        [★★ LensPrototypeTests:77 → port]
  └── Kang white point (moved)           [★★★ GammaControllerTests:10-47 → carry]
[+] Tone LUT invariants (in [0,1], monotonic, finite)  ├── [GAP] age change updates lens and all tiles alike
      [★★ GammaControllerTests:51-79 → re-point]       └── [GAP] [manual] hold ⌥ → original in lens and tiles
[+] Profile decoding (new schema + version)  [GAP]     [+] Click-through / Follow Pointer
[+] LensRenderer                                         ├── [GAP] ⌘ held → window usable; released → clicks pass
  ├── lens pixels == CPU reference       [GAP]           ├── [GAP] [manual] ⌃⌘T / ⌃⌘P from another app
  ├── thumbnail pixels == CPU reference  [GAP]           └── [GAP] [manual] accent border while on
  ├── two displays: samples both         [GAP]         [+] Window placement
  └── uniformity per display             [GAP]           ├── [GAP] [manual] over a full-screen app, after Space switch
[+] ScreenCapture                                        └── [GAP] [manual] lens spanning two displays
  ├── displays overlapped by lens rect   [GAP]         [+] Library
  ├── stream stop → state (revoked/unplugged) [GAP]      ├── [★★ LensPrototypeTests:99] search splits favourites
  └── permission denied → state          [GAP]           └── [GAP] D4 shows sources, estimated values marked
[+] Search / favourites       [★★ LensPrototypeTests:99,108 → port]

COVERAGE: 6/30 paths with ★★/★★★ tests (20%) | Code paths: 4/17 | User flows: 2/13   [measured: counted from this diagram]
QUALITY: ★★★:1 ★★:5 ★:0 | GAPS: 24 (13 code paths, 11 user flows; 8 of those flows covered only by the manual beta script)
Legend: ★★★ behaviour + edge + error | ★★ happy path | [manual] covered by the beta test script
```

Required proof for approved behaviour (added without a new question, per approvals cited):
- MonitorFilter unit tests for every §7.2/§7.3 rule (PRD §10, plan baseline).
- Shader vs CPU reference for lens and thumbnail targets (Vraag 4).
- Two-display sampling test and "displays overlapped by a rect" unit test (Vraag 9).
- ⌘ hand-back decision as a pure function `(mode, commandHeld) → ignoresMouseEvents` with a table test (Vraag 2, Vraag 6).
- Capture state transitions (running → needsPermission / failed on stream stop) as unit tests on the state reducer (PRD §9).
- Profile decoding: missing fields, `estimated` flags, unknown schema version fails the test (PRD §8.2 correction).

Tests to retire: `BannerLogicTests` (control panel removed), `PresetsStoreGroupingTests` (decade list removed), `testDecodesAllNewFields`/`testSpecSubtitle*` (old schema), and from `LensPrototypeTests`: `testWholeScreenGetsTheSameTablesAsTheLens`, `testLensModeTurnsDisplayGammaOff` (Whole Screen removed), `testSixYearsFollowsHandoffFormula`, `testAgeStaysInsideSliderRanges` (placeholder wear model replaced), `testPreviewWinsOverActiveInTheLens` (hover preview removed).

Regression risk: the Kang white point and the tone-table invariants move from `GammaController` into MonitorFilter (§6.1). Ledger R8.

### R8: Regression contract for the moved colour maths
Finding: Section 3 regression rule, CRITICAL, confidence 9/10, CrappyMonitorTests/GammaControllerTests.swift:10-79, reviewer: Claude
Plan baseline: §6.1 (approved, Vraag 11) moves `colorMultipliers(for:)` "with its existing tests"; table invariants not mentioned
Runtime evidence: 6 Kang tests and 3 table-invariant tests pass today (xcodebuild test, 33 tests, 2026-11-02, commit 90c44b9)
Comparison grid:
| Choice | Current | A | B |
|---|---|---|---|
| R2–R7 (approved) | approved | unchanged | unchanged |
| R8 behaviour to preserve | Kang: 6500 K neutral (±0.03), 5000 K warmer, 7500 K cooler, finite at 1667/25000 K, continuous at 4000 K (±0.02); tables in [0,1], monotonic, finite | all of it, tests moved unchanged and re-pointed at MonitorFilter's LUT | Kang only; table invariants dropped |
| R8 intentional changes | none | wear model and tone curve values change by design (§7.3); no test asserts the old numbers | same |
Question D8:
Vraag 12. De kleurtemperatuurberekening en de controles op de tabellen (waarden tussen 0 en 1, nooit dalend, geen ongeldige getallen) verhuizen naar het nieuwe MonitorFilter. Wat moet daarbij gegarandeerd blijven? Recommendation: A, because these 9 tests already guard behaviour the new filter still needs, and carrying them costs minutes.
Header: Behoud
Options:
A) Alles behouden (recommended)
De 6 kleurtemperatuurtests en de 3 tabelcontroles gaan ongewijzigd mee en testen voortaan MonitorFilter. Bewust anders: de leeftijds- en toonwaarden zelf (nieuw model), die geen enkele oude test vastlegt. Een paar minuten werk.
B) Alleen kleurtemperatuur
De 6 kleurtemperatuurtests gaan mee; de 3 tabelcontroles vervallen met de oude gamma-code. Iets minder werk, maar een fout die waarden buiten 0–1 of dalend maakt, valt dan niemand meer op.

State: approved
Actual answer: A) Alles behouden (recommended), Vraag 12, 2026-11-02
Accepted scope: GammaControllerTests:10-79 move unchanged into MonitorFilter tests (6 Kang tests + 3 LUT invariants: in [0,1], monotonic, finite); intentional changes: wear-model and tone-curve values (§7.3), which no old test asserts.
History: none

Section 3 dispositions: regression contract accepted (R8 = A, Vraag 12); required proof for approved behaviour added to §10; tests to retire listed above.

### Section 4: Performance findings

1. [P2] (confidence: 8/10) CrappyMonitor/LensPrototype/LensRenderer.swift — `view.preferredFramesPerSecond = 30` draws every 33 ms whether or not a new frame or parameter arrived, and capture keeps running while the window is miniaturised or fully hidden. Scale: 30 full lens renders per second per window, continuous, unknown energy cost [re-measure in Instruments]. Ledger R9.
2. [P2] (confidence: 7/10) CrappyMonitor/LensPrototype/ScreenCapture.swift — `config.queueDepth = 5` at full backing resolution. One 5K frame is 5120 × 2880 × 4 B ≈ 59 MB [estimated], so ≈ 295 MB per display held by the stream, doubled while the lens spans two displays (Vraag 9). Ledger R10.

### R9: Draw only when something changed, pause when hidden
Finding: Section 4 #1, P2, confidence 8/10, LensRenderer.swift init, reviewer: Claude
Plan baseline: PRD §10 "lens at 30 fps on a 5K display without dropping frames" (original proposal); no idle behaviour
Runtime evidence: prototype MTKView runs continuously at 30 fps; capture stops only when the window closes (static read)
Comparison grid:
| Choice | Current | A | B | C |
|---|---|---|---|---|
| R2–R8 (approved) | approved | unchanged | unchanged | unchanged |
| R9 redraw trigger | every 33 ms | only on a new captured frame, a parameter change, ⌥ or a window move | same as A | same as A |
| R9 max rate for screen changes | 30 fps | 30 fps | 2 fps (window moves stay immediate) | 30 fps while click-through or Follow Pointer is on, 2 fps otherwise |
| R9 hidden window | capture keeps running | capture and drawing pause when miniaturised or fully covered | same as A | same as A |
| R10 capture queue depth | pending | pending | pending | pending |
Question D11:
Vraag 13 (opnieuw). De lens tekent alleen nog als er iets verandert en pauzeert als je hem niet ziet. Hoe vaak mag hij bijwerken als het scherm eronder verandert (scrollen, typen, animaties)? Slepen van de lens blijft in alle gevallen meteen vloeiend. Recommendation: A, because drawing only on change already makes an idle lens almost free, and 2 fps makes working through the lens (click-through) feel sticky; we measure energy before the beta and can lower it then.
Header: Verversing
Options:
A) Tot 30 keer per seconde (recommended)
Veranderingen onder de lens zie je vloeiend. Als er niets verandert, doet de lens vrijwel niets. Meet in Instruments vóór de bèta; blijkt het verbruik toch te hoog, dan alsnog omlaag.
B) Tot 2 keer per seconde
Zuinigst bij drukke schermen (video, scrollen), maar alles onder de lens loopt tot een halve seconde achter; werken door de lens heen voelt stroperig.
C) Snel als je erdoor werkt
30 keer per seconde zolang doorklikken of muis volgen aan staat, 2 keer per seconde als je alleen kijkt. Zuinig én vloeiend, maar één regel meer om uit te leggen en te testen.

State: approved
Actual answer: A) Tot 30 keer per seconde (recommended), Vraag 13 (D11), 2026-11-02
Accepted scope: the lens redraws only on a new captured frame, a parameter change, ⌥ or a window move, at most 30 fps; capture and drawing pause while the window is miniaturised or fully covered; energy measured in Instruments before the beta.
History: D9 asked with options "A) Alleen bij verandering" / "B) Laten zoals het is"; the user answered "ik denk dat we zelfs met 2 keer per sec wegkomen" (proposes a lower rate; accepts drawing on change and pausing implicitly but did not pick an option). Rebuilt as D11 with the max rate as the open choice; draw-on-change and pause-when-hidden are common to all options.

### R10: Capture queue depth
Finding: Section 4 #2, P2, confidence 7/10, ScreenCapture.swift start(screen:), reviewer: Claude
Plan baseline: PRD §6 "full display at backing resolution" (original proposal); queue depth unspecified
Runtime evidence: prototype `config.queueDepth = 5` (static read); memory not measured
Comparison grid:
| Choice | Current | A | B |
|---|---|---|---|
| R2–R8 (approved) | approved | unchanged | unchanged |
| R9 redraw policy | approved: on change, max 30 fps, pause when hidden (Vraag 13) | unchanged | unchanged |
| R10 capture queue depth | 5 frames (≈ 295 MB per 5K display, estimated) | 3 frames, the ScreenCaptureKit minimum (≈ 177 MB per 5K display, estimated), verified in Instruments before beta | 5 frames |
Question D10:
Vraag 14. De opname houdt 5 schermbeelden tegelijk vast. Op een 5K-scherm is dat zo'n 295 MB geheugen, en het dubbele als de lens over twee schermen hangt. Zullen we dat terugbrengen naar 3 beelden, het minimum? Recommendation: A, because the lens only ever shows the newest frame, so the extra two buffers buy nothing but memory.
Header: Geheugen
Options:
A) 3 beelden (recommended)
Rond 177 MB per 5K-scherm in plaats van 295 MB. De lens toont toch altijd alleen het nieuwste beeld. Eén regel werk; voor de bèta in Instruments controleren dat er geen beelden wegvallen.
B) 5 beelden houden
Meer reserve als de app even hapert, maar ruim 100 MB extra per scherm voor beelden die niemand ziet.

State: approved
Actual answer: A) 3 beelden (recommended), Vraag 14, 2026-11-02
Accepted scope: capture queue depth 3 (ScreenCaptureKit minimum), ≈177 MB per 5K display [estimated]; dropped frames and memory verified in Instruments before the beta.
History: none

Section 4 dispositions: #1 accepted (R9 = A, Vraag 13); #2 accepted (R10 = A, Vraag 14).

### Outside voice

Unavailable. Codex preflight was `ready`, but the CLI failed to start: `spawn …/@openai/codex-darwin-arm64/vendor/aarch64-apple-darwin/codex/codex ENOENT` (repair: `npm install -g @openai/codex`). The native fallback needs TaskOutput, which this session does not have, so no subagent was dispatched. No outside coverage for this review.

### TODO decisions

### R11: Stale PLAN.md
Finding: Final planning, TODO candidate, confidence 9/10, PLAN.md:3 ("CrappyMonitor — Real-World Fidelity Improvements"), reviewer: Claude
Plan baseline: no mention of PLAN.md in the PRD
Runtime evidence: PLAN.md describes v1 (gamma tables, "NOT App Store", DMG via GitHub), contradicting PRD §1, §6, §9
Comparison grid:
| Choice | Current | C | A | B |
|---|---|---|---|---|
| R11 PLAN.md | unmarked | superseded note at the top, now | TODO to clean up later | unchanged |
Question D12:
Vraag 15. PLAN.md is het oude verbeterplan voor de menubalk-app (gamma-tabellen, geen App Store, DMG via GitHub). Het spreekt de nieuwe PRD op meerdere punten tegen en kan een bouwer later op het verkeerde been zetten. Wat doen we ermee? Recommendation: C, because it is a two-line change that removes a contradicting document today.
Header: PLAN.md
Options:
C) Nu meteen markeren (recommended)
Bovenaan PLAN.md komt: 'Vervangen door design/PRD.md (2026-11-02); alleen nog als geschiedenis.' Twee regels, in dezelfde commit als de PRD.
A) Op de TODO-lijst
Een TODO om PLAN.md later op te ruimen of te archiveren. Blijft tot dan staan zoals het is.
B) Overslaan
PLAN.md blijft ongewijzigd staan. Geen werk, maar twee plannen die elkaar tegenspreken.

State: approved
Actual answer: C) Nu meteen markeren (recommended), Vraag 15, 2026-11-02
Accepted scope: superseded note added at the top of PLAN.md (done in this review; documentation only).
History: none

Approval readiness: PASS. Checked: R1 closed as irrelevant (R4 = A); R2 Vraag 6; R3 Vraag 7; R4 Vraag 8; R5 Vraag 9; R6 Vraag 10; R7 Vraag 11; R8 Vraag 12; R9 Vraag 13 (D11); R10 Vraag 14; R11 Vraag 15; scope record Vraag 1–4.


### Reality rows

Premise table:

| premise | claim | file:line receipt | verdict |
|---|---|---|---|
| P1 | Prototype has a lens/Whole Screen table-equality test | CrappyMonitorTests/LensPrototypeTests.swift:52 | true |
| P2 | Current wear placeholder subtracts brightness from every value | CrappyMonitor/Display/GammaController.swift:35 | true |
| P3 | Dell P2419H black 0.010 → 0.005 → 0.003 (New/6/10 years) | replica of GammaController.swift:20-44 run in this session | true [measured] |
| P4 | Capture is 30 fps, sRGB | CrappyMonitor/LensPrototype/ScreenCapture.swift:61,65 | true |
| P5 | Offscreen render hook exists | CrappyMonitor/LensPrototype/LensRenderer.swift:129 | true |
| P6 | Off-display lens area renders black | CrappyMonitor/LensPrototype/LensRenderer.swift:207 | true |
| P7 | Lens window sets only `.floating` | CrappyMonitor/LensPrototype/LensWindowController.swift:57 | true |
| P8 | Capture queue depth is 5 | CrappyMonitor/LensPrototype/ScreenCapture.swift:67 | true |
| P9 | macOS 15 asks to re-confirm Screen Recording monthly | macrumors.com 2024-08-15; tidbits.com 2024-08-19 | true for 2024 releases; current release unverified |
| P10 | Sim Daltonism ships free on the Mac App Store and is open source | apps.apple.com id693112260; github.com/michelf/sim-daltonism | true |
| P11 | ScreenCaptureKit needs no special entitlement in a sandboxed app | developer.apple.com/forums/thread/778616 | unverified (M0 spike) |
| P12 | Carbon hot keys work on macOS 15 without Accessibility permission | developer reports (dev.to, Apple forums thread 735223) | unverified (M0 spike) |
| P13 | Wear constants (k, a, 60 K/yr, 1 %/yr) | none, PRD §7.3 | unverified [estimated] |

unverified=3 (P11, P12, P13)

REALITY: premise-table finding 13 premises, 3 unverified (sandbox entitlement, Carbon hot keys, wear constants), all routed to the M0 spike or later calibration design/PRD.md:191
REALITY: already-done pass `git log origin/main --since=2026-11-01 -- CrappyMonitor design PLAN.md README.md` returned no commits CrappyMonitor/App/AppDelegate.swift:1
REALITY: surface-check pass the PRD names no CLI commands; named APIs (SCStreamConfiguration fields, RegisterEventHotKey) are used in the prototype CrappyMonitor/LensPrototype/ScreenCapture.swift:61
REALITY: binding-decisions pass decisions 3f345bd5, 652897e6, 613bda2b honoured; b89c6a20 deliberately superseded by fc80c42d after its premise changed (R4) design/PRD.md:59
REALITY: numbers finding coverage totals corrected from 6/27 to 6/30; wear constants and 59 MB/frame tagged [estimated]; 177/295 MB to [re-measure before gate] in Instruments design/PRD.md:583
REALITY: deferred-asks pass handoff asks left out, each with reason: D2 hover preview (dropped by Ernest, 613bda2b), Whole Screen and state-whole-screen.png (Vraag 2), ⌃⌘W (Whole Screen gone); ⌘0, drag-to-reorder and VoiceOver labels kept by reference to Handoff §4 design/PRD.md:80
REALITY: pr-count pass no .gstack/ship-policy.json, default one PR per wave; milestones M0–M5 imply 6 PRs, each paying one /review + /ship gate; no user-facing reference spans PRs except README (M5 only) design/PRD.md:322

### What already exists

- **Prototype (`prototype/lens-window`)**: ScreenCaptureKit capture excluding this app, the Metal LUT shader with block averaging, Carbon hot keys, the strip/search/info/D5 UI, the permission state and the offscreen snapshot hook. Promoted or used as the behaviour reference per §6.1 (Vraag 11).
- **`GammaController.colorMultipliers(for:)`** (Kang white point) with 6 tests: moves into MonitorFilter unchanged (Vraag 12).
- **Platform**: ScreenCaptureKit (macOS 12.3+), App Store/TestFlight distribution, `NSWindow.ignoresMouseEvents` for click-through. No new third-party dependency in 2.0 (Sparkle dropped with R4).
- **Precedent**: Sim Daltonism (lens window, free, open source, Mac App Store).
- **Data**: linuxhw/EDID (CC-BY-4.0) for primaries; datasheets and reviews for the rest.

### NOT in scope

- Whole Screen mode and every gamma-table, display-mode and overlay mechanism (Vraag 2).
- Direct-download DMG and Sparkle, unless the M0 sandbox spike fails (Vraag 8).
- In-app monitor submission: after 2.0, GitHub issue templates first (Ernest).
- Calibration of the formula and wear constants with a colourimeter: open question 4.
- Medical IntelliVue presets: open question 3.
- Viewing-angle simulation, room-condition settings, brightness-adaptation compensation: not possible or not wanted in 2.0.

### Failure modes

| New path | Realistic failure | Test / handling | User sees |
|---|---|---|---|
| Capture (per display) | Screen Recording revoked or the monthly re-confirm is declined mid-session | state-reducer unit test; permission state view | clear: permission screen |
| Capture (per display) | display unplugged while the lens covers it | overlap unit test; restart streams on screen change; manual beta check | lens continues on remaining display |
| LensRenderer | shader fails to compile or diverges from the reference | shader vs CPU reference tests (fail in CI) | caught before release |
| Click-through | user cannot reach the lens controls | ⌘ hand-back table test; ⌃⌘T; accent border | clear: border + shortcut |
| Window placement | sandbox or a macOS update blocks floating over full-screen Spaces | M0 spike; manual beta check | lens stays on its own Space (visible, not silent) |
| Library | Presets.json does not decode | build-time decoding test | caught before release |
| Hot keys | front app consumes ⌃⌘T/⌃⌘P (e.g. a terminal) | documented limitation; toolbar buttons still work | shortcut does nothing in that app |

Critical gaps: 0 (no path is untested, unhandled and silent at the same time).

### Worktree parallelization strategy

| Step | Modules touched | Depends on |
|------|----------------|------------|
| S1 Sandbox spike + bundle IDs (T1, T2) | project config, spike target | — |
| S2 Code-plan cleanup (T8) | App/, Display/, ControlPanel/, tests | S1 |
| S3 MonitorFilter + regression tests (T3) | Filter/ (new), tests | S2 |
| S4 Capture per display (T5) | Capture/ (from LensPrototype) | S2 |
| S5 Renderer lens + thumbnails (T4) | Render/ | S3, S4 |
| S6 Window behaviour + idle/memory (T6, T7) | Window/, UI/ | S5 |
| S7 Monitor research + schema (T9) | Resources/, Filter/ decoding | — (research), S3 (schema) |

Parallel lanes: Lane A: S1 → S2 → S3 → S5 → S6 (shared Filter/Render). Lane B: S4 (independent after S2, merges before S5). Lane C: S7 research (independent; schema part waits for S3).
Execution order: launch S1; then S2; then S3 + S4 + S7 in parallel; merge; then S5; then S6.
Conflict flags: S3 and S7 both touch profile decoding; land S3 first.

## Implementation Tasks
Synthesized from this review's findings. Each task derives from a specific
finding above. Run with Claude Code or Codex; checkbox as you ship.
Effort assumption: human-team vs CC ratios from the skill defaults (features ~30x, architecture ~5x, research ~3x), adjusted per task.

- [ ] **T1 (P1, human: ~1 day / CC: ~1h)** — distribution — Sandbox spike: capture on two displays, lens over full-screen Spaces, click-through/Follow Pointer, Carbon hot keys in a sandboxed build
  - Surfaced by: Scope Challenge R4 (Vraag 8), Section 1 R5/R6
  - Files: project.yml, CrappyMonitor.entitlements, spike target
  - Verify: manual checklist; falls back to Developer ID DMG + Sparkle ≥ 2.7.2 if any item fails
- [ ] **T2 (P1, human: ~30min / CC: ~5min)** — build — Separate debug bundle ID `com.crappymonitor.app.debug`
  - Surfaced by: PRD §9 (prototype permission incident)
  - Files: project.yml
  - Verify: debug and release builds appear as two entries under Screen Recording
- [ ] **T3 (P1, human: ~2 days / CC: ~1h)** — filter — MonitorFilter with spec formula, wear model v2, gamut matrix; move Kang + LUT invariant tests unchanged
  - Surfaced by: PRD §7, Vraag 4, Vraag 12 (R8)
  - Files: CrappyMonitor/Filter/*, CrappyMonitorTests/MonitorFilterTests.swift
  - Verify: xcodebuild test; wear-direction and regression tests green
- [ ] **T4 (P1, human: ~2 days / CC: ~1h)** — render — LensRenderer draws lens and offscreen thumbnails; CPU reference comparison tests
  - Surfaced by: Scope Challenge Vraag 4
  - Files: CrappyMonitor/Render/*, tests
  - Verify: shader vs reference tests for lens and thumbnail targets
- [ ] **T5 (P1, human: ~1 day / CC: ~30min)** — capture — One stream per overlapped display, start/stop on move, queue depth 3
  - Surfaced by: Section 1 R5 (Vraag 9), Section 4 R10 (Vraag 14)
  - Files: CrappyMonitor/Capture/*, tests
  - Verify: overlap unit test; two-display manual check; Instruments memory
- [ ] **T6 (P2, human: ~1 day / CC: ~30min)** — window — Full-screen Spaces behaviour, click-through with ⌃⌘T and accent border, ⌘ hand-back as a pure function
  - Surfaced by: Section 1 R6 (Vraag 10), Scope R2/R3 (Vraag 6, 7)
  - Files: CrappyMonitor/Window/*, tests
  - Verify: hand-back table test; manual Spaces and click-through checks
- [ ] **T7 (P2, human: ~4h / CC: ~15min)** — performance — Redraw on change only (max 30 fps), pause when miniaturised or covered
  - Surfaced by: Section 4 R9 (Vraag 13)
  - Files: CrappyMonitor/Render/*, CrappyMonitor/Window/*
  - Verify: Instruments energy and frame-drop check before beta
- [ ] **T8 (P2, human: ~4h / CC: ~15min)** — cleanup — Apply the §6.1 code plan; retire the listed tests
  - Surfaced by: Section 2 R7 (Vraag 11), Section 3 tests to retire
  - Files: CrappyMonitor/App/*, Display/*, ControlPanel/*, CrappyMonitorTests/*
  - Verify: no `CGSetDisplayTransferByTable`, `NSStatusBar` or `CGConfigureDisplayWithDisplayMode` left in the target
- [ ] **T9 (P2, human: ~3 days / CC: ~2h)** — library — Research the ten monitors (specs, primaries, sources); schema v2 with version and `estimated` flags; decoding tests
  - Surfaced by: PRD §8.1, Scope correction #4
  - Files: CrappyMonitor/Resources/Presets.json, decoding tests
  - Verify: Ernest reviews every value and source; decoding test green
- [ ] **T10 (P3, human: ~30min / CC: ~5min)** — docs — README: remove "no permission dialogs", DMG install and the App Store exclusion; describe the lens
  - Surfaced by: Scope Challenge #3
  - Files: README.md
  - Verify: read-through at M5

### Unresolved decisions

None. All questions in this review were answered.

### Completion summary

- Step 0: Scope Challenge — scope reduced per recommendation (Whole Screen removed)
- Reality rows: 7/7 applicable rows emitted (`PLAN_REALITY: phase=eng rows=7/7 missing=none verdict=complete`), 3 unverified premises
- Architecture Review: 2 issues found
- Code Quality Review: 1 issue found
- Test Review: diagram produced, 24 gaps identified
- Performance Review: 2 issues found
- NOT in scope: written
- What already exists: written
- TODOS.md updates: 1 item proposed to user (built now: PLAN.md marked superseded)
- Failure modes: 0 critical gaps flagged
- Unresolved decisions: 0 in this review
- Outside voice: codex, unavailable (CLI fails to start; native fallback unavailable: no TaskOutput)
- Parallelization: 3 lanes, 3 parallel / 4 sequential steps
- Lake Score: N/A (no Completeness scores used; Ernest's instructions ask for questions without scores)

### Suppressed findings (appendix)

- (confidence 4/10) The `a` office-light constant may make dark UI look noticeably grey on high-brightness monitors; verify by eye in the beta. Not a remedy yet.
- (confidence 4/10) Carbon hot keys may stop firing in a sandboxed build on a future macOS; covered by the M0 spike and the toolbar fallbacks.

## Design review (2026-11-02)

_Target: `design/PRD.md`, reviewed with /plan-design-review after the engineering review.
No DESIGN.md; the gstack designer was unavailable (`design --version` exited 1), so the
review is text-only. No outside design voices (declined, D2). UI scope: lens window D1,
D3, D4, D5, Adjust, permission state, click-through._

| Pass | Before | After | Decisions |
|------|--------|-------|-----------|
| 1 Information architecture | 7 | 8 | 1C: Follow Pointer removed, click-through is the only pointer mode (replaces the earlier answer 1A) |
| 2 Interaction states | 5 | 8 | 2.1A empty favourites; 2.2A loading; 2.3A ≈ estimates and "—" (§5.1) |
| 3 Journey | 4 | 8 | 3.1A explain before the permission prompt, relaunch into the lens; 3.2A click-through capsule (§5.2) |
| 4 AI slop | 8 | 8 | none: native OPERATE surface, tiles are the interaction, no hard rejections |
| 5 Design system | 5 | 8 | 5.1A native macOS tokens and SF Symbols (§5.3) |
| 6 Window sizes & accessibility | 5 | 8 | 6.1A green button fills, no full screen; 6.2A strip collapses when filled; 6.3A accessibility (§5.4) |
| 7 Unresolved decisions | — | — | 7.1B ⌘0 removed; 7.2A Age also in Adjust |

Why not 10: no mockups could be generated, so none of the passes is verified at pixel
level. Run /design-review on the built app.

Prior learning applied: tcc-bundle-id-collision (confidence 9/10, from 2026-11-02), in
Pass 3 (relaunch after granting permission).

Litmus (Pass 4): brand in first screen YES (app icon, title, menu); one visual anchor YES
(the lens); scannable by headings YES (Last used, Favourites, Age); one job per section
YES; cards necessary YES (tiles are the interaction); motion improves hierarchy YES (only
capsule fades); premium without decorative shadows YES (system chrome only).

Effect on the engineering review: T6 no longer includes Follow Pointer; ⌃⌘P and its code
are deleted (§6.1). New interaction specs (first run, zoom/collapse, announcements) were
added after the engineering review.

### NOT in scope (design)

- Follow Pointer (1C): removed, not deferred.
- ⌘0 (7.1B): removed.
- Visual mockups and a pixel-level check: designer unavailable; /design-review after build.
- A brand design system / DESIGN.md: native macOS is the system (5.1A).
- "Last used" remembering more than one monitor: still open question 5.

### What already exists (design)

Handoff screens D1–D5 and state screens; the Handoff interaction table, shortcuts and
VoiceOver labels; the prototype SwiftUI views (`StripViews.swift`, `LensViews.swift`) for
tiles, capsules, the permission screen and the D5 footer; system controls and SF Symbols.

### TODOS (design)

No deferred design TODOs: every gap was decided and lands in the tasks below.

## Design Implementation Tasks
Synthesized from this review's findings. Each task derives from a specific
finding above. Run with Claude Code or Codex; checkbox as you ship.
Effort assumption: UI features ~30x human ÷ CC.

- [ ] **DT1 (P1, human: ~4h / CC: ~15min)** — window — Single click-through toggle (`cursorarrow.rays`), remove Follow Pointer and ⌃⌘P, 3-second hint capsule
  - Surfaced by: Pass 1 (1C), Pass 3 (3.2A)
  - Files: CrappyMonitor/Window/*, UI views
  - Verify: toggle via toolbar and ⌃⌘T; capsule appears each time; no Follow Pointer code left
- [ ] **DT2 (P1, human: ~4h / CC: ~15min)** — onboarding — Permission screen with Continue before the system prompt; relaunch lands in the lens with the rank-1 monitor
  - Surfaced by: Pass 3 (3.1A)
  - Files: CrappyMonitor/App/*, UI views
  - Verify: fresh account (tccutil reset), grant, Quit & Reopen → lens shows the screen
- [ ] **DT3 (P2, human: ~3h / CC: ~10min)** — states — Loading spinner after 0.5 s, empty-favourites state, ≈ estimates and "—" in D4
  - Surfaced by: Pass 2 (2.1A, 2.2A, 2.3A)
  - Files: UI views
  - Verify: state table §5.1 walked through by hand
- [ ] **DT4 (P2, human: ~3h / CC: ~10min)** — window — Green button zooms to fill (no full screen); strip auto-collapses while zoomed
  - Surfaced by: Pass 6 (6.1A, 6.2A)
  - Files: CrappyMonitor/Window/*
  - Verify: zoom/unzoom on two displays; View menu has no Enter Full Screen
- [ ] **DT5 (P2, human: ~2h / CC: ~10min)** — design system — Apply §5.3 tokens and symbols; check every symbol exists on macOS 13
  - Surfaced by: Pass 5 (5.1A)
  - Files: UI views
  - Verify: light/dark, Increase Contrast (3 pt border), Reduce Transparency
- [ ] **DT6 (P2, human: ~3h / CC: ~15min)** — accessibility — VoiceOver announcements, lens label, focus order per §5.4
  - Surfaced by: Pass 6 (6.3A)
  - Files: UI views, CrappyMonitor/Window/*
  - Verify: VoiceOver walk-through and keyboard-only pass
- [ ] **DT7 (P3, human: ~1h / CC: ~5min)** — adjust — Age control at the top of Adjust; ⌘0 not bound
  - Surfaced by: Pass 7 (7.1B, 7.2A)
  - Files: UI views, main menu
  - Verify: change Age from the collapsed lens

### Design completion summary

```
  +====================================================================+
  |         DESIGN PLAN REVIEW — COMPLETION SUMMARY                    |
  +====================================================================+
  | System Audit         | no DESIGN.md; UI scope D1/D3/D4/D5/Adjust   |
  | Step 0               | 6/10 initial; all 7 passes (D1)             |
  | Pass 1  (Info Arch)  | 7/10 → 8/10 after fixes                     |
  | Pass 2  (States)     | 5/10 → 8/10 after fixes                     |
  | Pass 3  (Journey)    | 4/10 → 8/10 after fixes                     |
  | Pass 4  (AI Slop)    | 8/10 → 8/10 after fixes                     |
  | Pass 5  (Design Sys) | 5/10 → 8/10 after fixes                     |
  | Pass 6  (Responsive) | 5/10 → 8/10 after fixes                     |
  | Pass 7  (Decisions)  | 2 resolved, 0 deferred                      |
  +--------------------------------------------------------------------+
  | NOT in scope         | written (5 items)                           |
  | What already exists  | written                                     |
  | TODOS.md updates     | 0 items proposed                            |
  | Approved Mockups     | 0 generated, 0 approved                     |
  | Decisions made       | 12 added to plan                            |
  | Decisions deferred   | 0                                           |
  | Overall design score | 4/10 → 8/10                                 |
  +====================================================================+
```

### Unresolved design decisions

None.

## Engineering review 2 (2026-11-02)

_Target: `design/PRD.md`, second /plan-eng-review, limited to what the design review
changed (§5.1–5.4, Follow Pointer removed, ⌘0 removed, Age in Adjust). Evidence: the
prototype (`LensWindowController.swift`), web search on permission relaunch and window
collection behaviour._

Scope: about 6 changed files and no new classes proposed by the plan delta, so the
complexity gate does not trip. Scope accepted as-is.

### Scope Challenge findings (review 2)

1. [P2] (confidence: 8/10) design/PRD.md §5.2 — the first run relies on macOS's own "Quit & Reopen" prompt. Developers report a new Screen Recording grant only takes effect after the app is quit and relaunched (docs.rs car-desktop permissions.rs; peep14.mataroa.blog). If the user picks "Later", the lens stays on the permission screen; the prototype only rechecks on activation: `@objc private func appDidBecomeActive()` (CrappyMonitor/LensPrototype/LensWindowController.swift:153). Ledger R12.
2. [P3] (confidence: 7/10) design/PRD.md §5.4 and R6 — "may appear over full-screen apps" and "never enter full screen" are both full-screen collection behaviours, which Apple documents as mutually exclusive (developer.apple.com, NSWindow.CollectionBehavior); what the green button does with the auxiliary behaviour is undocumented. Disposition: required proof of approved behaviour (R6, 6.1A); added to the M0 sandbox spike, no question.
3. [P3] (confidence: 9/10) design/PRD.md §5.2 "rank 1" — §7.1 has no rank field. Correction: `Presets.json` lists monitors in research rank order and the first entry is the first-run default; a decoding test checks it is fully sourced. No behaviour change, no question.

### Section 1 (review 2): Architecture

4. [P2] (confidence: 9/10) CrappyMonitor/LensPrototype/LensWindowController.swift:259 — `let size = … NSSize(width: 440, height: 330)`: collapsing the strip shrinks the window to the D5 size. With 6.2A (collapse automatically when the lens fills the screen) that rule would shrink the zoomed lens right after zooming it. Ledger R13.

### Section 2 (review 2): Code quality

5. [P3] (confidence: 7/10) design/PRD.md §5.4 — the lens label "Lens: [front app under the lens] through …" has no defined source. The frontmost application is Crappy Monitor itself whenever the lens has focus, which is exactly when VoiceOver reads it. Ledger R14.

### R12: Relaunch after granting Screen Recording
Finding: Review 2 Scope #1, P2, confidence 8/10, LensWindowController.swift:153, reviewer: Claude
Plan baseline: §5.2 (3.1A approved): after granting, "macOS offers Quit & Reopen; the app reopens straight into the lens"
Runtime evidence: in this session the user chose "Quit & Reopen" twice and macOS relaunched another copy; prototype has no relaunch control (static read + observed)
Comparison grid:
| Choice | Current | A | B |
|---|---|---|---|
| Approved earlier (R2–R11, design 1C–7.2A) | approved | unchanged | unchanged |
| R12 relaunch path | only macOS's Quit & Reopen prompt | permission screen detects "granted, needs relaunch" and shows a Relaunch Crappy Monitor button that quits and reopens this same app | unchanged; users who pick "Later" must quit and reopen themselves |
| R13 collapse vs zoom | pending | pending | pending |
| R14 lens label source | pending | pending | pending |
Question D1:
Vraag 17. Na het toestaan van schermopname werkt de lens pas als de app opnieuw start. macOS biedt daarvoor 'Stop en open opnieuw', maar kiest iemand 'Later', dan blijft de lens op het toestemmingsscherm hangen zonder uitleg. Krijgt de app een eigen knop om zichzelf te herstarten? Recommendation: A, because the first run is the moment the app earns trust, and a stuck permission screen is the most likely way to lose a new user.
Header: Herstarten
Options:
A) Eigen herstartknop (recommended)
Het toestemmingsscherm ziet dat de toestemming er is maar nog niet actief, en toont 'Toestemming gegeven. Herstart Crappy Monitor om de lens te starten.' met een knop die precies deze app afsluit en opnieuw opent. Een paar uur werk (CC: ~15 min).
B) Alleen macOS-melding
Zoals nu: alleen de 'Stop en open opnieuw'-melding van macOS. Geen werk, maar wie 'Later' kiest, ziet een lens die niets doet tot hij de app zelf afsluit.

State: approved
Actual answer: A) Eigen herstartknop (recommended), Vraag 17, 2026-11-02
Accepted scope: the permission screen detects "granted, not yet active" and shows "Permission granted. Relaunch Crappy Monitor to start the lens." with a button that quits and reopens this same app bundle; covered by the capture-state tests and the first-run manual check.
History: none

### R13: Collapsing the strip while the lens fills the screen
Finding: Review 2 Section 1 #4, P2, confidence 9/10, LensWindowController.swift:259, reviewer: Claude
Plan baseline: §5.4 (6.2A approved): "when the window is zoomed to fill its display, the strip collapses to the D5 footer automatically"; D5 (Handoff) is a ≈ 440 × 330 pt window
Runtime evidence: prototype collapse always resizes the window to 440 × 330 (static read)
Comparison grid:
| Choice | Current | A | B |
|---|---|---|---|
| Approved earlier | approved | unchanged | unchanged |
| R12 relaunch path | pending | pending | pending |
| R13 collapse vs window size | collapse always shrinks to 440 × 330 | collapse changes only the strip into the footer; the window shrinks to the D5 size only when collapsed by hand while not zoomed; un-zoom restores the earlier frame and strip state; rules in one tested window-layout state machine | collapse always shrinks; auto-collapse on zoom is dropped |
| R14 lens label source | pending | pending | pending |
Question D2:
Vraag 18. In het prototype maakt inklappen van de strip het hele venster klein (440 × 330). Met jouw keuze 'strip klapt vanzelf in als de lens het scherm vult' zou de lens dan meteen na het vergroten weer krimpen. Hoe lossen we dat op? Recommendation: A, because it keeps both approved behaviours (small D5 lens and a filled lens with a footer) and puts the rules in one testable place.
Header: Inklappen
Options:
A) Inklappen ≠ krimpen (recommended)
Inklappen verandert alleen de strip in de smalle voetregel. Het venster krimpt naar het D5-formaat alleen als je met de hand inklapt terwijl de lens niet het scherm vult. Terugzetten herstelt het oude formaat en de strip. De regels komen in één los, getest onderdeel. Een halve dag werk (CC: ~20 min).
B) Automatisch inklappen schrappen
Inklappen blijft altijd krimpen, en de strip klapt niet meer vanzelf in bij een gevulde lens. Eenvoudiger, maar dat draait jouw keuze 6.2A terug.

State: approved
Actual answer: A) Inklappen ≠ krimpen (recommended), Vraag 18, 2026-11-02
Accepted scope: collapsing turns the strip into the footer only; the window shrinks to the D5 size only for a manual collapse while not zoomed; un-zoom restores the earlier frame and strip state; rules live in one window-layout state machine with table tests.
History: none

### R14: How far accessibility goes for VoiceOver (reopens part of 6.3A)
Finding: Review 2 Section 2 #5, P3, confidence 7/10, design/PRD.md §5.4, reviewer: Claude
Plan baseline: §5.4 (6.3A approved): VoiceOver announcements for click-through and capsules; lens label "Lens: [front app under the lens] through [monitor], [age]"; focus order; ⌃⌘T instead of holding ⌘; Increase Contrast and Reduce Motion
Reason to reopen: D3 (Vraag 19) asked only about the app name; the user replied "for a visual tool for comparing colours I doubt whether we should make it accessible for visually impaired people at all" (changed assumption about the audience for VoiceOver features).
Runtime evidence: none (not in the prototype)
Comparison grid:
| Choice | Current | A | B | C |
|---|---|---|---|---|
| Approved earlier (except 6.3A) | approved | unchanged | unchanged | unchanged |
| R12 relaunch | approved: own relaunch button (Vraag 17) | unchanged | unchanged | unchanged |
| R13 collapse vs zoom | approved: collapsing ≠ shrinking (Vraag 18) | unchanged | unchanged | unchanged |
| System labels, keyboard, focus order, ⌃⌘T, Increase Contrast, Reduce Motion | approved (6.3A) | kept | kept | kept |
| VoiceOver announcements (click-through, capsules) | approved (6.3A) | kept | kept | dropped |
| Lens label app name | approved (6.3A), source undefined | dropped: "Lens through [monitor], [age]" | kept: owner of the topmost window under the lens centre, ≤ 2 updates/s | dropped |
Question D4:
Vraag 19 (opnieuw). Je twijfelt of een kleurvergelijkingstool toegankelijk moet zijn voor slechtzienden. Wat bijna gratis is (systeemknoppen met labels, toetsenbord, focusvolgorde, ⌃⌘T, Verhoogd contrast, Beweging beperken) blijft in elk geval. Hoeveel VoiceOver-werk doen we daarbovenop? Recommendation: A, because the free parts serve low-vision and keyboard users who do use a visual tool, while detecting the app under the lens costs real work for the smallest group.
Header: VoiceOver
Options:
A) Meldingen, geen appnaam (recommended)
VoiceOver meldt doorklikken aan/uit en leest de lensmeldingen voor; de lens heet 'Lens door [monitor], [leeftijd]'. Klein werk (CC: ~10 min); de dure appnaam-detectie vervalt.
B) Alles, met appnaam
Zoals 6.3A plus de app onder de lens in het label. Volledigst, maar een paar uur extra werk (CC: ~15 min) voor een kleine groep.
C) Alleen het gratis deel
Geen meldingen en geen lenslabel; alleen wat systeemknoppen en -instellingen vanzelf geven. Geen extra werk, maar VoiceOver-gebruikers horen niet wanneer doorklikken aan staat.

State: approved
Actual answer: A) Meldingen, geen appnaam (recommended), Vraag 19 (D4), 2026-11-02
Accepted scope: keep system labels, keyboard, focus order, ⌃⌘T, Increase Contrast, Reduce Motion and the VoiceOver announcements; the lens label becomes "Lens through [monitor], [age]" (no app detection).
History: D3 (Vraag 19) asked "real app name (A) vs drop app name (B)"; the user answered with doubt about accessibility for visually impaired users at all (no option chosen). Rebuilt as D4 with the VoiceOver depth as the open choice.

Scope Challenge result (review 2): scope accepted as-is. Dispositions: #1 accepted (R12 = A, Vraag 17); #2 added to the M0 spike (required proof of R6 and 6.1A); #3 corrected in §8.2.

Section 1 dispositions (review 2): #4 accepted (R13 = A, Vraag 18).
Section 2 dispositions (review 2): #5 accepted in a changed form (R14 = A, Vraag 19 re-asked as D4: announcements kept, app name dropped).

### Section 3 (review 2): Test review

```
CODE PATHS (delta)                                     USER FLOWS (delta)
[+] Capture state                                      [+] First run
  ├── notDetermined → explainer → requested [GAP]        ├── [GAP] [manual] Continue → system prompt → grant → Quit & Reopen
  ├── granted, needs relaunch → Relaunch    [GAP]        ├── [GAP] [manual] grant → "Later" → Relaunch button → lens
  └── denied → Open System Settings         [GAP]        └── [GAP] [manual] deny → Open System Settings
[+] Window layout state machine                        [+] Window size
  ├── zoom → auto-collapse, frame kept      [GAP]        ├── [GAP] [manual] green button fills, never full screen
  ├── manual collapse unzoomed → D5 size    [GAP]        └── [GAP] [manual] un-zoom restores frame and strip
  ├── manual ⌥⌘S while zoomed kept          [GAP]      [+] Accessibility
  └── un-zoom restores frame + strip        [GAP]        ├── [GAP] [manual] VoiceOver hears click-through on/off
[+] First-run default = first Presets entry [GAP]        └── [GAP] [manual] keyboard-only pass in focus order
[+] Click-through hint capsule (3 s, once per toggle)  [GAP]
[+] Follow Pointer                                     REMOVED (no tests; prototype code deleted per §6.1)

COVERAGE (delta): 0/16 paths tested (0%) | Code paths: 0/9 | User flows: 0/7   [measured: counted from this diagram]
QUALITY: none yet | GAPS: 16 (9 unit, 7 manual in the beta script)
```

Required proof for approved behaviour (added without a new question): capture-state reducer tests including "granted, needs relaunch" (Vraag 17); window-layout table tests (Vraag 18, 6.2A); a decoding test that the first `Presets.json` entry is fully sourced (correction #3); the manual first-run, zoom and VoiceOver checks join the beta script. No regression risk to existing behaviour (all delta paths are new). Tests made obsolete: none beyond review 1's list.

### Section 4 (review 2): Performance

No issues found. The relaunch check runs only while the permission screen is visible; the window-layout rules run on resize/zoom events; dropping the app name (Vraag 19) removes the only new periodic work (window-list lookups).

### Outside voice (review 2)

Unavailable, same cause as review 1: the Codex CLI fails to start (ENOENT; repair with `npm install -g @openai/codex`), and the native fallback needs TaskOutput, which this session lacks. No outside coverage.

### TODO decisions (review 2)

No TODO candidates: every finding was decided and maps to tasks below.

Approval readiness (review 2): PASS. Checked: R12 Vraag 17; R13 Vraag 18; R14 Vraag 19 (D4); corrections #2 and #3 need no approval (required proof / no behaviour change).

### Reality rows (review 2)

| premise | claim | file:line receipt | verdict |
|---|---|---|---|
| P14 | Prototype rechecks permission only on activation | CrappyMonitor/LensPrototype/LensWindowController.swift:153 | true |
| P15 | Prototype collapse shrinks the window to 440 × 330 | CrappyMonitor/LensPrototype/LensWindowController.swift:259 | true |
| P16 | A new Screen Recording grant needs a quit and relaunch | docs.rs car-desktop permissions.rs; peep14.mataroa.blog | unverified (developer reports; M0 spike) |
| P17 | Full-screen collection behaviours are mutually exclusive | developer.apple.com NSWindow.CollectionBehavior | true (documented); green-button effect unverified |

unverified=2 (P16, P17 green-button part)

REALITY: premise-table finding 4 premises, 2 unverified, both routed to the M0 spike design/PRD.md:385
REALITY: already-done pass no commits on origin/main since 2026-11-01 for the touched paths (checked in review 1, unchanged today) CrappyMonitor/LensPrototype/LensWindowController.swift:153
REALITY: surface-check pass the delta names no CLI commands; named APIs are AppKit/ScreenCaptureKit documented members CrappyMonitor/LensPrototype/LensWindowController.swift:259
REALITY: binding-decisions pass decisions 7a069404 (Follow Pointer removed) and fc80c42d honoured; 6.3A partly reopened only after the user's own doubt (R14) design/PRD.md:184
REALITY: numbers pass delta coverage 0/16 counted from the diagram; no new performance numbers design/PRD.md:411
REALITY: deferred-asks pass every design-review decision (1C–7.2A) is in the plan body or tasks design/PRD.md:139
REALITY: pr-count pass no new milestones; delta lands inside M2/M3 PRs design/PRD.md:385

### NOT in scope (review 2)

- Naming the app under the lens for VoiceOver (Vraag 19).
- Rebooting as a recovery for stale permission denials: documented only as a support note, not built.

### What already exists (review 2)

The prototype permission screen and capture-state handling, the D5 footer, and `NSWindow` zoom (`windowWillUseStandardFrame`) cover most of the delta; the new pieces are the relaunch path and the window-layout state machine.

### Failure modes (review 2)

| Path | Realistic failure | Test / handling | User sees |
|---|---|---|---|
| First run | user picks "Later" after granting | Relaunch button (Vraag 17), state test | clear: "Permission granted. Relaunch…" |
| First run | macOS keeps a stale denial | permission screen with Open System Settings; support note to reboot | clear, recoverable |
| Window layout | auto-collapse shrinks a zoomed lens | window-layout table test (Vraag 18) | caught before release |
| Green button | auxiliary behaviour still allows full screen on some macOS | M0 spike; manual beta check | lens shows an empty Space (visible, caught in spike) |

Critical gaps: 0.

## Implementation Tasks (review 2)
Synthesized from this review's findings. Each task derives from a specific
finding above. Run with Claude Code or Codex; checkbox as you ship.
Effort assumption: features ~30x human ÷ CC.

- [ ] **T11 (P1, human: ~3h / CC: ~15min)** — onboarding — Detect "granted, needs relaunch" and offer a Relaunch button that reopens this same app
  - Surfaced by: Review 2 Scope #1 (Vraag 17)
  - Files: CrappyMonitor/App/*, CrappyMonitor/Capture/*, permission view
  - Verify: capture-state tests; manual grant → Later → Relaunch
- [ ] **T12 (P1, human: ~4h / CC: ~20min)** — window — Window-layout state machine: zoom, auto-collapse, manual collapse, un-zoom restore
  - Surfaced by: Review 2 Section 1 #4 (Vraag 18)
  - Files: CrappyMonitor/Window/*, tests
  - Verify: table tests; manual zoom/unzoom with and without strip
- [ ] **T13 (P2, human: ~1h / CC: ~5min)** — spike — Add the green-button/auxiliary check to the M0 sandbox spike
  - Surfaced by: Review 2 Scope #2
  - Files: spike target
  - Verify: green button zooms, never full screen, over a full-screen app
- [ ] **T14 (P3, human: ~30min / CC: ~5min)** — library — First Presets entry is the first-run default; decoding test
  - Surfaced by: Review 2 Scope #3
  - Files: CrappyMonitor/Resources/Presets.json, tests
  - Verify: test green
- [ ] **T15 (P3, human: ~30min / CC: ~5min)** — accessibility — Lens label without app name (replaces part of DT6)
  - Surfaced by: Review 2 Section 2 #5 (Vraag 19)
  - Files: UI views
  - Verify: VoiceOver reads "Lens through [monitor], [age]"

### Unresolved decisions (review 2)

None.

### Completion summary (review 2)

- Step 0: Scope Challenge — scope accepted as-is
- Reality rows: 7/7 applicable rows emitted, 2 unverified premises
- Architecture Review: 1 issue found
- Code Quality Review: 1 issue found
- Test Review: diagram produced, 16 gaps identified
- Performance Review: 0 issues found
- NOT in scope: written
- What already exists: written
- TODOS.md updates: 0 items proposed to user
- Failure modes: 0 critical gaps flagged
- Unresolved decisions: 0 in this review
- Outside voice: codex, unavailable (CLI broken; native fallback unavailable)
- Parallelization: Sequential implementation, no parallelization opportunity (the delta sits in the window and onboarding modules of review 1's lanes A and S6)
- Lake Score: N/A (no Completeness scores used)

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Outside Review | codex, default-on after `/plan-eng-review` | Independent 2nd opinion | 2 | unavailable | CLI fails to start (ENOENT) both runs; native fallback unavailable |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 2 | ISSUES OPEN | review 2: 18 issues, 0 critical gaps (1 architecture, 1 code quality, 16 test gaps); all choices answered, work mapped to T11–T15 |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAR | score: 4/10 → 8/10, 12 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **OUTSIDE COVERAGE:** codex, phase plan-review (eng), unavailable in both eng runs (broken CLI); design outside voices declined. No outside coverage.
- **VERDICT:** DESIGN CLEARED. Eng review covers the design changes and has no open decisions; its status stays ISSUES OPEN because findings are mapped to tasks (T1–T15, DT1–DT7) rather than already built; eng review required.

NO UNRESOLVED DECISIONS

