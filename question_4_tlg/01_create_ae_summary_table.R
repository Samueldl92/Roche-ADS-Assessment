# Question 4.1: summary table of treatment-emergent adverse events (gtsummary)
#
# Input:  pharmaverseadam::adae, pharmaverseadam::adsl
# Output: question_4_tlg/ae_summary_table.html
# Run from the repository root:  Rscript question_4_tlg/01_create_ae_summary_table.R
#
# Layout (FDA Table 10 style): one row per system organ class (AESOC) with the
# reported terms (AETERM) nested below it, one column per actual treatment arm
# (ACTARM) plus a Total column, cells are n (%) of subjects. The first row,
# "Any TEAE", counts every subject with at least one event. Rows are sorted by
# descending frequency in the Total column.

library(dplyr)
library(gtsummary)

stopifnot("Run this script from the repository root" = dir.exists("question_4_tlg"))

# 1. Data ----------------------------------------------------------------------

# Denominators come from ADSL, not from ADAE, so subjects without any event
# still count. The safety population (SAFFL = "Y") excludes screen failures,
# who never received treatment and therefore have no ACTARM that fits a TEAE
# table.
adsl <- pharmaverseadam::adsl %>%
  filter(SAFFL == "Y")

adae <- pharmaverseadam::adae %>%
  filter(TRTEMFL == "Y") %>%
  semi_join(adsl, by = c("STUDYID", "USUBJID"))

# A Total column is built by stacking a copy of the data labelled "Total".
arm_levels <- c(sort(unique(adsl$ACTARM)), "Total")
with_total <- function(df) {
  df %>%
    bind_rows(mutate(df, ACTARM = "Total")) %>%
    mutate(ACTARM = factor(ACTARM, levels = arm_levels))
}
adsl_tot <- with_total(adsl)
adae_tot <- with_total(adae)

# 2. Table ---------------------------------------------------------------------

tbl <- adae_tot %>%
  tbl_hierarchical(
    variables = c(AESOC, AETERM),
    by = ACTARM,
    id = USUBJID,
    denominator = adsl_tot,
    overall_row = TRUE,
    label = list(..ard_hierarchical_overall.. = "Any TEAE")
  ) %>%
  sort_hierarchical(sort = everything() ~ "descending") %>%
  modify_header(
    label ~ "**System organ class**  \n  Reported term",
    all_stat_cols() ~ "**{level}**  \nN = {n}"
  ) %>%
  modify_spanning_header(all_stat_cols() ~ "**Actual treatment arm**") %>%
  modify_caption("**Treatment-emergent adverse events by system organ class and reported term**") %>%
  modify_footnote_header(
    "n (%) of subjects with at least one event; percentages use the safety population of each arm as denominator",
    columns = all_stat_cols()
  )

# 3. Output --------------------------------------------------------------------

tbl %>%
  as_gt() %>%
  gt::tab_source_note("Safety population (SAFFL = Y). Treatment-emergent events only (TRTEMFL = Y). Sorted by descending frequency in the Total column.") %>%
  gt::gtsave("question_4_tlg/ae_summary_table.html")

message("Wrote question_4_tlg/ae_summary_table.html")
message("Safety population: ", nrow(adsl), " subjects; TEAE records: ", nrow(adae),
        " in ", n_distinct(adae$USUBJID), " subjects")
