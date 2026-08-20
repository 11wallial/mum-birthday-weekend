# CAMHS Outreach poster

A3 landscape (420 × 297 mm) outreach poster, rebuilt as an editable HTML source.

## Files

- `poster.html` — the source. Self-contained: the Archivo webfont is embedded as
  base64, so it renders identically offline. Open it in a browser to preview.
- `outreach_poster_v2.pdf` — the print-ready export.

## Background

The original was supplied as a PDF containing a single flattened JPEG, so it had
no editable text layer. The layout was measured off that image (margins, column
grid, rules, box positions, type sizes and letter-spacing) and rebuilt in HTML/CSS
so the copy can be edited from now on. All positions match the original to within
about 0.7 mm.

The typeface is Archivo (Google Fonts, SIL Open Font License), which matches the
original's letterforms — including its distinctive "Ɛ"-shaped ampersand.

## Changes in this version

- **01 What we do** — added: "We also act as the mental health liaison for under 10s."
- **03 The team** — added *mental health navigators* to the list of professionals.
- **03 The team** — replaced the *CBT* and *Psychoeducation* intervention tags with a
  single *Psychological Interventions* tag.
- **Referral box** — "significant risk of harm" → "significant safety concerns".

Note: the blue referral banner across the top still reads "significant risk of harm".
It was left as-is because the change was requested only for the referral box.

## Re-exporting the PDF

Print to PDF from a browser at A3 landscape with margins set to none and background
graphics enabled. The page carries `@page { size: A3 landscape; margin: 0 }`, so
"paper size: from page" produces the correct dimensions.
