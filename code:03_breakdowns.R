# NDHS 2018 vs 2024: load data, build survey designs, validate mCPR
# Author: Ofikwu Matthew

# --- Packages ---
library(haven); library(dplyr); library(srvyr); library(survey)
library(labelled); library(ggplot2); library(tidyr); library(readr)
options(survey.lonely.psu = "adjust")

# --- Variables to load (13) ---
vars <- c("v001","v005","v012","v021","v022","v024","v025",
          "v106","v190","v312","v313","v501","v502")

# --- Load both rounds (IR = women's recode) ---
ir18 <- read_dta("data/raw/ir2018.DTA", col_select = all_of(vars))
ir24 <- read_dta("data/raw/ir2024.DTA", col_select = all_of(vars))
nrow(ir18); nrow(ir24)   # 41,821 and 39,050

# --- Code checks: modern = 3 in both rounds; v502 1 = currently in union ---
val_labels(ir18$v313); val_labels(ir24$v313)
val_labels(ir18$v502); val_labels(ir24$v502)

# --- Prep: weights are stored as integers, so divide by 1e6 ---
prep <- function(d, yr) d %>% mutate(
  wt = v005/1e6,
  year = yr,
  modern = 100 * as.integer(as.numeric(v313) == 3),
  in_union = as.numeric(v502) == 1
)

# --- Survey designs: clusters (v021), strata (v022), weights ---
des18 <- prep(ir18, 2018) %>%
  as_survey_design(ids = v021, strata = v022, weights = wt, nest = TRUE)
des24 <- prep(ir24, 2024) %>%
  as_survey_design(ids = v021, strata = v022, weights = wt, nest = TRUE)

# --- Validation vs official reports ---
# 2018: 12.0% in union, 10.5% all women (FR359, Table 7.2, p.139)
# 2024: 15.3% in union, 13.1% all women (2024 Final Report, Table 7.3, p.160)
des18 %>% filter(in_union) %>% summarise(mcpr = survey_mean(modern, vartype = "ci", na.rm = TRUE), n = unweighted(n()))
des24 %>% filter(in_union) %>% summarise(mcpr = survey_mean(modern, vartype = "ci", na.rm = TRUE), n = unweighted(n()))
des18 %>% summarise(mcpr = survey_mean(modern, vartype = "ci", na.rm = TRUE))
des24 %>% summarise(mcpr = survey_mean(modern, vartype = "ci", na.rm = TRUE))

val_labels(ir18$v024)
val_labels(ir24$v024)

prep <- function(d, yr) d %>% mutate(
  wt = v005/1e6, year = yr,
  modern = 100 * as.integer(as.numeric(v313) == 3),
  in_union = as.numeric(v502) == 1,
  region = as.character(haven::as_factor(v024))
)

des18 <- prep(ir18, 2018) %>%
  as_survey_design(ids = v021, strata = v022, weights = wt, nest = TRUE)
des24 <- prep(ir24, 2024) %>%
  as_survey_design(ids = v021, strata = v022, weights = wt, nest = TRUE)

r18 <- des18 %>% filter(in_union) %>% group_by(region) %>%
  summarise(mcpr_2018 = survey_mean(modern, na.rm = TRUE))

r24 <- des24 %>% filter(in_union) %>% group_by(region) %>%
  summarise(mcpr_2024 = survey_mean(modern, na.rm = TRUE))

region_change <- left_join(r18, r24, by = "region") %>%
  mutate(change = mcpr_2024 - mcpr_2018)

region_change

region_change <- region_change %>%
  mutate(se_change = sqrt(mcpr_2018_se^2 + mcpr_2024_se^2),
         lo = change - 1.96 * se_change,
         hi = change + 1.96 * se_change,
         clear = lo > 0 | hi < 0)

region_change
write_csv(region_change, "outputs/mcpr_change_by_region.csv")

w18 <- des18 %>% filter(in_union) %>% group_by(wealth = as.character(haven::as_factor(v190))) %>%
  summarise(mcpr_2018 = survey_mean(modern, na.rm = TRUE))

w24 <- des24 %>% filter(in_union) %>% group_by(wealth = as.character(haven::as_factor(v190))) %>%
  summarise(mcpr_2024 = survey_mean(modern, na.rm = TRUE))

wealth_change <- left_join(w18, w24, by = "wealth") %>%
  mutate(change = mcpr_2024 - mcpr_2018,
         se_change = sqrt(mcpr_2018_se^2 + mcpr_2024_se^2),
         lo = change - 1.96 * se_change, hi = change + 1.96 * se_change,
         clear = lo > 0 | hi < 0)
wealth_change

e18 <- des18 %>% filter(in_union, as.numeric(v106) != 8) %>%
  group_by(educ = as.character(haven::as_factor(v106))) %>%
  summarise(mcpr_2018 = survey_mean(modern, na.rm = TRUE))

e24 <- des24 %>% filter(in_union, as.numeric(v106) != 8) %>%
  group_by(educ = as.character(haven::as_factor(v106))) %>%
  summarise(mcpr_2024 = survey_mean(modern, na.rm = TRUE))

educ_change <- left_join(e18, e24, by = "educ") %>%
  mutate(change = mcpr_2024 - mcpr_2018,
         se_change = sqrt(mcpr_2018_se^2 + mcpr_2024_se^2),
         lo = change - 1.96 * se_change, hi = change + 1.96 * se_change,
         clear = lo > 0 | hi < 0)
educ_change

write_csv(wealth_change, "outputs/mcpr_change_by_wealth.csv")
write_csv(educ_change, "outputs/mcpr_change_by_education.csv")