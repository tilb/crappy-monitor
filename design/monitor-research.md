# Monitor research: the ten most-used monitors (2011–2026)

_Status: draft for Ernest's review · Date: 2026-11-03 · For: PRD §8.1 (task T9)_

This is the input for the 2.0 monitor library. Nothing here is in `Presets.json` yet; the
PRD says profiles ship only after review.

## 1. How "most used" was measured

There is no public per-model sales data. Market reports (IDC via Statista and TAdviser)
give vendor shares only: Dell leads PC monitor shipments with roughly 20–23 %, followed by
TPV (AOC and Philips), HP, Lenovo, Samsung and LG.

For per-model prevalence this research uses **linux-hardware.org**, where real computers
report their hardware with `hw-probe`. For each candidate model it counts the computers
that reported that monitor, summed over all EDID product codes of the model. Codes come
from the open **linuxhw/EDID** index (`DigitalDisplay.md`, `AnalogDisplay.md`, CC-BY-4.0).

Counted: about 60 office and consumer models of 21–27 inches, 2011–2026, chosen from the
major vendors' mainstream lines and from the most frequent models in the EDID index.

**Biases, stated plainly:**
- Only Linux users who run hw-probe are counted. Cheap consumer monitors (Samsung,
  Philips, AOC) are probably over-represented; corporate fleets (HP and Lenovo office
  monitors behind managed Windows PCs) are under-represented. HP E24 G4 (40) and Lenovo
  T24i-10 (43) are surely far more common in real offices than these counts suggest.
- Some vendors reuse one EDID code across several models (AOC `AOC2402`: 24B2, 24G2 and
  Q24P2; LG `GSM5B55`: 21.5″ to 31.5″ and 4K). Those codes cannot be attributed to a
  model and were left out of the ranking.
- Counts change between crawls (Dell P2419H code `DELD0DA`: 280 → 369 → 373 across
  snapshots). Treat them as relative, not absolute.

## 2. Ranking (computers on linux-hardware.org, fetched 2026-11-02/03)

| Monitor | Year* | Panel | Computers |
|---|---|---|---|
| Samsung C24F390 | 2015 | VA (SVA), curved | 934 |
| Philips 243V7 | 2017 | IPS | 898 |
| Samsung S24F350 | 2015 | PLS | 892 |
| Dell P2419H | 2018 | IPS | 683 |
| Dell U2412M | 2011 | e-IPS | 618 |
| Dell U2415 | 2014 | AH-IPS | 546 |
| Philips 223V5 | 2011–2014 | TN | 484 |
| Samsung S22F350 | 2016 | TN | 364 |
| Dell U2414H | 2013 | IPS | 343 |
| Samsung S24D300 | 2013 | TN | 326 |
| Philips 273V7 | 2017 | IPS | 287 |
| AOC 2270W (e2270Sw / E2270SWN) | 2013 | TN | 286 |
| Acer K222HQL | 2014 | TN | 239 |
| HP 24f | 2018 | IPS | 238 |
| Dell P2417H · P2422H · P2219H | 2016–2021 | IPS | 218 · 216 · 211 |
| LG 22MP55 | 2013 | IPS | 207 |
| AOC 24B2 family (shared code) | 2019– | IPS | 709, not attributable |

\* Earliest manufacture year seen in the EDID data, a check on the release year.

Incomplete: AOC 2470W and one Acer B246HL code were rate-limited (HTTP 429) and are not
counted.

## 3. The ten (chosen by Ernest, 2026-11-03)

Rule: highest counts, at most three per brand, at least one TN, IPS and VA panel. The AOC
24B2XH was replaced by the AOC 2270W because its count belonged to a shared code.

Dell P2419H · Dell U2412M · Dell U2415 · Samsung C24F390 · Samsung S24F350 · Samsung
S22F350 · Philips 243V7 · Philips 223V5 · AOC 2270W · HP 24f

## 4. Specifications

Rank order below follows the ranking; per PRD §8.2 the first entry would become the
first-run default. Sources are listed in §6 by letter. `≈` marks an estimated or derived
value, "—" a value not found.

