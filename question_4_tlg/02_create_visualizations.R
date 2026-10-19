# Question 4.2: adverse event plots (ggplot2)
#
# Input:  pharmaverseadam::adae, pharmaverseadam::adsl
# Output: question_4_tlg/plot1_ae_severity_by_treatment.png
#         question_4_tlg/plot2_top10_ae_incidence_ci.png
# Run from the repository root:  Rscript question_4_tlg/02_create_visualizations.R

library(dplyr)
library(ggplot2)
library(scales)

stopifnot("Run this script from the repository root" = dir.exists("question_4_tlg"))

# 1. Data ----------------------------------------------------------------------

# Same populations as the summary table: safety population, TEAEs only.
adsl <- pharmaverseadam::adsl %>%
  filter(SAFFL == "Y")

adae <- pharmaverseadam::adae %>%
  filter(TRTEMFL == "Y") %>%
  semi_join(adsl, by = c("STUDYID", "USUBJID"))

severity_levels <- c("MILD", "MODERATE", "SEVERE")
severity_colours <- c(MILD = "#9ecae1", MODERATE = "#3182bd", SEVERE = "#08306b")

theme_ae <- theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold"),
    plot.title.position = "plot",
    panel.grid.minor = element_blank(),
    legend.position = "bottom"
  )

# 2. Plot 1: severity distribution by treatment --------------------------------

# Number of TEAE records per arm and severity. Arms differ in size (72 to 96
# subjects), so compare totals with that in mind.
severity_counts <- adae %>%
  count(ACTARM, AESEV) %>%
  mutate(AESEV = factor(AESEV, levels = severity_levels))

plot1 <- ggplot(severity_counts, aes(x = ACTARM, y = n, fill = AESEV)) +
  geom_col(position = "stack", width = 0.7) +
  geom_text(
    aes(label = n),
    position = position_stack(vjust = 0.5),
    colour = "white", size = 3.5
  ) +
  scale_fill_manual(values = severity_colours, name = "Severity") +
  labs(
    title = "Treatment-emergent adverse events by severity and treatment",
    subtitle = "Number of TEAE records, safety population",
    x = NULL, y = "Number of adverse events"
  ) +
  theme_ae

ggsave(
  "question_4_tlg/plot1_ae_severity_by_treatment.png",
  plot1, width = 8, height = 5.5, dpi = 150, bg = "white"
)

# 3. Plot 2: top 10 adverse events with 95% CI ---------------------------------

# Incidence = subjects with the event / all subjects in the safety population.
# The 95% CI is the exact (Clopper-Pearson) interval from binom.test(), which
# stays valid for small counts.
n_total <- n_distinct(adsl$USUBJID)

top10 <- adae %>%
  distinct(USUBJID, AETERM) %>%
  count(AETERM, name = "n_subjects") %>%
  # Ties at the cut-off are resolved alphabetically so the output is stable.
  arrange(desc(n_subjects), AETERM) %>%
  slice_head(n = 10) %>%
  rowwise() %>%
  mutate(
    ci = list(stats::binom.test(n_subjects, n_total)$conf.int),
    incidence = n_subjects / n_total,
    lower = ci[[1]],
    upper = ci[[2]]
  ) %>%
  ungroup() %>%
  select(-ci) %>%
  mutate(AETERM = reorder(stringr::str_to_sentence(AETERM), incidence))

plot2 <- ggplot(top10, aes(x = incidence, y = AETERM)) +
  geom_errorbar(aes(xmin = lower, xmax = upper), width = 0.25, orientation = "y",
                colour = "grey35") +
  geom_point(size = 3, colour = "#3182bd") +
  geom_text(
    aes(x = upper, label = sprintf("%.1f%%", 100 * incidence)),
    hjust = -0.25, size = 3.3
  ) +
  scale_x_continuous(
    labels = percent_format(accuracy = 1),
    limits = c(0, NA),
    expand = expansion(mult = c(0.02, 0.12))
  ) +
  labs(
    title = "Top 10 most frequent treatment-emergent adverse events",
    subtitle = paste0(
      "Incidence with exact 95% confidence interval, safety population (N = ",
      n_total, ")"
    ),
    x = "Percentage of subjects with the event", y = NULL
  ) +
  theme_ae

ggsave(
  "question_4_tlg/plot2_top10_ae_incidence_ci.png",
  plot2, width = 8, height = 5.5, dpi = 150, bg = "white"
)

message("Wrote two PNG files in question_4_tlg/")
print(as.data.frame(top10), digits = 3)
