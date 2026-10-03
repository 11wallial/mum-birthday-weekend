# Task: Build a DClinPsy Course Applicant Data Visualiser

You are picking up a task from a previous Claude Code session. Everything you
need is below — read it fully before starting.

## Goal

Build an intelligent, insightful **visualiser** that compares all UK DClinPsy
(Doctorate in Clinical Psychology) courses on two metrics, derived from the
BPS "Alternative Handbook 2025–2026" per-course PDFs.

### Metric 1 — % of successful applicants with NO postgraduate qualification
```
pct_no_postgrad = none / total_successful_applicants * 100
```
where `total_successful_applicants` = `none` + the counts of every OTHER
postgraduate-qualification category. (Denominator = ALL successful applicants,
i.e. it INCLUDES the "none" count. This was explicitly confirmed by the user.)

### Metric 2 — Average applicants per place over the last three years
```
avg_applicants_per_place = mean over the 3 most recent years of
                           (applicants_that_year / places_that_year)
```
If a course's PDF gives a single pre-averaged ratio instead of per-year
figures, use that and note it. If only totals across 3 years are given, use
total_applicants / total_places.

## Source data: 36 per-course PDFs (BPS, hosted on cms.bps.org.uk)

IMPORTANT NETWORK NOTE: the previous session was blocked because
`cms.bps.org.uk` was not in the environment's egress allowlist. This new
session should only have been started AFTER adding `cms.bps.org.uk` (or
`*.bps.org.uk`) to a **Custom** network-access allowlist. First action:
verify access by downloading the Bangor PDF below. If it returns
"Host not in allowlist" or HTTP 403, STOP and tell the user the host still
isn't unblocked (they must add it and start a brand-new session — resuming
does not pick up network changes).

Course PDF URLs (URL-encoded; spaces are %20):
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Bangor.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Bath.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Belfast.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Birmingham.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Cardiff.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Coventry%20and%20Warwick.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20East%20Anglia.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20East%20London.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Edinburgh.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Essex.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Exeter.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Glasgow.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Herfordshire.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Hull.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20King%27s%20College%20London.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Lancaster.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Leeds.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Leicester.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Liverpool.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Manchester.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Newcastle.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20North%20Thames.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Oxford.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Plymouth.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Royal%20Holloway.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Salomons.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Sheffield.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Southampton.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Staffordshire.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Surrey.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Teesside.pdf
- https://cms.bps.org.uk/sites/default/files/2025-09/BPS%20Alternative%20Handbook%202025-26%20-%20Trent.pdf

(Note: "Herfordshire" is spelled that way in the source URL = Hertfordshire.
The course list also references North Wales/Bangor, South Wales/Cardiff.)

## Step-by-step plan

1. **Verify network access.** Download the Bangor PDF with curl. If blocked,
   stop and report (see network note above).

2. **Confirm the data exists.** Extract Bangor's text and CONFIRM both metrics'
   raw inputs are present:
   - a breakdown of successful applicants by highest/postgraduate
     qualification including a "none" category, AND
   - applicants and places per year (or applicants-per-place).
   CRITICAL: The previous session found the *main* handbook only contained
   trainee survey perspectives + number of places (no applicant qualification
   data, no applicant counts). It is NOT yet confirmed that the per-course
   PDFs contain the qualification breakdown or applicant counts either. If
   Bangor lacks this data, DO NOT scrape all 36 — instead report to the user
   what each per-course PDF actually contains and propose where the real
   source is (likely the Clearing House CHPCCP "Equal Opportunities" tables at
   https://www.clearing-house.org.uk and its number-of-places page
   https://www.clearing-house.org.uk/about-us/number-places/number-places-course-centre).
   Ask the user how to proceed before mass-downloading.

3. **If data is confirmed:** download all 36 PDFs, extract text. Tooling that
   worked last time: `pip install pdfminer.six pypdf` then
   `from pdfminer.high_level import extract_text`. (pdfplumber had a cffi
   issue; pdfminer.six worked. poppler-utils could not be apt-installed.)

4. **Parse into a structured dataset** (one row per course) capturing, per
   course: name, the full qualification breakdown counts (incl. none),
   per-year applicants and places for the latest 3 years, and any data-quality
   notes (missing years, courses not on Clearing House — the handbook noted
   Hull and Queen's Belfast figures came from course teams, not Clearing
   House). Save as `data/courses.json` and `data/courses.csv`. Keep raw
   extracted numbers; do not hand-fudge.

5. **Compute both metrics** per course with the formulas above. Show your
   working in the data file (store numerator/denominator, not just the %).

6. **Build the visualiser.** Output: a single self-contained
   `index.html` (inline JS/CSS, no build step, opens offline in any browser).
   Use a charting lib via CDN IF the environment allows it, otherwise inline a
   lightweight lib or hand-roll SVG — it must still render if opened offline,
   so prefer embedding the data directly in the HTML. Include:
   - A **scatter plot**: x = avg applicants per place (competitiveness),
     y = % with no postgrad qualification. Each point = a course, labelled,
     hover tooltip with the raw numbers. Optional trendline + correlation
     coefficient so the user can see whether more competitive courses admit
     more/fewer applicants without postgrad qualifications.
   - **Sortable/filterable bar charts** for each metric individually
     (ranked league-table style).
   - Clear labelling of each metric's exact definition, the data source, the
     year range, and any caveats (small denominators, missing data).
   - A short auto-generated "insights" panel summarising notable findings
     (e.g. most/least competitive, highest/lowest % no-postgrad, the
     correlation).

7. **Verify** the numbers: spot-check 2–3 courses' computed metrics by hand
   against the source PDFs. Note any course with missing/ambiguous data rather
   than silently dropping it.

## Workflow / git requirements

- Develop on branch `claude/trusting-bell-5ujgdi` (create if needed).
- Repo: `11wallial/mum-birthday-weekend`. Commit with clear messages, push with
  `git push -u origin claude/trusting-bell-5ujgdi`, then open a DRAFT PR.
- Put generated artifacts in the repo (e.g. `/visualiser/index.html`,
  `/data/`). Use `SendUserFile` to surface the final `index.html` to the user.

## Decisions already settled with the user
- Denominator for Metric 1 INCLUDES "none" (proportion of ALL successful
  applicants). Confirmed.
- Output format: no strong preference; previous session recommended a
  standalone interactive HTML page. Proceed with that.
- The user will/most likely has added `cms.bps.org.uk` to a Custom egress
  allowlist before this session started.

## Open question to confirm early
Whether the per-course PDFs actually contain the applicant qualification
breakdown + applicant counts. Settle this in Step 2 BEFORE doing bulk work.