| # | Monitor | Released | Panel | Backlight | Size | Resolution | ppi | Brightness | Static contrast | Gamut (spec) |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Samsung C24F390 (C24F390FH) | 2015 [F] | SVA, 1800R curve [A] | W-LED [A] | 23.5″ [A] | 1920 × 1080 | ≈ 94 | 250 cd/m² [A] | 3000:1 [A] | 72 % NTSC [A] |
| 2 | Philips 243V7 (243V7QDSB/QSB) | 2017 [F] | IPS [B] | W-LED [B] | 23.8″ [B] | 1920 × 1080 | 92.6 (0.275 mm pitch) [B] | 250 cd/m² [B] | 1000:1 [B] | — (datasheet lists "sRGB" mode only) [B] |
| 3 | Samsung S24F350 (S24F350FH) | 2015 [F] | PLS [C] | W-LED [A] | 23.5″ [A] | 1920 × 1080 | ≈ 94 | 250 cd/m² [C] | 1000:1 (700:1 min) [C] | 72 % NTSC 1976 [C] |
| 4 | Dell P2419H | 2018 [F] | IPS [D] | W-LED [A] | 23.8″ [D] | 1920 × 1080 | 92.6 | 250 cd/m² [D] | 1000:1 [D] | 72 % CIE 1931 / 82 % CIE 1976 [D] |
| 5 | Dell U2412M | 2011 [E] | e-IPS, LG.Display LM240WU8-SLA2 [E] | W-LED [E] | 24″ [E] | 1920 × 1200 | 94.3 | 300 cd/m² [E] | 1000:1 (measured 947–1139:1) [E] | 71 % NTSC, 95.8 % sRGB [E] |
| 6 | Dell U2415 | 2014 [G] | AH-IPS [A] | W-LED [A] | 24.1″ [A] | 1920 × 1200 | 94 | 300 cd/m² [G] | 1000:1 (measured 1015:1) [G] | 99 % sRGB; 76 % CIE 1931 [G] |
| 7 | Philips 223V5 (223V5LSB) | ≈ 2013 [F] | TN [A] | W-LED [A] | 21.5″ [H] | 1920 × 1080 | 102.5 | 250 cd/m² [H] | 1000:1 [H] | — ("sRGB" mode only) [H] |
| 8 | Samsung S22F350 (S22F350FH) | 2016 [F] | TN [C] | W-LED [A] | 21.5″ [C] | 1920 × 1080 | 102.5 | 200 cd/m² [C] | 1000:1 [C] | 72 % NTSC 1976 [C] |
| 9 | AOC 2270W (≈ e2270Sw / E2270SWN) | ≈ 2013 [F] | TN [I] | W-LED [I] | 21.5″ [I] | 1920 × 1080 | 102.5 (0.248 mm pitch) [I] | 200 cd/m² [I] | 700:1 [I] | — [I] |
| 10 | HP 24f | 2018 [A] | IPS [A] | W-LED [A] | 23.8″ [A] | 1920 × 1080 | 92.6 | 300 cd/m² [A] | 1000:1 [A] | 72 % NTSC [A] |

All ten have **W-LED backlights**; none is CCFL. The CCFL branch of the wear model (PRD
§7.3) is not used by this first library.

## 5. Colour primaries (EDID, source [J])

Values as programmed by the manufacturer into each monitor (CIE 1931 xy), identical across
every sample checked (4 per model, different manufacture years). Coverage and area are
computed against sRGB (0.64,0.33 / 0.30,0.60 / 0.15,0.06).

| Monitor | Red | Green | Blue | White | Gamma | sRGB coverage | Area vs NTSC |
|---|---|---|---|---|---|---|---|
| Samsung C24F390 | 0.6455, 0.3369 | 0.3281, 0.6152 | 0.1464, 0.0556 | 0.3134, 0.3291 | 2.2 | 94.5 % | 72.1 % |
| Philips 243V7 | 0.6523, 0.3359 | 0.3212, 0.6103 | 0.1533, 0.0605 | 0.3134, 0.3291 | 2.2 | 95.0 % | 72.1 % |
| Samsung S24F350 | 0.6503, 0.3330 | 0.3164, 0.6123 | 0.1523, 0.0673 | 0.3134, 0.3291 | 2.2 | 96.0 % | 72.0 % |
| Dell P2419H | 0.6523, 0.3359 | 0.3212, 0.6103 | 0.1533, 0.0605 | 0.3134, 0.3291 | 2.2 | 95.0 % | 72.1 % |
| Dell U2412M | 0.6396, 0.3300 | 0.2998, 0.5996 | 0.1503, 0.0595 | 0.3134, 0.3291 | 2.2 | 99.8 % | 70.7 % |
| Dell U2415 | 0.6601, 0.3320 | 0.3017, 0.6132 | 0.1503, 0.0634 | 0.3134, 0.3291 | 2.2 | 99.8 % | 75.7 % |
| Philips 223V5 | 0.6328, 0.3505 | 0.3222, 0.6298 | 0.1523, 0.0498 | 0.3134, 0.3291 | 2.2 | 92.0 % | 71.9 % |
| Samsung S22F350 (code SAM0D1B) | 0.6337, 0.3515 | 0.3222, 0.6308 | 0.1523, 0.0507 | 0.3134, 0.3291 | 2.2 | 92.0 % | 72.1 % |
| Samsung S22F350 (code SAM0D1A) | 0.6455, 0.3369 | 0.3281, 0.6152 | 0.1464, 0.0556 | 0.3134, 0.3291 | 2.2 | 94.5 % | 72.1 % |
| AOC 2270W | 0.6328, 0.3505 | 0.3222, 0.6298 | 0.1523, 0.0498 | 0.3134, 0.3291 | 2.2 | 92.0 % | 71.9 % |
| HP 24f | 0.6513, 0.3359 | 0.3203, 0.6093 | 0.1523, 0.0605 | 0.3125, 0.3281 | 2.2 | 95.4 % | 71.9 % |

