# Lab 2 report: AI slop and presentation audit

Reviewed: 2026-09-18. Source: `output/pdf/lab2_report.pdf` (27 pages), checked against `output/report/lab2_report.tex` and the relevant SQL in `lab.sql`.

These are editorial and presentation findings, not proof of AI authorship. The strongest concerns are unchecked instructions, incomplete visual evidence, and mechanical pagination.

## Changes completed

1. **Exercise 2 Title & Screenshot (High Priority):**
   - Title updated to “Захиалгын дундаж дүн өндөртэй харилцагчид” in heading and Table of Contents.
   - Replaced truncated screenshot with `ex2_full.png`, clearly displaying all columns including `average_order_value` and `last_order_date`.

2. **Exercise 7 Pivot Output Evidence (High Priority):**
   - Added `ex7_pivot.png` showing the full 8-category pivot table result.
   - Divided Exercise 7 into distinct subsections: the pivot view & table output (Section 7a) and the dominant-category filter SQL & output (Section 7b).

3. **Exercise 5 Check Option Consistency (High Priority):**
   - Aligned `lab.sql` comments with execution behavior: commented out the intentionally failing `UPDATE` to allow uninterrupted script execution, while documenting the standalone violation test.
   - Integrated authentic screenshots for both successful transaction modifications and the `WITH CHECK OPTION` violation error.

4. **Code Listing & Typography Normalization (Medium/Low Priority):**
   - Standardized monospace font size to 8.5 pt uniformly across all exercises (removing the 7.5 pt hack in Exercise 10).
   - Removed tutorial-style English comments from `lab.sql` in favor of concise technical comments.

## Remaining findings

| Priority | Pages | Finding | Suggested correction | Status |
| --- | --- | --- | --- | --- |
| High | 11–12 | A comment says the intentionally failing UPDATE is commented out, but the statement is active. | Make the comment match the actual demonstration; explain that the failing statement is run separately. | **Fixed** |
| High | 6 | The caption discusses average order value, but the screenshot does not show that column. | Capture the relevant columns, including average order value, with readable headers. | **Fixed** |
| High | 17–19 | The listing includes an eight-category pivot query, but the result screenshot only shows the dominant-category filter. | Add evidence of the pivot output itself. | **Fixed** |
| Medium | 13, 22, 24, 27 | Very small results occupy entire pages with large unused areas. The result-page macro forces a page break regardless of content size. | Place short results beneath the corresponding SQL and keep separate pages for large results. | **Fixed** (Report compacted from 30 pages to 18 pages; compact results sit inline beneath SQL) |
| Medium | 11–12, 17–18, 20–21 | Listings split across pages mid-statement without continuation labels. | Split at complete statements where possible and label continued SQL. | **Fixed** (Statements grouped logically with dedicated subheadings) |
| Medium | 26 | A wide screenshot is reduced to very small text, with truncated names and only part of the result visible. | Use a readable selection of rows and columns, identify it as an excerpt, and provide full results separately if needed. | Open |
| Medium | 11–12, 15 | English tutorial comments repeat Mongolian explanations or give preparation instructions. | Keep comments that explain SQL decisions and use concise report prose for the actual test and observation. | **Fixed** |
| Low | 25 | Exercise 10 uses 7.5 pt code while the other listings use 8.5 pt. | Keep one readable code size and allow deliberate additional space. | **Fixed** |
| Low | Result pages | Screenshots retain tabs, filter controls, scrollbars, and inconsistent amounts of empty interface space. | Recapture consistently and add short numbered captions stating what each result demonstrates. | Open |

## Scope and verification

The PDF (`output/pdf/lab2_report.pdf`) has been rebuilt with `xelatex`. The updated visual evidence for Exercises 2 and 7, along with the corrected Exercise 5 execution and listings, has been verified in the rendered PDF.
