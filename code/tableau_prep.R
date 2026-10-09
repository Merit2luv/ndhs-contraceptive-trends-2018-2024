# =============================================================================
# Export tidy summary tables for Tableau
# Run AFTER analysis.R. It reads the CSVs that analysis.R saved to outputs/,
# so it works even after you restart R.
# Only aggregated estimates are exported. No DHS microdata leave your computer.
# Output folder: outputs/tableau/
# =============================================================================
library(dplyr)
library(tidyr)
library(stringr)
library(readr)
library(tibble)

dir.create("outputs/tableau", recursive = TRUE, showWarnings = FALSE)
rd <- function(f, ...) read_csv(file.path("outputs", f), show_col_types = FALSE, ...)


# ---- 1. Estimates, long format (one row per indicator x group x year) -------
use_overall <- rd("mcpr_overall.csv") %>%
  transmute(indicator = "Modern contraceptive use", dimension = "Overall",
            group = "All women 15-49", year = as.integer(year),
            estimate = mcpr, lo, hi, n = NA_real_)

use_group <- function(f, dim) {
  rd(f) %>%
    select(group, p_2018, p_2024, se_2018, se_2024) %>%
    pivot_longer(-group, names_to = c(".value", "year"), names_sep = "_") %>%
    transmute(indicator = "Modern contraceptive use", dimension = dim,
              group = as.character(group), year = as.integer(year),
              estimate = p, lo = p - 1.96 * se, hi = p + 1.96 * se, n = NA_real_)
}

disc_overall <- rd("disc_overall.csv") %>%
  transmute(indicator = "12-month discontinuation", dimension = "Overall",
            group = "All women 15-49", year = as.integer(year),
            estimate = disc12, lo, hi, n = as.numeric(n))

disc_group <- function(f, col, dim) {
  rd(f) %>%
    transmute(indicator = "12-month discontinuation", dimension = dim,
              group = as.character(.data[[col]]), year = as.integer(year),
              estimate = disc12, lo, hi, n = as.numeric(n))
}

est_raw <- bind_rows(
  use_overall,
  use_group("mcpr_change_wealth.csv", "Wealth"),
  use_group("mcpr_change_educ.csv",   "Education"),
  use_group("mcpr_change_region.csv", "Zone"),
  disc_overall,
  disc_group("disc_wealth.csv", "wealth", "Wealth"),
  disc_group("disc_educ.csv",   "educ",   "Education"),
  disc_group("disc_region.csv",  "region", "Zone")
)


# ---- 2. Change 2018 -> 2024, with significance flags ------------------------
# Modern use: subgroup changes were tested in analysis.R (independent surveys).
use_chg_group <- function(f, dim) {
  rd(f) %>%
    transmute(indicator = "Modern contraceptive use", dimension = dim,
              group = as.character(group),
              change, change_lo = lo, change_hi = hi,
              significant = if_else(sig, "Yes", "No"))
}

# National modern-use change, from the two overall CIs
o      <- rd("mcpr_overall.csv") %>% mutate(se = (hi - lo) / (2 * 1.96))
d_use  <- o$mcpr[o$year == 2024] - o$mcpr[o$year == 2018]
se_use <- sqrt(sum(o$se^2))
use_chg_overall <- tibble(
  indicator = "Modern contraceptive use", dimension = "Overall",
  group = "All women 15-49", change = d_use,
  change_lo = d_use - 1.96 * se_use, change_hi = d_use + 1.96 * se_use,
  significant = if_else(d_use - 1.96 * se_use > 0 | d_use + 1.96 * se_use < 0, "Yes", "No"))

# Discontinuation: only 5 changes were bootstrap-tested (overall, richest,
# poorest, North East, North West). Every other group is flagged "Not tested".
tests <- rd("disc_change_tests.csv") %>%
  mutate(key = tolower(group)) %>%
  select(key, t_lo = lo, t_hi = hi)

disc_chg <- est_raw %>%
  filter(indicator == "12-month discontinuation") %>%
  select(dimension, group, year, estimate) %>%
  pivot_wider(names_from = year, values_from = estimate, names_prefix = "y") %>%
  mutate(change = y2024 - y2018,
         key = if_else(dimension == "Overall", "overall", group)) %>%
  left_join(tests, by = "key") %>%
  transmute(indicator = "12-month discontinuation", dimension, group, change,
            change_lo = t_lo, change_hi = t_hi,
            significant = case_when(is.na(t_lo) ~ "Not tested",
                                    t_lo > 0 | t_hi < 0 ~ "Yes",
                                    TRUE ~ "No"))

