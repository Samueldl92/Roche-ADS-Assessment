# DSX Data Scientist Coding Assessment

Solutions to the R part (questions 1 to 4) and the Python part (questions 5 and 6).
Everything runs from the repository root.

## Repository layout

```
question_1/descriptive_stats/   R package descriptiveStats (Q1)
question_2_sdtm/                SDTM DS domain with {sdtm.oak} (Q2)
question_3_adam/                ADSL with {admiral} (Q3)
question_4_tlg/                 TEAE table, plots and listing (Q4)
question_5_api/                 FastAPI service (Q5)
question_6_genai/               Natural language AE query agent (Q6)
data/adae.csv                   AE data exported from R for Q5 and Q6
data/export_adae.R              script that regenerates data/adae.csv
R-sessionInfo.txt               R version and package versions used
```

## Versions

R 4.3.3 on Windows. All packages installed from CRAN, no version had to be
pinned below the latest because every package supports R 4.3.3.

| Package | Version |
|---------|---------|
| sdtm.oak | 0.2.0 |
| admiral | 1.5.0 |
| pharmaverseraw / pharmaversesdtm / pharmaverseadam | 0.1.1 / 1.5.0 / 1.4.0 |
| gtsummary / gt | 2.6.1 / 1.4.0 |
| ggplot2 / dplyr / lubridate / stringr | 4.0.3 / 1.2.1 / 1.9.5 / 1.6.0 |
| devtools / roxygen2 / testthat | 2.5.2 / 8.1.1 / 3.3.2 |

The full list with `sessionInfo()` is in `R-sessionInfo.txt`. Install everything with:

```r
install.packages(c(
  "admiral", "sdtm.oak", "pharmaverseraw", "pharmaversesdtm", "pharmaverseadam",
  "gtsummary", "gt", "ggplot2", "dplyr", "tidyr", "lubridate", "stringr",
  "scales", "devtools", "roxygen2", "testthat"
))
```

## How to run

```sh
Rscript data/export_adae.R
Rscript question_2_sdtm/02_create_ds_domain.R
Rscript question_3_adam/create_adsl.R
Rscript question_4_tlg/01_create_ae_summary_table.R
Rscript question_4_tlg/02_create_visualizations.R
Rscript question_4_tlg/03_create_listings.R
```

For Q1:

```r
devtools::install("question_1/descriptive_stats")
devtools::test("question_1/descriptive_stats")
devtools::check("question_1/descriptive_stats")
```

`devtools::check()` needs Rtools for the installed R version. On a machine
without it, `R CMD build` followed by `R CMD check --no-manual` gives the same
result (Status: OK, no errors, warnings or notes).

## Outputs

| Question | Output |
|----------|--------|
| Q1 | package with 148 passing tests, `R CMD check` Status: OK |
| Q2 | `question_2_sdtm/ds.csv` (850 records, 12 variables) |
| Q3 | `question_3_adam/adsl.csv` (306 subjects), `adsl_checks.txt` |
| Q4 | `ae_summary_table.html`, `plot1_ae_severity_by_treatment.png`, `plot2_top10_ae_incidence_ci.png`, `ae_listings.html` |

## Design decisions and problems solved

### Q1 descriptiveStats

* The statement lists `calc_mean(data) # 3.3`, but the ten values add up to 43,
  so the mean is 4.3. The tests check 4.3.
* The expected `Q1 = 2.5` and `Q3 = 5.5` match none of the nine quantile types of
  `stats::quantile()` (type 7 gives 2.25 and 5, type 6 gives 2 and 5.25) nor the
  median of each half (2 and 5). The one simple rule that gives them is position
  `h = p * n + 1` on the sorted data with linear interpolation, `h` capped at `n`.
  It is the default (`type = "assessment"`), and `type = 1:9` selects a standard
  definition. The consequence of that rule is that for very small samples Q3 can
  equal the maximum, which is documented in the help page.
* Empty input returns `NA` with a warning, `NA` values return `NA` unless
  `na.rm = TRUE`, a mode with ties returns all tied values and no mode returns `NA`.
  `Inf` is rejected because it makes the quartiles ill defined.
* All input checks live in one internal helper so the six functions behave the same way.

### Q2 DS domain

