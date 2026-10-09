# =============================================================================
# Adjusted models: NDHS 2018 vs 2024, Nigeria, women 15-49
#
# Question 1: Did modern contraceptive use rise, and did the wealth gap widen,
#             AFTER adjusting for age, residence, education and zone?
# Question 2: Did 12-month method retention improve after adjusting for who the
#             users are, and how much of the improvement is the method mix?
#
# Run from the project root, AFTER analysis.R (needs outputs/episodes.rds).
# Outputs: outputs/models/*.csv|txt and outputs/charts/or_forest_modern_use.png
# =============================================================================
library(haven)
library(dplyr)
library(tidyr)
library(stringr)
library(tibble)
library(survey)
library(survival)
library(ggplot2)

options(survey.lonely.psu = "adjust")
set.seed(2026)

path18 <- "data/raw/ir2018.DTA"
path24 <- "data/raw/ir2024.DTA"
dir.create("outputs/models", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/charts", recursive = TRUE, showWarnings = FALSE)

# Helper: coefficient table with Wald 95% CIs and p-values.
# exponentiate = TRUE gives odds ratios (logistic) or hazard ratios (Cox).
coef_tab <- function(m, exponentiate = TRUE) {
  est <- coef(m)
  se  <- sqrt(diag(vcov(m)))
  tibble(term = names(est), estimate = est, se = se) %>%
    mutate(lo = estimate - 1.96 * se,
           hi = estimate + 1.96 * se,
           p  = 2 * pnorm(-abs(estimate / se))) %>%
    mutate(across(c(estimate, lo, hi), ~ if (exponentiate) exp(.x) else .x)) %>%
    select(-se)
}


# =============================================================================
# PART 1. Modern contraceptive use (all women 15-49, both surveys pooled)
# =============================================================================
get_model_data <- function(path, yr) {
  read_dta(path, col_select = c("caseid", "v005", "v021", "v022", "v024", "v025",
                                "v106", "v013", "v190", "v313")) %>%
    mutate(year      = yr,
           wt        = v005 / 1e6,
           modern    = as.numeric(v313 == 3),
           region    = as_factor(v024),
           residence = as_factor(v025),
           educ      = as_factor(v106),
           age       = as_factor(v013),
           wealth    = as_factor(v190),
           psu       = paste(yr, v021),       # prefix with year so PSUs and strata
           strata    = paste(yr, v022)) %>%   # stay distinct across the two surveys
    select(caseid, year, wt, modern, region, residence, educ, age, wealth, psu, strata)
}

dat <- bind_rows(get_model_data(path18, 2018), get_model_data(path24, 2024)) %>%
  mutate(year      = factor(year),
         region    = relevel(factor(region), ref = "north west"),
         residence = relevel(factor(residence), ref = "rural"),
         wealth    = factor(wealth, levels = c("poorest", "poorer", "middle", "richer", "richest")),
         educ      = factor(educ, levels = c("no education", "primary", "secondary", "higher")))

# Reference groups: year 2018, age 15-19, rural, poorest, no education, North West.
des <- svydesign(ids = ~psu, strata = ~strata, weights = ~wt, data = dat, nest = TRUE)

# ---- Model A: logistic, main effects -> adjusted odds ratios ---------------
m1 <- svyglm(modern ~ year + age + residence + wealth + educ + region,
             design = des, family = quasibinomial())

or_a <- coef_tab(m1) %>% filter(term != "(Intercept)")
print(or_a, n = Inf)
write.csv(or_a, "outputs/models/logit_main_effects_OR.csv", row.names = FALSE)

# Forest plot of adjusted odds ratios
grp_re <- "^(year|age|residence|wealth|educ|region)"
or_plot <- or_a %>%
  mutate(group = str_extract(term, grp_re),
         level = str_remove(term, grp_re),
         level = if_else(group == "region", str_to_title(level), str_to_sentence(level)),
         group = recode(group,
                        year = "Survey year (ref 2018)",
                        age = "Age (ref 15-19)",
                        residence = "Residence (ref rural)",
                        wealth = "Wealth (ref poorest)",
                        educ = "Education (ref none)",
                        region = "Zone (ref North West)"),
         group = factor(group, levels = unique(group)),
         level = factor(level, levels = rev(unique(level))),
         sig   = if_else(lo > 1 | hi < 1, "Significant", "Not significant"))

p_or <- ggplot(or_plot, aes(estimate, level, colour = sig)) +
  geom_vline(xintercept = 1, linetype = "dashed", colour = "grey50") +
  geom_errorbarh(aes(xmin = lo, xmax = hi), height = 0.25) +
  geom_point(size = 2.2) +
  scale_x_log10() +
  scale_colour_manual(values = c("Significant" = "#0F6CBD", "Not significant" = "#9AA3AF")) +
  facet_grid(group ~ ., scales = "free_y", space = "free_y") +
  labs(title = "Adjusted odds of modern contraceptive use",
       subtitle = "Survey-weighted logistic regression, NDHS 2018 and 2024 pooled. Dashed line = no difference.",
       x = "Adjusted odds ratio (log scale), 95% CI", y = NULL, colour = NULL,
       caption = "Source: NDHS 2018 & 2024, women 15-49.") +
  theme_minimal(base_size = 11) +
  theme(strip.text.y = element_text(angle = 0, hjust = 0, face = "bold"),
        legend.position = "top")
ggsave("outputs/charts/or_forest_modern_use.png", p_or, width = 9, height = 10, dpi = 300)

# ---- Model B: does the wealth gradient change between surveys? -------------
# Global test of the year x wealth interaction (logistic scale).
m2 <- svyglm(modern ~ year * wealth + age + residence + educ + region,
             design = des, family = quasibinomial())
int_test <- regTermTest(m2, ~ year:wealth)
print(int_test)
capture.output(int_test, file = "outputs/models/interaction_test_year_wealth.txt")

# ---- Model C: linear probability model, results in percentage points -------
# Same structure as Model B, but coefficients are differences in probability.
#   year2024                 = adjusted change in use for the POOREST (reference)
#   year2024:wealthrichest   = extra change for the richest vs the poorest
#                              = adjusted CHANGE IN THE RICHEST-POOREST GAP
m3 <- svyglm(modern ~ year * wealth + age + residence + educ + region, design = des)

lpm <- coef_tab(m3, exponentiate = FALSE) %>%
  mutate(across(c(estimate, lo, hi), ~ .x * 100)) %>%      # convert to pct points
  rename(estimate_pts = estimate, lo_pts = lo, hi_pts = hi)

gap_rows <- lpm %>% filter(str_detect(term, "^year2024"))
print(gap_rows, n = Inf)
write.csv(lpm,      "outputs/models/lpm_year_wealth_pts.csv",      row.names = FALSE)
write.csv(gap_rows, "outputs/models/lpm_year_wealth_gap_rows.csv", row.names = FALSE)


# =============================================================================
# PART 2. 12-month retention (episode-level Cox model)
# =============================================================================
# Uses the episode dataset built in analysis.R (sterilization, EC, LAM excluded;
# switching = censored). Follow-up is capped at 12 months so results line up with
# the 12-month discontinuation rates.
ep2 <- readRDS("outputs/episodes.rds")

strata_lookup <- bind_rows(
  read_dta(path18, col_select = c("caseid", "v022")) %>% mutate(year = 2018),
  read_dta(path24, col_select = c("caseid", "v022")) %>% mutate(year = 2024)
) %>% mutate(v022 = as.numeric(v022))

epm <- ep2 %>%
  left_join(strata_lookup, by = c("year", "caseid")) %>%
  mutate(time   = pmin(dur, 12),
         status = as.integer(event & dur <= 12),
         yearf  = factor(year),
         psu    = paste(year, psu),
         strata = paste(year, v022),
         method = case_when(code == "1" ~ "Pill",
                            code == "3" ~ "Injectables",
                            code == "5" ~ "Male condom",
                            code == "N" ~ "Implants",
                            code == "2" ~ "IUD",
                            code %in% c("8", "9", "W") ~ "Traditional",
                            TRUE ~ "Other modern"),
         method = relevel(factor(method), ref = "Pill"),
         region = relevel(factor(region), ref = "north west"),
         wealth = factor(wealth, levels = c("poorest", "poorer", "middle", "richer", "richest")),
         educ   = factor(educ, levels = c("no education", "primary", "secondary", "higher")))

stopifnot(!anyNA(epm$strata))     # the strata join must have matched every episode

des_ep <- svydesign(ids = ~psu, strata = ~strata, weights = ~wt, data = epm, nest = TRUE)

# Model D1: year effect adjusted for WHO the users are (wealth, education, zone)
cox1 <- svycoxph(Surv(time, status) ~ yearf + wealth + educ + region, design = des_ep)
# Model D2: ... and also for WHICH METHOD they use
cox2 <- svycoxph(Surv(time, status) ~ yearf + method + wealth + educ + region, design = des_ep)

hr1 <- coef_tab(cox1)
hr2 <- coef_tab(cox2)
print(hr2, n = Inf)
write.csv(hr1, "outputs/models/cox_without_method_HR.csv", row.names = FALSE)
write.csv(hr2, "outputs/models/cox_with_method_HR.csv",    row.names = FALSE)

# The key comparison: how much does the 2024 effect change once method is added?
cat("\n2024 vs 2018 hazard ratio for stopping within 12 months:\n")
print(bind_rows(hr1 %>% filter(term == "yearf2024") %>% mutate(model = "Without method"),
                hr2 %>% filter(term == "yearf2024") %>% mutate(model = "With method")))

# Optional check of the proportional-hazards assumption (unweighted approximation).
# Look for small p-values on a covariate: the effect may change over time.
# ph <- coxph(Surv(time, status) ~ yearf + method + wealth + educ + region, data = epm)
# print(cox.zph(ph))

# ---- Notes for the write-up -------------------------------------------------
# - Associations, not causal effects.
# - Logistic ORs are not percentage points. Use the linear probability model
#   (Model C) when you want to talk in percentage points.
# - Hazard ratio < 1 = lower hazard of stopping within 12 months = better retention.
# - Cox models treat each episode as an observation. Women can contribute several,
#   so SEs rely on the PSU-clustered design to account for that.
