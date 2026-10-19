# Exports the adverse event dataset used by the Python questions (Q5 and Q6)
# to data/adae.csv.
#
# Source: pharmaversesdtm::ae (SDTM AE domain, all original columns kept).
# The SDTM AE domain does not carry the actual treatment arm, but Q5 filters on
# ACTARM, so ACTARM is added by joining pharmaversesdtm::dm on USUBJID (one row
# per subject, so the join cannot duplicate AE records).
#
# Run from the repository root:  Rscript data/export_adae.R

suppressPackageStartupMessages({
  library(dplyr)
  library(pharmaversesdtm)
})

actarm <- pharmaversesdtm::dm |>
  select(STUDYID, USUBJID, ACTARM)

adae <- pharmaversesdtm::ae |>
  left_join(actarm, by = c("STUDYID", "USUBJID"))

stopifnot(
  nrow(adae) == nrow(pharmaversesdtm::ae),
  !anyNA(adae$ACTARM)
)

dir.create("data", showWarnings = FALSE)
write.csv(adae, "data/adae.csv", row.names = FALSE, na = "")
message("Wrote data/adae.csv: ", nrow(adae), " rows x ", ncol(adae), " columns")