* Mapping rules come from the annotations of the Subject Disposition aCRF:
  `OTHERSP` populated gives `DSTERM` and `DSDECOD` from `OTHERSP` and
  `DSCAT = "OTHER EVENT"`; "Randomized" gives `PROTOCOL MILESTONE`; the rest gives
  `DISPOSITION EVENT`. Conditional mappings use `condition_add()`.
* "Randomized" is not in the study CT, so it is mapped without CT, the rest goes
  through codelist C66727.
* `VISITNUM` comes from a small lookup of the visit schedule, and unscheduled
  visits take the number from their label (`Unscheduled 4.1` becomes 4.1).
* The result was compared with `pharmaversesdtm::ds`: all eight compared variables
  agree on every record. That comparison is printed at the end of the script.
  `DSSEQ` orders by start date and then raw record order, because ordering by
  term shuffled records that share a date.
* `sdtm.oak` prints an informational message about terms that were not found in
  `collected_value`. The final `DSDECOD` is fully populated and equals the reference.

### Q3 ADSL

* `AGEGR9` uses `derive_vars_cat()`, treatment dates use `derive_vars_dtm()` with
  `highest_imputation = "h"` and `ignore_seconds_flag = TRUE`, and the first
  valid-dose exposure is picked with `derive_vars_merged()`. `ABNSBPFL` and
  `CARPOPFL` use `derive_var_merged_exist_flag()`, `LSTALVDT` uses
  `derive_vars_extreme_event()` over VS, AE, DS and the last exposure date.
* Valid dose: `EXDOSE > 0`, or `EXDOSE == 0` with `PLACEBO` in `EXTRT`.
* In this data every `EXSTDTC` is date only, so `TRTSTMF` is `H` for all treated
  subjects. The 52 screen failures have no valid dose, so `TRTSDTM` is missing.
* `ITTFL` follows the specification literally (`ARM` populated). The screen
  failure arm has `ARM = "Screen Failure"`, so all 306 subjects are `Y`.
* `ABNSBPFL` follows the detailed specification (`VSTESTCD`, `VSSTRESU`, value
  range) and does not filter on position. Restricting to supine readings would
  give 213 instead of 233 subjects; both counts are in `adsl_checks.txt`.
* The script recomputes `CARPOPFL` and `ABNSBPFL` directly from SDTM and stops if
  they disagree.

### Q4 TLG

* The table uses `tbl_hierarchical()` with AESOC and AETERM, denominators from
  ADSL (safety population, 254 subjects), an "Any TEAE" row and a Total column.
  Rows are sorted by descending frequency with `sort_hierarchical()`.
* Plot 2 uses the exact (Clopper-Pearson) interval from `binom.test()`, which is
  reliable for the small counts in the tail of the top 10.
* `{gtsummary}` has no listing function (`tbl_listing()` lives in {gtreg}), so the
  listing data frame is wrapped with `as_gtsummary()` and exported through `gt`.

### Data for Q5 and Q6

`data/adae.csv` is `pharmaversesdtm::ae` with all its columns. The SDTM AE domain
has no treatment arm, but Q5 filters on `ACTARM`, so `ACTARM` is joined from `dm`
(one row per subject, no records are added or lost).

## What I learned

Q1: stating the quartile definition matters more than I expected. Nine are in common use, the statement's own example matched none of them, and the tests against `stats::quantile()` and `stats::median()` were a cheap way to catch mistakes. Roxygen2 with `devtools::check()` also caught documentation drift early.

Q2: the aCRF annotations are the real specification, and reading them settled the DSTERM, DSDECOD and DSCAT rules. Controlled terminology has gaps ("Randomized"), so those cases need their own mapping. Comparing with the published `ds` dataset exposed a DSSEQ ordering problem I would have missed.

Q3: admiral covers almost every step, so most of the work was picking the right function and arguments. Reading the specification literally showed cases worth documenting (every subject gets `ITTFL = "Y"`, and supine-only readings would change `ABNSBPFL`), and recomputing the flags independently from SDTM was a quick way to trust the derivations.

Q4: `tbl_hierarchical()` handles nested counts with denominators from ADSL, which is where percentages usually go wrong. Rendering the HTML and PNG files and actually looking at them caught label problems the code never showed. Exact binomial intervals are the safer choice for the small counts in the tail of the top 10.

Q5 and Q6: see `question_5_api/README.md` and `question_6_genai/README.md`.
