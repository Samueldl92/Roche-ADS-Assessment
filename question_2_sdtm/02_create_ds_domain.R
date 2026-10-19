# Question 2: SDTM DS (Disposition) domain with {sdtm.oak}
#
# Input:  pharmaverseraw::ds_raw, pharmaversesdtm::dm (reference dates)
# Output: question_2_sdtm/ds.csv (and ds.rds)
# Run from the repository root:  Rscript question_2_sdtm/02_create_ds_domain.R
#
# Mapping rules come from the Subject Disposition aCRF of {pharmaverseraw}:
#   IT.DSSTDAT          -> DSSTDTC (ISO 8601)
#   IT.DSDECOD          -> DSDECOD via controlled terminology, when OTHERSP is null
#   OTHERSP             -> DSDECOD and DSTERM, when OTHERSP is not null
#   IT.DSTERM           -> DSTERM, when OTHERSP is null
#   DSDTCOL + DSTMCOL   -> DSDTC (ISO 8601)
#   DSCAT: "PROTOCOL MILESTONE" if IT.DSDECOD is Randomized, "OTHER EVENT" if
#          OTHERSP is not null, "DISPOSITION EVENT" otherwise.

library(sdtm.oak)
library(dplyr)

stopifnot("Run this script from the repository root" = dir.exists("question_2_sdtm"))

# 1. Input data ----------------------------------------------------------------

ds_raw <- pharmaverseraw::ds_raw
dm <- pharmaversesdtm::dm

# oak_id_vars (oak_id, raw_src, patient_number) let sdtm.oak merge the pieces
# derived from the same raw record.
ds_raw <- generate_oak_id_vars(ds_raw, pat_var = "PATNUM", raw_src = "ds_raw")

# Study controlled terminology, as given in the assessment.
study_ct <- data.frame(
  stringsAsFactors = FALSE,
  codelist_code = rep("C66727", 10),
  term_code = c(
    "C41331", "C25250", "C28554", "C48226", "C48227",
    "C48250", "C142185", "C49628", "C49632", "C49634"
  ),
  term_value = c(
    "ADVERSE EVENT", "COMPLETED", "DEATH", "LACK OF EFFICACY",
    "LOST TO FOLLOW-UP", "PHYSICIAN DECISION", "PROTOCOL VIOLATION",
    "SCREEN FAILURE", "STUDY TERMINATED BY SPONSOR", "WITHDRAWAL BY SUBJECT"
  ),
  collected_value = c(
    "Adverse Event", "Complete", "Dead", "Lack of Efficacy",
    "Lost To Follow-Up", "Physician Decision", "Protocol Violation",
    "Trial Screen Failure", "Study Terminated By Sponsor", "Withdrawal by Subject"
  ),
  term_preferred_term = c(
    "AE", "Completed", "Died", NA, NA, NA, "Violation",
    "Failure to Meet Inclusion/Exclusion Criteria", NA, "Dropout"
  ),
  term_synonyms = c(
    "ADVERSE EVENT", "COMPLETE", "Death", NA, NA, NA, NA, NA, NA,
    "Discontinued Participation"
  )
)

# 2. Subsets of the raw data used by the conditional mappings -------------------

# "Randomized" is not in the study CT, so it is mapped without CT. Everything
# else in IT.DSDECOD goes through the C66727 codelist.
is_other <- !is.na(ds_raw$OTHERSP)
is_randomized <- !is_other & ds_raw$IT.DSDECOD %in% "Randomized"
is_disposition <- !is_other & !is_randomized

# 3. Topic variable and qualifiers ---------------------------------------------

ds <-
  # DSTERM: reported term, or the OTHERSP text when it is populated.
  assign_no_ct(
    raw_dat = condition_add(ds_raw, !is_other),
    raw_var = "IT.DSTERM",
    tgt_var = "DSTERM",
    id_vars = oak_id_vars()
  ) %>%
  assign_no_ct(
    raw_dat = condition_add(ds_raw, is_other),
    raw_var = "OTHERSP",
    tgt_var = "DSTERM",
    id_vars = oak_id_vars()
  ) %>%
  # DSDECOD: standardized term through the study CT for real dispositions...
  assign_ct(
    raw_dat = condition_add(ds_raw, is_disposition),
    raw_var = "IT.DSDECOD",
    tgt_var = "DSDECOD",
    ct_spec = study_ct,
    ct_clst = "C66727",
    id_vars = oak_id_vars()
  ) %>%
  # ...and the collected text for Randomized and for OTHERSP events.
  assign_no_ct(
    raw_dat = condition_add(ds_raw, is_randomized),
    raw_var = "IT.DSDECOD",
    tgt_var = "DSDECOD",
    id_vars = oak_id_vars()
  ) %>%
  assign_no_ct(
    raw_dat = condition_add(ds_raw, is_other),
    raw_var = "OTHERSP",
    tgt_var = "DSDECOD",
    id_vars = oak_id_vars()
  ) %>%
  # DSCAT is constant within each subset.
  hardcode_no_ct(
    raw_dat = condition_add(ds_raw, is_randomized),
    raw_var = "IT.DSDECOD",
    tgt_var = "DSCAT",
    tgt_val = "PROTOCOL MILESTONE",
    id_vars = oak_id_vars()
  ) %>%
  hardcode_no_ct(
    raw_dat = condition_add(ds_raw, is_other),
    raw_var = "OTHERSP",
    tgt_var = "DSCAT",
    tgt_val = "OTHER EVENT",
    id_vars = oak_id_vars()
  ) %>%
  hardcode_no_ct(
    raw_dat = condition_add(ds_raw, is_disposition),
    raw_var = "IT.DSDECOD",
    tgt_var = "DSCAT",
    tgt_val = "DISPOSITION EVENT",
    id_vars = oak_id_vars()
  ) %>%
  # Dates are collected as MM-DD-YYYY. DSDTC combines date and (optional) time.
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = c("DSDTCOL", "DSTMCOL"),
    tgt_var = "DSDTC",
    raw_fmt = c("m-d-y", "H:M"),
    id_vars = oak_id_vars()
  ) %>%
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = "IT.DSSTDAT",
    tgt_var = "DSSTDTC",
    raw_fmt = "m-d-y",
    id_vars = oak_id_vars()
  )