**What this means for the gamut simulation (PRD Vraag 3):**
- The values were found for all ten, so the condition "reconsider if research cannot find
  them" is not met.
- But they say these monitors cover **92–100 % of sRGB**. On a Mac that renders sRGB
  content, the gamut matrix would change colours only slightly (most for the TN models
  Philips 223V5 and AOC 2270W, around 8 % coverage loss).
- They are nominal panel values, not measurements: Philips 243V7 = Dell P2419H, and
  Philips 223V5 = AOC 2270W = one Samsung S22F350 panel source, so panel makers' datasheet
  values are being copied. Real budget panels often measure below their nominal gamut.
- The S22F350 ships with two panel sources (two codes, two sets of primaries).

## 6. Sources

- [A] displayspecifications.com model pages (third-party spec database; values read from
  search-result extracts because the site blocks automated page loads): C24F390FH
  `/en/model/5e083aa`, S24F350F `/en/model/29676ad`, S22F350F `/en/model/c4686af`,
  P2419H `/en/model/4d1d1390`, U2415 `/en/model/f3cb58`, 223V5LSB `/en/model/1d9412df`,
  HP 24f `/en/model/2a2712dd`.
- [B] Philips 243V7QSB/01 leaflet, version 8.1.1, issue date 2024-03-25,
  documents.philips.com (`…/20230608/6564caa612f14fe7ad23b01b00fa5d63.pdf`).
- [C] Samsung business product pages: S24F350F (samsung.com/ie, `led-ls24f350fhuxen`),
  S22F350FHU (samsung.com/ie, `led-ls22f350fhuxen`). Note: Samsung India lists the
  S24F350FHW as AH-IPS; the Irish page says PLS.
- [D] Dell P2419H data sheet (i.dell.com, `dell_24_monitor_p2419h_data_sheet.pdf`) and
  user's guide (dl.dell.com).
- [E] TFTCentral review of the Dell U2412M, 24 August 2011 (manufacturer spec table and
  measurements).
- [F] Earliest manufacture year in the linuxhw/EDID index for that model.
- [G] Dell U2415 user's guide (dl.dell.com) and TFTCentral review of the U2415.
- [H] Philips 223V5LSB product sheet (download.p4c.philips.com, `223v5lsb_00_pss_engie.pdf`).
  The 223V5LSB2 variant lists 200 cd/m² and 600:1.
- [I] AOC E2270SWN specification page, aoc.com/uk.
- [J] linuxhw/EDID decoded EDID files (github.com/linuxhw/EDID), CC-BY-4.0, credit
  required in the app's About window.
- Prevalence: linux-hardware.org device pages (`?id=eisa:<vendor>-<code>`); vendor
  shares: Statista (IDC, Q2 2022) and TAdviser (IDC, 2019–2020).

## 7. For Ernest to check

1. **AOC 2270W attribution.** The EDID name "2270W" is most likely the AOC e2270Sw(n)
   (TN, 21.5″); its primaries match the Philips 223V5 TN panel. The specs used are AOC's
   E2270SWN page. Confidence: medium.
2. **Philips 223V5 release year.** EDID data shows units from 2011, earlier than the
   223V5LSB's usual 2013–2014 date; possibly an earlier 223V5 variant. Marked ≈ 2013.
3. **Samsung S24F350 panel type.** PLS on the Irish page, AH-IPS on the Indian page. Both
   are IPS-like; the profile uses IPS-like behaviour either way.
4. **Gamut simulation.** Keep it (cheap, honest, small effect), or drop it for 2.0 now that
   the values show little difference from sRGB? See §5.
5. **Office bias.** The list is consumer-heavy because of the data source. HP E24 G4 and
   Lenovo T24i are obvious additions once in-app or GitHub requests arrive.
