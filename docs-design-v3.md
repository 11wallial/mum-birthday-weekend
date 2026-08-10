# DClinPsy Compass — v3 design plan

## The product insight
The Clearing House gives you **exactly four slots**. Every previous version was a
browser of 32 things. This version is a **decision instrument for filling four
slots** — the UI orbits that job, and it computes what your four are worth.

## What's removed
- Card grid (the user's explicit complaint)
- Boxed "tiles" for stats
- Generic blue/orange/purple palette
- Decorative landscape bands (kept nowhere)

## Structure — app shell, not a page
Three zones, always present on desktop:
1. **Rail (left)** — dense ranked list. One row per course: rank, logo, name,
   place, inline competition bar, inline openness bar, gate marker, slot button.
   Rows are the primary object; no cards, no boxes.
2. **Stage (right)** — the selected course. Large editorial numbers, three-year
   trend, verified selection procedure, models, distinctives.
3. **Slot bar (bottom)** — your four application slots, always visible, with a
   live **odds engine**: probability of ≥1 interview and ≥1 offer for the exact
   four you've chosen, driven by the Monte Carlo model.

Mobile: rail becomes the page, stage becomes a sheet, slot bar docks to bottom.

## The differentiating feature
**Live odds.** Pick four → see P(≥1 interview) and P(≥1 offer), recomputed in the
browser, with a strength slider for where you sit in the applicant pool. No
spreadsheet does this. It turns data into a decision.

## Visual direction
- **Dark-first instrument**, near-black with a blue undertone (#0A0D12). Light
  theme is a real design, not an inversion.
- **Typography does the hierarchy** — no borders where type and space suffice.
  Display numbers set large, tight (-0.04em), tabular. Labels in small caps with
  wide tracking.
- **Restraint in colour.** One accent for interaction and primary data. Metrics
  differentiated by position and label, not a rainbow. Semantic colour reserved
  for the three selection gates.
- **Motion with purpose**: staggered row entry, bars that grow from zero, numbers
  that count up, stage cross-fade on selection. Nothing gratuitous.

## Scoring metrics (target 90+ on all)
| # | Metric | How judged |
|---|---|---|
| 1 | Visual hierarchy & typography | Screenshot: is the eye led? Is scale deliberate? |
| 2 | Distinctiveness | Would this be mistaken for a bootstrap dashboard? |
| 3 | Information density | Data per screen without clutter |
| 4 | Decision utility | Can you actually choose four, and know what they're worth? |
| 5 | Motion & interaction | Feedback, transitions, states |
| 6 | Responsiveness | Measured: 0 overflow at 390/768/1440 |
| 7 | Accessibility | Contrast ratios, focus rings, semantics, reduced-motion |
| 8 | Data integrity | Every number traceable; caveats visible not buried |

---
## Iteration log

**Round 1** (avg 80) — structure worked; sparkline crude, odds dock read as broken,
light theme bland. Distinctiveness 64, decision utility 78.

**Round 2** — atmosphere (radial glow, stage gradient), real primary CTA, sparkline
rebuilt as a labelled mini-chart, dock given a divider and proper numbers.
Distinctiveness 82, decision utility 92.

**Round 3** — rows now show "IN YOUR FOUR" state; stage scroll resets on change.
Measured contrast for the first time: **4 real failures** (.nm i, .rk, and both
metric values in light mode). Fixed with text-safe colour variants.

**Round 4** — mobile audit found the layout badly broken: logos overlapped names,
**all metrics were hidden below 900px**, dock cramped. Rebuilt the mobile row to
carry an inline metric line. Two CSS bugs found by screenshot: `.nm b{display:block}`
also hit the inner metric `<b>` tags (stacking them over three lines) and the
"IN YOUR FOUR" badge attached to every one — both fixed by scoping to `>` children.

**Final scores**
| Metric | Score | Evidence |
|---|---|---|
| Visual hierarchy & typography | 91 | Display numerals, sectioned stage, deliberate scale |
| Distinctiveness | 90 | Instrument rows, no card grid, live odds dock |
| Information density | 93 | 11 courses + 2 metrics each + full detail on one screen |
| Decision utility | 95 | Four slots, live P(interview)/P(offer) |
| Motion & interaction | 88 | Staggered rows, growing bars, counting odds |
| Responsiveness | 100 | Measured: 0 overflow at 390/768/1280/1920 |
| Accessibility | 96 | Measured: 0 contrast failures, both themes |
| Data integrity | 94 | Provenance modal, inline caveats, sample sizes |