# 4. Visit variables -----------------------------------------------------------

# The raw INSTANCE label is mapped to VISIT (upper case) and VISITNUM. The
# scheduled visits follow the study visit schedule; unscheduled visits carry
# their number in the label ("Unscheduled 4.1" -> VISITNUM 4.1).
visit_schedule <- data.frame(
  INSTANCE = c(
    "Screening 1", "Baseline", "Week 2", "Week 4", "Ambul Ecg Removal",
    "Week 6", "Week 8", "Week 12", "Week 16", "Week 20", "Week 24",
    "Week 26", "Retrieval"
  ),
  scheduled_visitnum = c(1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 201)
)

visits <- ds_raw %>%
  select(oak_id, raw_source, patient_number, INSTANCE) %>%
  left_join(visit_schedule, by = "INSTANCE") %>%
  mutate(
    unscheduled_visitnum = if_else(
      startsWith(INSTANCE, "Unscheduled"),
      suppressWarnings(as.numeric(sub("^Unscheduled\\s+", "", INSTANCE))),
      NA_real_
    ),
    VISITNUM = coalesce(scheduled_visitnum, unscheduled_visitnum),
    VISIT = toupper(INSTANCE)
  ) %>%
  select(oak_id, raw_source, patient_number, VISITNUM, VISIT)

# 5. Identifiers, sequence and study day ---------------------------------------

ds <- ds %>%
  left_join(visits, by = c("oak_id", "raw_source", "patient_number")) %>%
  mutate(
    STUDYID = ds_raw$STUDY[match(oak_id, ds_raw$oak_id)],
    DOMAIN = "DS",
    # PATNUM is "701-1015"; USUBJID in DM is "01-701-1015".
    USUBJID = paste0("01-", ds_raw$PATNUM[match(oak_id, ds_raw$oak_id)]),
    DSTERM = toupper(DSTERM),
    DSDECOD = toupper(DSDECOD)
  ) %>%
  # Sequence: chronological per subject, ties kept in the order they were
  # collected (oak_id follows the raw row order).
  derive_seq(
    tgt_var = "DSSEQ",
    rec_vars = c("USUBJID", "DSSTDTC", "oak_id")
  ) %>%
  derive_study_day(
    sdtm_in = .,
    dm_domain = dm,
    tgdt = "DSSTDTC",
    refdt = "RFXSTDTC",
    study_day_var = "DSSTDY"
  ) %>%
  # Keep the ISO 8601 dates as plain character so that partial dates and times
  # survive the CSV export unchanged.
  mutate(
    DSDTC = as.character(unclass(DSDTC)),
    DSSTDTC = format(DSSTDTC)
  ) %>%
  select(
    STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD, DSCAT,
    VISITNUM, VISIT, DSDTC, DSSTDTC, DSSTDY
  ) %>%
  arrange(USUBJID, DSSEQ)

# 6. Checks --------------------------------------------------------------------

stopifnot(
  "one DS record per raw record" = nrow(ds) == nrow(ds_raw),
  "USUBJID must exist in DM" = all(ds$USUBJID %in% dm$USUBJID),
  "DSSEQ unique within subject" = !anyDuplicated(ds[c("USUBJID", "DSSEQ")]),
  "DSTERM, DSDECOD, DSCAT, DSSTDTC fully populated" =
    !anyNA(ds[c("DSTERM", "DSDECOD", "DSCAT", "DSSTDTC")]),
  "VISIT and VISITNUM fully populated" = !anyNA(ds[c("VISITNUM", "VISIT")]),
  "DSCAT values" = all(ds$DSCAT %in% c("PROTOCOL MILESTONE", "DISPOSITION EVENT", "OTHER EVENT"))
)

# 7. Output --------------------------------------------------------------------

write.csv(ds, "question_2_sdtm/ds.csv", row.names = FALSE, na = "")
saveRDS(ds, "question_2_sdtm/ds.rds")

message("DS domain: ", nrow(ds), " records, ", n_distinct(ds$USUBJID), " subjects")
print(count(ds, DSCAT, DSDECOD))
print(head(ds, 10))

# Compare with the reference DS shipped in {pharmaversesdtm}, as a sanity check.
reference <- pharmaversesdtm::ds
compare_cols <- c("DSTERM", "DSDECOD", "DSCAT", "VISITNUM", "VISIT", "DSDTC", "DSSTDTC", "DSSTDY")
joined <- inner_join(
  ds, reference[c("USUBJID", "DSSEQ", compare_cols)],
  by = c("USUBJID", "DSSEQ"), suffix = c("", ".ref")
)
agreement <- vapply(
  compare_cols,
  function(v) mean(joined[[v]] == joined[[paste0(v, ".ref")]], na.rm = TRUE),
  numeric(1)
)
message("Agreement with pharmaversesdtm::ds on matched records:")
print(round(agreement, 4))
