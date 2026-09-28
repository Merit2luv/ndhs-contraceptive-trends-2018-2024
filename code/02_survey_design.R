library(haven); library(dplyr); library(srvyr); library(survey)
library(labelled); library(ggplot2); library(tidyr); library(readr)
options(survey.lonely.psu = "adjust")

vars <- c("v001","v005","v012","v021","v022","v024","v025",
          "v106","v190","v312","v313","v501","v502")

ir18 <- read_dta("data/raw/ir2018.DTA", col_select = all_of(vars))
ir24 <- read_dta("data/raw/ir2024.DTA", col_select = all_of(vars))

prep <- function(d, yr) d %>% mutate(
  wt = v005/1e6,
  year = yr,
  modern = 100 * as.integer(as.numeric(v313) == 3),
  in_union = as.numeric(v502) == 1
)

des18 <- prep(ir18, 2018) %>%
  as_survey_design(ids = v021, strata = v022, weights = wt, nest = TRUE)
des24 <- prep(ir24, 2024) %>%
  as_survey_design(ids = v021, strata = v022, weights = wt, nest = TRUE)

des18 %>% filter(in_union) %>% summarise(mcpr = survey_mean(modern, vartype = "ci", na.rm = TRUE))
des24 %>% filter(in_union) %>% summarise(mcpr = survey_mean(modern, vartype = "ci", na.rm = TRUE))
# Weights are stored as integers, so divide by 1,000,000
# modern = 3 in v313 (checked with val_labels)
# Validated against official reports: 12.0% (2018) and 15.3% (2024)