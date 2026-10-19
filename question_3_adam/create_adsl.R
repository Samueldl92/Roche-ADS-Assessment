# Question 3: ADaM ADSL with {admiral}
#
# Input:  pharmaversesdtm dm, ex, vs, ae, ds
# Output: question_3_adam/adsl.csv, adsl.rds, adsl_checks.txt
# Run from the repository root:  Rscript question_3_adam/create_adsl.R
#
# DM is the basis of ADSL. Derived variables: AGEGR9, AGEGR9N, TRTSDTM, TRTSTMF,
# ITTFL, ABNSBPFL, LSTALVDT, CARPOPFL (TRTEDTM is derived as well because the
# last-alive date uses it).

library(admiral)
library(dplyr)
library(lubridate)
library(stringr)

stopifnot("Run this script from the repository root" = dir.exists("question_3_adam"))

# 1. Input data ----------------------------------------------------------------

dm <- pharmaversesdtm::dm
ex <- pharmaversesdtm::ex
vs <- pharmaversesdtm::vs
ae <- pharmaversesdtm::ae
ds <- pharmaversesdtm::ds

# Blank strings count as missing in the derivations below.
adsl <- dm %>%
  select(-DOMAIN) %>%
  convert_blanks_to_na()
ex <- convert_blanks_to_na(ex)
vs <- convert_blanks_to_na(vs)
ae <- convert_blanks_to_na(ae)
ds <- convert_blanks_to_na(ds)

# 2. Age groups ----------------------------------------------------------------

# AGEGR9: "<18", "18 - 50", ">50"; AGEGR9N: 1, 2, 3.
agegr9_lookup <- exprs(
  ~condition,            ~AGEGR9,   ~AGEGR9N,
  AGE < 18,              "<18",     1,
  between(AGE, 18, 50),  "18 - 50", 2,
  AGE > 50,              ">50",     3
)

adsl <- derive_vars_cat(adsl, definition = agegr9_lookup)

# 3. Treatment start and end date-time -----------------------------------------

# Only exposure records with a valid dose count: EXDOSE > 0, or EXDOSE == 0 on
# a placebo record (see the filter_add arguments below).

# Time imputation (highest_imputation = "h"): a missing time becomes 00:00:00,
# a missing hour or minute is replaced by 00. The date part is never imputed, so
# records with an incomplete date get a missing date-time and are dropped by the
# is.na() filter. ignore_seconds_flag = TRUE keeps the imputation flag empty
# when only the seconds were missing.
ex_ext <- ex %>%
  derive_vars_dtm(
    dtc = EXSTDTC,
    new_vars_prefix = "EXST",
    highest_imputation = "h",
    time_imputation = "first",
    ignore_seconds_flag = TRUE
  ) %>%
  derive_vars_dtm(
    dtc = EXENDTC,
    new_vars_prefix = "EXEN",
    highest_imputation = "h",
    time_imputation = "last",
    ignore_seconds_flag = TRUE
  )

adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = (EXDOSE > 0 | (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO"))) &
      !is.na(EXSTDTM),
    new_vars = exprs(TRTSDTM = EXSTDTM, TRTSTMF = EXSTTMF),
    order = exprs(EXSTDTM, EXSEQ),
    mode = "first",
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = (EXDOSE > 0 | (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO"))) &
      !is.na(EXENDTM),
    new_vars = exprs(TRTEDTM = EXENDTM, TRTETMF = EXENTMF),
    order = exprs(EXENDTM, EXSEQ),
    mode = "last",
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  derive_vars_dtm_to_dt(exprs(TRTSDTM, TRTEDTM))

# 4. Flags ---------------------------------------------------------------------

adsl <- adsl %>%
  # ITTFL: "Y" when ARM is populated, "N" otherwise.
  mutate(ITTFL = if_else(!is.na(ARM), "Y", "N")) %>%
  # ABNSBPFL: any systolic BP reading in mmHg that is >= 140 or < 100.
  derive_var_merged_exist_flag(
    dataset_add = vs,
    by_vars = exprs(STUDYID, USUBJID),
    new_var = ABNSBPFL,
    condition = VSTESTCD == "SYSBP" & VSSTRESU == "mmHg" &
      (VSSTRESN >= 140 | VSSTRESN < 100),
    true_value = "Y",
    false_value = "N",
    missing_value = "N"
  ) %>%
  # CARPOPFL: "Y" for a cardiac adverse event, missing otherwise.
  derive_var_merged_exist_flag(
    dataset_add = ae,
    by_vars = exprs(STUDYID, USUBJID),
    new_var = CARPOPFL,
    condition = str_to_upper(AESOC) == "CARDIAC DISORDERS",
    true_value = "Y",
    false_value = NA_character_,
    missing_value = NA_character_
  )

# 5. Last known alive date -----------------------------------------------------

# Latest of: vital signs date with a valid result, AE onset date, disposition
# start date, and the date part of the last valid exposure (TRTEDTM). Only
# complete dates qualify; convert_dtc_to_dt() returns NA for partial dates.
adsl <- adsl %>%
  derive_vars_extreme_event(
    by_vars = exprs(STUDYID, USUBJID),
    events = list(
      event(
        dataset_name = "vs",
        order = exprs(VSDTC, VSSEQ),
        condition = !is.na(convert_dtc_to_dt(VSDTC)) &
          !(is.na(VSSTRESN) & is.na(VSSTRESC)),
        set_values_to = exprs(
          LSTALVDT = convert_dtc_to_dt(VSDTC),
          seq = VSSEQ
        )
      ),
      event(
        dataset_name = "ae",
        order = exprs(AESTDTC, AESEQ),
        condition = !is.na(convert_dtc_to_dt(AESTDTC)),
        set_values_to = exprs(
          LSTALVDT = convert_dtc_to_dt(AESTDTC),
          seq = AESEQ
        )
      ),
      event(
        dataset_name = "ds",
        order = exprs(DSSTDTC, DSSEQ),
        condition = !is.na(convert_dtc_to_dt(DSSTDTC)),
        set_values_to = exprs(
          LSTALVDT = convert_dtc_to_dt(DSSTDTC),
          seq = DSSEQ
        )
      ),
      event(
        dataset_name = "adsl",
        condition = !is.na(TRTEDT),
        set_values_to = exprs(LSTALVDT = TRTEDT, seq = 0)
      )
    ),
    source_datasets = list(vs = vs, ae = ae, ds = ds, adsl = adsl),
    tmp_event_nr_var = event_nr,
    order = exprs(LSTALVDT, seq, event_nr),
    mode = "last",
    new_vars = exprs(LSTALVDT)
  )

adsl <- adsl %>%
  select(-TRTSDT, -TRTEDT) %>%
  arrange(USUBJID)

# 6. Checks --------------------------------------------------------------------

stopifnot(
  "one record per subject" = !anyDuplicated(adsl$USUBJID) && nrow(adsl) == nrow(dm),
  "AGEGR9N consistent with AGEGR9" = all(
    adsl$AGEGR9N == match(adsl$AGEGR9, c("<18", "18 - 50", ">50"))
  ),
  "ITTFL is Y/N" = all(adsl$ITTFL %in% c("Y", "N")),
  "ABNSBPFL is Y/N" = all(adsl$ABNSBPFL %in% c("Y", "N")),
  "CARPOPFL is Y or missing" = all(adsl$CARPOPFL %in% c("Y", NA)),
  "TRTSTMF is H, M or missing" = all(adsl$TRTSTMF %in% c("H", "M", NA)),
  "TRTSDTM not after TRTEDTM" = all(adsl$TRTSDTM <= adsl$TRTEDTM, na.rm = TRUE),
  "LSTALVDT not before the treatment start date" =
    all(adsl$LSTALVDT >= as_date(adsl$TRTSDTM), na.rm = TRUE)
)

# Independent recomputation of the flags straight from the SDTM data.
cardiac_ids <- unique(ae$USUBJID[str_to_upper(ae$AESOC) == "CARDIAC DISORDERS"])
abn_ids <- vs %>%
  filter(VSTESTCD == "SYSBP", VSSTRESU == "mmHg", VSSTRESN >= 140 | VSSTRESN < 100) %>%
  pull(USUBJID) %>%
  unique()
stopifnot(
  "CARPOPFL matches a direct count" =
    setequal(adsl$USUBJID[which(adsl$CARPOPFL == "Y")], cardiac_ids),
  "ABNSBPFL matches a direct count" =
    setequal(adsl$USUBJID[adsl$ABNSBPFL == "Y"], abn_ids)
)

# 7. Output --------------------------------------------------------------------

write.csv(adsl, "question_3_adam/adsl.csv", row.names = FALSE, na = "")
saveRDS(adsl, "question_3_adam/adsl.rds")

summary_lines <- c(
  paste("ADSL records:", nrow(adsl), "| variables:", ncol(adsl)),
  "",
  "AGEGR9 / AGEGR9N:", capture.output(print(count(adsl, AGEGR9, AGEGR9N))),
  "",
  "ITTFL:", capture.output(print(count(adsl, ITTFL))),
  "",
  "ABNSBPFL:", capture.output(print(count(adsl, ABNSBPFL))),
  "",
  "CARPOPFL:", capture.output(print(count(adsl, CARPOPFL))),
  "",
  "TRTSTMF:", capture.output(print(count(adsl, TRTSTMF))),
  "",
  paste("Subjects without TRTSDTM (never received a valid dose):", sum(is.na(adsl$TRTSDTM))),
  paste("Subjects without LSTALVDT:", sum(is.na(adsl$LSTALVDT))),
  paste("TRTSDTM range:", paste(format(range(adsl$TRTSDTM, na.rm = TRUE)), collapse = " to ")),
  paste("LSTALVDT range:", paste(format(range(adsl$LSTALVDT, na.rm = TRUE)), collapse = " to ")),
  "",
  "Sensitivity: subjects flagged ABNSBPFL = Y",
  paste(
    "  any position (as specified):", sum(adsl$ABNSBPFL == "Y"),
    "| supine readings only:",
    n_distinct(vs$USUBJID[
      vs$VSTESTCD == "SYSBP" & vs$VSSTRESU %in% "mmHg" & vs$VSPOS %in% "SUPINE" &
        (vs$VSSTRESN >= 140 | vs$VSSTRESN < 100) & !is.na(vs$VSSTRESN)
    ])
  ),
  "",
  "Sensitivity: ITTFL = Y includes the 'Screen Failure' arm because ARM is populated",
  capture.output(print(count(adsl, ARM, ITTFL))),
  "",
  "Head of the derived variables:",
  capture.output(print(
    adsl %>% select(USUBJID, AGE, AGEGR9, AGEGR9N, TRTSDTM, TRTSTMF, TRTEDTM,
                    ITTFL, ABNSBPFL, LSTALVDT, CARPOPFL) %>% head(10),
    width = 200
  ))
)
writeLines(summary_lines, "question_3_adam/adsl_checks.txt")
cat(summary_lines, sep = "\n")
