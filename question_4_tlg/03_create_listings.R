# Question 4.3: listing of treatment-emergent adverse events (gtsummary)
#
# Input:  pharmaverseadam::adae
# Output: question_4_tlg/ae_listings.html
# Run from the repository root:  Rscript question_4_tlg/03_create_listings.R
#
# One row per TEAE record (TRTEMFL = "Y"), sorted by subject and event start
# date. {gtsummary} has no listing function of its own, so the listing data
# frame is wrapped with as_gtsummary() and styled with the usual gtsummary
# verbs before conversion to gt.

library(dplyr)
library(gtsummary)

stopifnot("Run this script from the repository root" = dir.exists("question_4_tlg"))

# 1. Data ----------------------------------------------------------------------

listing <- pharmaverseadam::adae %>%
  filter(TRTEMFL == "Y") %>%
  # Start date, then record number, keeps events of one subject in order even
  # when several start on the same day.
  arrange(USUBJID, ASTDT, AESEQ) %>%
  transmute(
    USUBJID,
    ACTARM,
    AETERM,
    AESEV,
    AEREL,
    # Dates are shown as ISO 8601 text. A missing end date means the event had
    # no recorded end (ongoing or unknown).
    ASTDT = format(ASTDT),
    AENDT = if_else(is.na(AENDT), "", format(AENDT))
  )

# 2. Table ---------------------------------------------------------------------

tbl <- listing %>%
  as_gtsummary() %>%
  modify_header(
    USUBJID ~ "**Subject ID**",
    ACTARM ~ "**Treatment**",
    AETERM ~ "**Adverse event term**",
    AESEV ~ "**Severity**",
    AEREL ~ "**Relationship to drug**",
    ASTDT ~ "**Start date**",
    AENDT ~ "**End date**"
  ) %>%
  modify_caption("**Listing of treatment-emergent adverse events**")

# 3. Output --------------------------------------------------------------------

tbl %>%
  as_gt() %>%
  gt::tab_source_note(
    "Treatment-emergent events only (TRTEMFL = Y), sorted by subject and start date. A blank end date means no end date was recorded."
  ) %>%
  gt::opt_row_striping() %>%
  gt::gtsave("question_4_tlg/ae_listings.html")

message("Wrote question_4_tlg/ae_listings.html: ", nrow(listing), " events, ",
        n_distinct(listing$USUBJID), " subjects")