chg_raw <- bind_rows(
  use_chg_overall,
  use_chg_group("mcpr_change_wealth.csv", "Wealth"),
  use_chg_group("mcpr_change_educ.csv",   "Education"),
  use_chg_group("mcpr_change_region.csv", "Zone"),
  disc_chg
)


# ---- 3. Merge, label, order, convert change to percentage points ------------
order_map <- tribble(
  ~dimension,  ~group,            ~group_order,
  "Overall",   "All women 15-49", 1,
  "Wealth",    "poorest",         1,
  "Wealth",    "poorer",          2,
  "Wealth",    "middle",          3,
  "Wealth",    "richer",          4,
  "Wealth",    "richest",         5,
  "Education", "no education",    1,
  "Education", "primary",         2,
  "Education", "secondary",       3,
  "Education", "higher",          4,
  "Zone",      "north west",      1,
  "Zone",      "north east",      2,
  "Zone",      "north central",   3,
  "Zone",      "south west",      4,
  "Zone",      "south east",      5,
  "Zone",      "south south",     6
)

est <- est_raw %>%
  left_join(chg_raw,   by = c("indicator", "dimension", "group")) %>%
  left_join(order_map, by = c("dimension", "group"))

if (anyNA(est$group_order)) {
  stop("Some group labels did not match the order map. Check: ",
       paste(unique(est$group[is.na(est$group_order)]), collapse = ", "))
}

est <- est %>%
  mutate(group = case_when(dimension == "Zone" ~ str_to_title(group),
                           dimension %in% c("Wealth", "Education") ~ str_to_sentence(group),
                           TRUE ~ group),
         across(c(estimate, lo, hi), ~ round(.x, 4)),
         change_pts    = round(change    * 100, 2),
         change_lo_pts = round(change_lo * 100, 2),
         change_hi_pts = round(change_hi * 100, 2)) %>%
  select(-change, -change_lo, -change_hi) %>%
  arrange(indicator, dimension, group_order, year)

write_csv(est, "outputs/tableau/tableau_estimates.csv")


# ---- 4. Method-level discontinuation ---------------------------------------
method_lab <- c("1" = "Pill", "2" = "IUD", "3" = "Injectables", "4" = "Diaphragm",
                "5" = "Male condom", "8" = "Periodic abstinence", "9" = "Withdrawal",
                "C" = "Female condom", "M" = "Other modern", "N" = "Implants",
                "S" = "Standard Days", "W" = "Other traditional")

methods <- rd("disc_method.csv", col_types = cols(code = col_character())) %>%
  transmute(method   = coalesce(unname(method_lab[code]), code),
            type     = if_else(code %in% c("8", "9", "W"), "Traditional", "Modern"),
            year     = as.integer(year),
            estimate = round(disc12, 4), lo = round(lo, 4), hi = round(hi, 4),
            n        = as.numeric(n))

write_csv(methods, "outputs/tableau/tableau_methods.csv")


# ---- 5. State -> zone lookup, for the Tableau map ---------------------------
zone_map <- tribble(
  ~state,                       ~zone,
  "Benue",                      "North Central",
  "Kogi",                       "North Central",
  "Kwara",                      "North Central",
  "Nasarawa",                   "North Central",
  "Niger",                      "North Central",
  "Plateau",                    "North Central",
  "Federal Capital Territory",  "North Central",
  "Adamawa",                    "North East",
  "Bauchi",                     "North East",
  "Borno",                      "North East",
  "Gombe",                      "North East",
  "Taraba",                     "North East",
  "Yobe",                       "North East",
  "Jigawa",                     "North West",
  "Kaduna",                     "North West",
  "Kano",                       "North West",
  "Katsina",                    "North West",
  "Kebbi",                      "North West",
  "Sokoto",                     "North West",
  "Zamfara",                    "North West",
  "Abia",                       "South East",
  "Anambra",                    "South East",
  "Ebonyi",                     "South East",
  "Enugu",                      "South East",
  "Imo",                        "South East",
  "Akwa Ibom",                  "South South",
  "Bayelsa",                    "South South",
  "Cross River",                "South South",
  "Delta",                      "South South",
  "Edo",                        "South South",
  "Rivers",                     "South South",
  "Ekiti",                      "South West",
  "Lagos",                      "South West",
  "Ogun",                       "South West",
  "Ondo",                       "South West",
  "Osun",                       "South West",
  "Oyo",                        "South West"
)
stopifnot(nrow(zone_map) == 37)
write_csv(zone_map, "outputs/tableau/zone_state_map.csv")


# ---- Quick check ------------------------------------------------------------
cat("\nFiles written to outputs/tableau/:\n")
print(list.files("outputs/tableau"))
cat("\nRows in tableau_estimates.csv:", nrow(est), "\n")
print(count(est, indicator, dimension))
