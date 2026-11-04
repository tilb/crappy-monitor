# Monitor research: the ten monitors large organisations use most (2011–2026)

_Status: draft for Ernest's review · Date: 2026-11-04 · For: PRD §8.1 (task T9)_

The 2.0 library is for designers who design for people at work in healthcare, transport,
call centres, government and other large organisations. So the question is not "which
monitors sell most" but **"which monitors sit on the desks of large organisations"**,
for Europe and the US. Nothing here is in `Presets.json` yet; the PRD says profiles ship
only after review.

## 1. Method

**Candidates.** About 100 models from the business lines that organisations buy in bulk,
2011–2026, 21.5–24″: Dell P, E and U series; HP EliteDisplay, E and P series and LA;
Lenovo ThinkVision T, E and LT; Fujitsu B, E and P; iiyama ProLite; EIZO FlexScan; NEC
EA; Philips B-line (no Philips B-line model was found in the data).

**Prevalence.** For each model, the number of computers that reported it on
**linux-hardware.org** (hw-probe), summed over all of the model's EDID product codes from
the open **linuxhw/EDID** index (CC-BY-4.0). Fetched 2026-11-03/04.

**Organisation signal.** Each model page lists a sample of the computers the monitor was
attached to (about 10–50 per model). The share of business machines in that sample
(Dell OptiPlex/Latitude/Precision/Vostro, HP EliteBook/EliteDesk/ProBook/ProDesk/Z,
Lenovo ThinkPad/ThinkCentre/ThinkStation, Fujitsu Esprimo/Lifebook/Celsius, Acer
TravelMate/Veriton, ASUS ExpertBook) is the organisation signal. **Baseline:** the
consumer monitors from the first round (Samsung C24F390, Samsung S24F350, Philips 243V7,
AOC 2270W) sat on a business machine in 2 of 51 samples (4 %). Business-line monitors sat
on one in 10–57 % of samples.

**Ranking measure.** Estimated business-attached units = computers × business share.

**Supporting evidence (qualitative).** Dell leads PC monitor shipments with about
20–23 %, followed by TPV (AOC/Philips), HP and Lenovo (IDC via Statista and TAdviser).
US government surplus is auctioned in lots of Dell P2417Hb monitors (GSA Auctions,
2026). Insight lists the Dell P2419H and Lenovo T24i among its top-selling refurbished
monitors; refurbishers sell the T24i in A/B/C grades (PCLiquidations, refurbed). No public
tender awards naming models were found; those sit in closed procurement portals.

**Limits, stated plainly.**
- linux-hardware.org only sees computers whose users run hw-probe; managed corporate
  fleets rarely do, so absolute numbers are small and favour IT staff and developers.
  The organisation share corrects for this only partly.
- Samples are small (10–50 computers per model); treat the shares as rough.
- New models (2021+) are under-represented because the data lags years behind
  purchases: the Dell P2422H (2021) already scores 44, the P2425H (2024) has no data.
- Some vendors reuse one EDID code across models; such codes were left out.

## 2. Ranking (business-line models, top 25)

| Monitor | Computers | Business share (sample) | Est. business-attached |
|---|---|---|---|
| Dell P2419H | 683 | 33 % (39) | 228 |
| Dell U2412M | 1034 | 18 % (44) | 188 |
| Dell P2417H | 365 | 24 % (33) | 88 |
| Dell U2414H | 396 | 16 % (38) | 63 |
| Dell U2415 | 546 | 11 % (53) | 62 |
| Dell P2317H | 252 | 23 % (30) | 59 |
| HP EliteDisplay E243 | 146 | 38 % (29) | 55 |
| Lenovo ThinkVision T24i-10 | 97 | 57 % (23) | 55 |
| Dell P2319H | 183 | 29 % (38) | 53 |
| HP LA2205wg | 212 | 24 % (25) | 51 |
| Dell P2414H | 339 | 15 % (27) | 50 |
| Dell U2419H | 118 | 41 % (22) | 48 |
| EIZO FlexScan EV2450 | 149 | 30 % (46) | 45 |
| Dell P2422H | 255 | 17 % (46) | 44 |
| Lenovo ThinkVision LT2252p | 171 | 25 % (12) | 43 |
| Dell P2219H | 212 | 20 % (30) | 42 |
| HP LA2405wg | 126 | 30 % (27) | 37 |
| HP EliteDisplay E231 | 254 | 14 % (44) | 35 |
| HP EliteDisplay E232 | 166 | 21 % (29) | 34 |
| Dell P2212H | 116 | 29 % (17) | 34 |
| Dell P2214H | 298 | 11 % (35) | 34 |
| Dell P2217H | 223 | 15 % (27) | 33 |
| iiyama ProLite XU2492HSU | 133 | 21 % (19) | 28 |
| NEC EA244WMi | 110 | 22 % (46) | 24 |
| HP E24 G4 | 41 | 33 % (27) | 14 |

## 3. The ten (chosen by Ernest, 2026-11-04)

Rules: highest estimated business-attached units, at most three per brand, at least one
European fleet brand, spread over the years. In rank order (the first is the first-run
default, PRD §8.2):

1. Dell P2419H · 2. Dell U2412M · 3. Dell P2417H · 4. HP EliteDisplay E243 ·
5. Lenovo ThinkVision T24i-10 · 6. HP LA2205wg · 7. EIZO FlexScan EV2450 ·
8. Lenovo ThinkVision LT2252p · 9. iiyama ProLite XU2492HSU · 10. HP E24 G4

**No VA panel.** Organisations bought IPS and, earlier, TN; VA barely appears in the
fleet data (best candidate HP P222va: 32 computers). That is a finding, not a gap.

## 4. Specifications

Sources are listed in §6 by letter. `≈` marks an estimated or derived value, "—" a
value not found. Gamut percentages use the standard the source names (Dell and Lenovo:
CIE 1931 NTSC).

| # | Monitor | Released | Panel | Backlight | Size | Resolution | ppi | Brightness | Static contrast | Gamut (spec) |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Dell P2419H | 2018 [F] | IPS [D] | W-LED [D] | 23.8″ | 1920 × 1080 | 92.6 | 250 cd/m² [D] | 1000:1 [D] | 72 % NTSC (CIE 1931) [D] |
| 2 | Dell U2412M | 2011 [E] | e-IPS, LG.Display LM240WU8-SLA2 [E] | W-LED [E] | 24″ | 1920 × 1200 (16:10) | 94.3 | 300 cd/m² [E] | 1000:1 (measured 947–1139:1) [E] | 71 % NTSC, 95.8 % sRGB [E] |
| 3 | Dell P2417H | 2016 [F] | IPS [K] | W-LED [K] | 23.8″ | 1920 × 1080 | 92.6 | 250 cd/m² [K] | 1000:1 [K] | 72 % NTSC (CIE 1931), 82 % (CIE 1976) [K] |
| 4 | HP EliteDisplay E243 | ≈ 2016 [F] | IPS [L] | W-LED [L] | 23.8″ | 1920 × 1080 | 92.6 | 250 cd/m² [L] | 1000:1 [L] | — (72 % NTSC is the E243m's figure) [L] |
| 5 | Lenovo ThinkVision T24i-10 | 2017 [F] | IPS [M] | W-LED [M] | 23.8″ | 1920 × 1080 | 92.6 | 250 cd/m² [M] | 1000:1 [M] | 72 % NTSC (CIE 1931) [M] |
| 6 | HP LA2205wg | ≈ 2009 [F] | TN [N] | ≈ CCFL [N] | 22″ | 1680 × 1050 (16:10) | 90.1 [O] | 250 cd/m² [N] | 1000:1 [N] | — |
| 7 | EIZO FlexScan EV2450 | 2014 [P] | AH-IPS, LG.Display LM238WF2-SSC1, 6-bit + FRC [P] | W-LED [P] | 23.8″ | 1920 × 1080 | 92.6 | 250 cd/m² (measured 250.4) [P] | 1000:1 (measured 1071:1) [P] | ≈ sRGB, ~72 % NTSC [P] |
| 8 | Lenovo ThinkVision LT2252p | 2011 [Q] | TN [Q] | W-LED [Q] | 22″ | 1680 × 1050 (16:10) | 90.1 (computed; PSREF rounds the pitch to 0.28 mm) [Q] | 250 cd/m² [Q] | 1000:1 [Q] | 72 % [Q] |
| 9 | iiyama ProLite XU2492HSU | 2016 [F] | AH-IPS [R] | W-LED [R] | 23.8″ | 1920 × 1080 | 92.6 | 250 cd/m² [R] | 1000:1 [R] | 99 % sRGB, 72 % NTSC [R] |
| 10 | HP E24 G4 | 2020 [S] | IPS [S] | W-LED [S] | 23.8″ | 1920 × 1080 | 92.6 | 250 cd/m² [S] | 1000:1 [S] | 72 % NTSC [S] |

The HP LA2205wg is the only monitor with a (probable) CCFL backlight: HP's QuickSpecs
give a backlight "lamp life to half brightness" of 50,000 hours, which is CCFL wording,
and a retailer lists CCFL; no HP document says CCFL in so many words. It is also older
than the 15-year window (EDID manufacture dates 2009–2012), but it was still on desks
well into the window.

## 5. Colour primaries (EDID, source [J])

Values as programmed by the manufacturer into each monitor (CIE 1931 xy); identical across
the samples checked (3–4 per model, different manufacture years). Coverage and area are
computed against sRGB and NTSC 1953.

| Monitor | Red | Green | Blue | White | sRGB coverage | Area vs NTSC |
|---|---|---|---|---|---|---|
| Dell P2419H | 0.6523, 0.3359 | 0.3212, 0.6103 | 0.1533, 0.0605 | 0.3134, 0.3291 | 95.0 % | 72.1 % |
| Dell U2412M | 0.6396, 0.3300 | 0.2998, 0.5996 | 0.1503, 0.0595 | 0.3134, 0.3291 | 99.8 % | 70.7 % |
| Dell P2417H | 0.6523, 0.3359 | 0.3212, 0.6103 | 0.1533, 0.0605 | 0.3134, 0.3291 | 95.0 % | 72.1 % |
| HP EliteDisplay E243 | 0.6386, 0.3574 | 0.3085, 0.6376 | 0.1523, 0.0693 | 0.3134, 0.3291 | 92.4 % | 73.1 % |
| Lenovo T24i-10 | 0.6396, 0.3300 | 0.2998, 0.5996 | 0.1503, 0.0595 | 0.3134, 0.3291 | 99.8 % | 70.7 % |
| HP LA2205wg | 0.6406, 0.3349 | 0.2978, 0.6113 | 0.1474, 0.0703 | 0.3134, 0.3291 | 96.5 % | 71.8 % |
| EIZO EV2450 | 0.6552, 0.3349 | 0.3300, 0.6103 | 0.1503, 0.0595 | 0.3134, 0.3291 | 93.7 % | 72.3 % |
| Lenovo LT2252p | 0.6445, 0.3417 | 0.3085, 0.6201 | 0.1513, 0.0585 | 0.3134, 0.3291 | 97.3 % | 73.5 % |
| iiyama XU2492HSU (code IVM618E) | 0.6503, 0.3281 | 0.3115, 0.6191 | 0.1513, 0.0468 | 0.3134, 0.3291 | 97.3 % | 76.0 % |
| iiyama XU2492HSU (code IVM612F) | 0.6474, 0.3330 | 0.3076, 0.6142 | 0.1533, 0.0458 | 0.3134, 0.3291 | 97.4 % | 74.8 % |
| HP E24 G4 | 0.6230, 0.3359 | 0.2958, 0.6171 | 0.1435, 0.0664 | 0.3134, 0.3291 | 94.1 % | 70.5 % |

**What this means for the gamut simulation (PRD Vraag 3).**
- Values were found for all ten, so the condition "reconsider if research cannot find
  them" is not met.
- They say these monitors cover **92–100 % of sRGB**, so the gamut matrix would change
  colours only slightly. The HP E24 G4 is the clearest case: its red sits well inside
  sRGB (x 0.623 against 0.64).
- They are nominal panel values, not measurements. Two are exactly the sRGB standard
  (Dell U2412M, Lenovo T24i-10), and the Dell P2419H and P2417H share one set, so panel
  datasheet values are being copied. Real panels, especially aged ones, often measure
  below them.

## 6. Sources

- [D] Dell P2419H data sheet (i.dell.com, `dell_24_monitor_p2419h_data_sheet.pdf`) and
  user's guide (dl.dell.com).
- [E] TFTCentral review of the Dell U2412M, 24 August 2011 (manufacturer spec table and
  measurements).
- [F] Earliest manufacture year in the linuxhw/EDID index for that model (a check on the
  release year).
- [J] linuxhw/EDID decoded EDID files (github.com/linuxhw/EDID), CC-BY-4.0, credit
  required in the app's About window.
- [K] Dell P2217H/P2317H/P2417H/P2717H user's guide (dl.dell.com).
- [L] HP Store Canada listing and HP support specifications page for the HP EliteDisplay
  E243 (support.hp.com, product 17210316). No QuickSpecs found.
- [M] Lenovo PSREF, ThinkVision T24i-10 specifications and datasheet (psref.lenovo.com).
- [N] HP QuickSpecs for the LA2205wg (NM274AA), as quoted on manualmachine.com /
  manualsdir.com; CCFL per a Ukrainian retailer listing (compbest.com.ua). Treat as
  secondary.
- [O] HP Compaq LA1905wg/LA2205wg/LA2405wg user guide, Table A-2 (h10032.www1.hp.com,
  `c03285508.pdf`).
- [P] EIZO FlexScan EV2450 product page (eizo.com) and TFTCentral EV2450 review; release
  per EIZO press release (EV2455/EV2450).
- [Q] Lenovo PSREF ThinkVision LT2252p specifications (psref.lenovo.com); announced
  September 2011 (Lenovo press release).
- [R] iiyama ProLite XU2492HSU-B1 product page (iiyama.com).
- [S] HP E24 G4 FHD Monitor QuickSpecs (h20195.www2.hp.com, `c06922717.pdf`) and
  datasheet.
- Prevalence: linux-hardware.org device pages (`?id=eisa:<vendor>-<code>`); vendor
  shares: Statista (IDC, Q2 2022), TAdviser (IDC, 2019–2020); fleet evidence: GSA
  Auctions (computer.govsales.us, 2026-02-26), Insight certified refurbished monitors,
  PCLiquidations, refurbed.

## 7. For Ernest to check

1. **HP LA2205wg backlight.** CCFL is likely but only secondary-sourced. It decides
   whether the CCFL wear rate (PRD §7.3) applies.
2. **HP EliteDisplay E243 gamut.** Not found for the E243 itself; only its sibling E243m
   lists 72 % NTSC. The EDID primaries are used either way.
3. **Gamut simulation.** Keep it (cheap, honest, small effect), or drop it for 2.0 now
   that the values show little difference from sRGB? See §5.
4. **Two models, one look.** Dell P2419H and P2417H share panel class and primaries;
   their profiles will look nearly identical. Fine for "which monitor do I have", less so
   for variety.

## Appendix: first round (consumer-weighted)

The first round ranked all mainstream models by computer counts alone and picked Samsung
C24F390, Philips 243V7, Samsung S24F350, Dell P2419H, Dell U2412M, Dell U2415, Philips
223V5, Samsung S22F350, AOC 2270W and HP 24f. Ernest set it aside on 2026-11-04 because
it reflects home and budget use rather than the organisations the target designers work
for. Its data (specs and EDID primaries for those ten) is in git history
(commit `8d3d448`) and can seed later library additions.
