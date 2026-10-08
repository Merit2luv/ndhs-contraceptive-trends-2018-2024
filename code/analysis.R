# =============================================================================
# NDHS 2018 vs 2024: Modern contraceptive use and 12-month method discontinuation
# Women aged 15-49, Nigeria
# Data: NDHS 2018 and 2024 Individual Recode (IR) files, placed in data/raw/
#   - data/raw/ir2018.DTA
#   - data/raw/ir2024.DTA
# Run top to bottom. Outputs are written to outputs/ and outputs/charts/
# =============================================================================

# ---- 0. Setup ---------------------------------------------------------------
library(haven)
library(dplyr)
library(tidyr)
library(stringr)
library(survey)
library(ggplot2)

set.seed(2026)                       # reproducible bootstrap results
options(survey.lonely.psu = "adjust")

path18 <- "data/raw/ir2018.DTA"
path24 <- "data/raw/ir2024.DTA"

dir.create("outputs/charts", recursive = TRUE, showWarnings = FALSE)

B_FAST  <- 200    # bootstrap reps for quick looks
B_FINAL <- 500    # bootstrap reps for final numbers (use 1000 if time allows)


# ---- 1. Reproductive calendar code map --------------------------------------
# Confirmed empirically by cross-tabbing the calendar character at the interview
# month against current method (v312), in both survey rounds.
# vcal_1 reads right-to-left in time: leftmost = most recent month (after
# padding). v018 (calendar position of interview month) matched the leading
# blank padding for all women in both rounds.
modern <- c("1","2","3","4","5","6","7","C","E","L","M","N","S")
trad   <- c("8","9","W")
events <- c("B","P","T")             # birth, pregnancy, termination


# ---- 2. Woman-month dataset from the calendar -------------------------------
# vcal_2 (discontinuation reason) is blank for most women, so pad to 80 chars
# before splitting to avoid unnest() recycling errors.
build_wm <- function(path, yr) {
  read_dta(path, col_select = c("caseid","v005","v018","vcal_1","vcal_2")) %>%
    mutate(wt     = v005 / 1e6,
           vcal_2 = str_pad(coalesce(as.character(vcal_2), ""), 80, side = "right"),
           cal1   = substr(vcal_1, v018, 80),   # interview month -> oldest month
           cal2   = substr(vcal_2, v018, 80),
           code   = str_split(cal1, ""),
           reason = str_split(cal2, "")) %>%
    select(caseid, wt, code, reason) %>%
    unnest(c(code, reason)) %>%
    group_by(caseid) %>% mutate(m_ago = row_number() - 1L) %>% ungroup() %>%
    mutate(year = yr,
           grp = case_when(code %in% modern ~ "modern",
                           code %in% trad   ~ "traditional",
                           code %in% events ~ "event",
                           code == "0"      ~ "none",
                           TRUE             ~ "other"))
}

wm <- bind_rows(build_wm(path18, 2018), build_wm(path24, 2024))

# Sanity checks
wm %>% count(year, grp)                                   # no "other" expected
wm %>% filter(m_ago == 0) %>% group_by(year) %>%          # ~10.5% and ~13.1%
  summarise(mcpr_cal = weighted.mean(grp == "modern", wt))


# ---- 3. Method-use episodes -------------------------------------------------
# Episode = run of the same method code within the 5-year calendar window.
# - Sterilization (6, 7) excluded from discontinuation analysis
# - Episodes that begin at the oldest edge of the window are dropped (left-censored)
# - Switching to another method is censored (not a discontinuation), DHS convention
# - Emergency contraception (E) and LAM (L) excluded from headline rates
use_codes <- c(setdiff(modern, c("6","7")), trad)

ep <- wm %>%
  filter(m_ago < 60) %>%
  arrange(year, caseid, desc(m_ago)) %>%                 # oldest -> newest
  group_by(year, caseid) %>%
  mutate(run = cumsum(code != lag(code, default = first(code)))) %>%
  group_by(year, caseid, run, code, wt) %>%
  summarise(start_ago = max(m_ago), end_ago = min(m_ago),
            dur = n(), .groups = "drop") %>%
  arrange(year, caseid, run) %>%
  group_by(year, caseid) %>%
  mutate(next_code = lead(code)) %>%
  ungroup() %>%
  filter(code %in% use_codes, start_ago < 59) %>%
  mutate(event = !is.na(next_code) & !(next_code %in% use_codes))

ep %>% count(year, event)

# Covariates for subgroup analysis and cluster bootstrap
cov_get <- function(path, yr)
  read_dta(path, col_select = c("caseid","v021","v024","v106","v190")) %>%
  mutate(year = yr, psu = as.numeric(v021),
         region = as_factor(v024), educ = as_factor(v106), wealth = as_factor(v190)) %>%
  select(year, caseid, psu, region, educ, wealth)

covs <- bind_rows(cov_get(path18, 2018), cov_get(path24, 2024))

ep2 <- ep %>%
  filter(!code %in% c("E","L")) %>%
  left_join(covs, by = c("year","caseid"))

saveRDS(ep2, "outputs/episodes.rds")     # cache so a power cut doesn't cost the rebuild


# ---- 4. 12-month discontinuation: estimator + cluster bootstrap -------------
# Discrete-time life table: monthly hazard = weighted stops / weighted at risk.
rate12 <- function(d) {
  h <- sapply(1:12, function(t)
    sum(d$wt[d$dur == t & d$event]) / sum(d$wt[d$dur >= t]))
  1 - prod(1 - h)
}

# Bootstrap by PSU (primary sampling unit) to respect survey clustering
boot_rate <- function(d, B = B_FAST) {
  psus <- unique(d$psu)
  idx  <- split(seq_len(nrow(d)), d$psu)
  est  <- replicate(B, {
    s <- sample(psus, replace = TRUE)
    rate12(d[unlist(idx[as.character(s)]), ])
  })
  tibble(n = nrow(d), disc12 = rate12(d),
         lo = quantile(est, .025), hi = quantile(est, .975))
}

# Bootstrap the 2024 minus 2018 change directly
prep <- function(d) list(d = d, idx = split(seq_len(nrow(d)), d$psu), psus = unique(d$psu))
draw <- function(P) {
  s <- sample(P$psus, replace = TRUE)
  rate12(P$d[unlist(P$idx[as.character(s)]), ])
}
boot_change <- function(d, B = B_FINAL) {
  P18 <- prep(filter(d, year == 2018)); P24 <- prep(filter(d, year == 2024))
  diffs <- replicate(B, draw(P24) - draw(P18))
  tibble(change = rate12(P24$d) - rate12(P18$d),
         lo = quantile(diffs, .025), hi = quantile(diffs, .975))
}

# Discontinuation tables (slow: run once, results are saved to CSV)
disc_overall <- ep2 %>% group_by(year) %>% group_modify(~ boot_rate(.x, B_FINAL))
disc_wealth  <- ep2 %>% group_by(year, wealth) %>% group_modify(~ boot_rate(.x, B_FINAL))
disc_educ    <- ep2 %>% group_by(year, educ) %>% group_modify(~ boot_rate(.x, B_FINAL))
disc_region  <- ep2 %>% group_by(year, region) %>% group_modify(~ boot_rate(.x, B_FINAL))
disc_method  <- ep2 %>% group_by(year, code) %>% filter(n() > 100) %>%
                group_modify(~ boot_rate(.x, B_FINAL))

write.csv(disc_overall, "outputs/disc_overall.csv", row.names = FALSE)
write.csv(disc_wealth,  "outputs/disc_wealth.csv",  row.names = FALSE)
write.csv(disc_educ,    "outputs/disc_educ.csv",    row.names = FALSE)
write.csv(disc_region,  "outputs/disc_region.csv",  row.names = FALSE)
write.csv(disc_method,  "outputs/disc_method.csv",  row.names = FALSE)

# Tests of change, 2018 -> 2024
chg_disc <- bind_rows(
  boot_change(ep2)                                   %>% mutate(group = "Overall"),
  boot_change(filter(ep2, wealth == "richest"))      %>% mutate(group = "Richest"),
  boot_change(filter(ep2, wealth == "poorest"))      %>% mutate(group = "Poorest"),
  boot_change(filter(ep2, region == "north east"))   %>% mutate(group = "North East"),
  boot_change(filter(ep2, region == "north west"))   %>% mutate(group = "North West")
)
print(chg_disc)
write.csv(chg_disc, "outputs/disc_change_tests.csv", row.names = FALSE)


# ---- 5. Modern contraceptive use (survey-weighted) --------------------------
# Standard DHS modern-method flag: v313 == 3. All women 15-49.
get_ir <- function(path, yr)
  read_dta(path, col_select = c("caseid","v005","v021","v022","v024","v106","v190","v313")) %>%
  mutate(year = yr, wt = v005 / 1e6,
         modern = as.numeric(v313 == 3),
         region = as_factor(v024), educ = as_factor(v106), wealth = as_factor(v190))

ir <- bind_rows(get_ir(path18, 2018), get_ir(path24, 2024))

des_fun <- function(d) svydesign(ids = ~v021, strata = ~v022, weights = ~wt,
                                 data = d, nest = TRUE)

# Overall (should match validated official figures: ~10.5% and ~13.1%)
mcpr_overall <- ir %>% group_by(year) %>%
  group_modify(~ {
    r <- svymean(~modern, des_fun(.x)); ci <- confint(r)
    tibble(mcpr = coef(r), lo = ci[1], hi = ci[2])
  })
print(mcpr_overall)
write.csv(mcpr_overall, "outputs/mcpr_overall.csv", row.names = FALSE)

# Change in modern use by subgroup. Surveys are independent, so
# SE(diff) = sqrt(se18^2 + se24^2).
chg <- function(by) {
  ir %>% group_by(year) %>%
    group_modify(~ {
      r <- svyby(~modern, as.formula(paste0("~", by)), des_fun(.x), svymean)
      as_tibble(r) %>% rename(group = 1, p = modern)
    }) %>% ungroup() %>%
    pivot_wider(names_from = year, values_from = c(p, se)) %>%
    mutate(change  = p_2024 - p_2018,
           se_diff = sqrt(se_2018^2 + se_2024^2),
           lo = change - 1.96 * se_diff,
           hi = change + 1.96 * se_diff,
           sig = lo > 0 | hi < 0)
}

w_chg <- chg("wealth")
e_chg <- chg("educ")
r_chg <- chg("region")
print(w_chg, n = Inf, width = Inf)
print(e_chg, n = Inf, width = Inf)
print(r_chg, n = Inf, width = Inf)

# Did the richest-poorest gap in modern use widen?
g <- function(y, grp, col) w_chg[[paste0(col, "_", y)]][w_chg$group == grp]
gap_chg <- (g(2024,"richest","p") - g(2024,"poorest","p")) -
           (g(2018,"richest","p") - g(2018,"poorest","p"))
se_gap  <- sqrt(g(2024,"richest","se")^2 + g(2024,"poorest","se")^2 +
                g(2018,"richest","se")^2 + g(2018,"poorest","se")^2)
gap_result <- c(gap_change = gap_chg, lo = gap_chg - 1.96 * se_gap, hi = gap_chg + 1.96 * se_gap)
print(gap_result)

write.csv(w_chg, "outputs/mcpr_change_wealth.csv", row.names = FALSE)
write.csv(e_chg, "outputs/mcpr_change_educ.csv",   row.names = FALSE)
write.csv(r_chg, "outputs/mcpr_change_region.csv", row.names = FALSE)


# ---- 6. Charts: modern use 2018 vs 2024 -------------------------------------
plot_mcpr <- function(d, title) {
  d %>% select(group, p_2018, p_2024, se_2018, se_2024) %>%
    pivot_longer(-group, names_to = c(".value", "year"), names_sep = "_") %>%
    mutate(lo = p - 1.96 * se, hi = p + 1.96 * se) %>%
    ggplot(aes(group, p, fill = year)) +
    geom_col(position = position_dodge(.8), width = .7) +
    geom_errorbar(aes(ymin = lo, ymax = hi), position = position_dodge(.8), width = .2) +
    scale_y_continuous(labels = scales::percent) +
    scale_fill_manual(values = c("2018" = "#9ecae1", "2024" = "#08519c")) +
    labs(title = title, x = NULL, y = "Modern contraceptive use (women 15-49)",
         fill = NULL, caption = "Source: NDHS 2018 & 2024. Bars: 95% CI.") +
    theme_minimal(base_size = 12) + theme(legend.position = "top")
}

ggsave("outputs/charts/mcpr_wealth.png", plot_mcpr(w_chg, "Modern contraceptive use by wealth"),
       width = 8, height = 5, dpi = 300)
ggsave("outputs/charts/mcpr_educ.png",   plot_mcpr(e_chg, "Modern contraceptive use by education"),
       width = 8, height = 5, dpi = 300)
ggsave("outputs/charts/mcpr_region.png", plot_mcpr(r_chg, "Modern contraceptive use by zone"),
       width = 9, height = 5, dpi = 300)

# ---- 7. Charts: discontinuation, and use vs discontinuation -----------------
# If you restarted R, reload the saved tables instead of re-running the bootstraps.
if (!exists("disc_method")) disc_method <- read.csv("outputs/disc_method.csv")
if (!exists("disc_wealth")) disc_wealth <- read.csv("outputs/disc_wealth.csv")
if (!exists("disc_educ"))   disc_educ   <- read.csv("outputs/disc_educ.csv")
if (!exists("disc_region")) disc_region <- read.csv("outputs/disc_region.csv")
if (!exists("r_chg"))       r_chg       <- read.csv("outputs/mcpr_change_region.csv")

method_lab <- c("1" = "Pill", "2" = "IUD", "3" = "Injectables", "4" = "Diaphragm",
                "5" = "Male condom", "8" = "Periodic abstinence", "9" = "Withdrawal",
                "C" = "Female condom", "M" = "Other modern", "N" = "Implants",
                "S" = "Standard Days", "W" = "Other traditional")

plot_disc <- function(d, xvar, title, flip = FALSE) {
  p <- d %>% ungroup() %>% mutate(year = factor(year)) %>%
    ggplot(aes(.data[[xvar]], disc12, fill = year)) +
    geom_col(position = position_dodge(.8), width = .7) +
    geom_errorbar(aes(ymin = lo, ymax = hi), position = position_dodge(.8), width = .2) +
    scale_y_continuous(labels = scales::percent, limits = c(0, NA)) +
    scale_fill_manual(values = c("2018" = "#fdae6b", "2024" = "#a63603")) +
    labs(title = title, x = NULL, y = "12-month discontinuation rate", fill = NULL,
         caption = "Source: NDHS 2018 & 2024 reproductive calendar. Bars: 95% cluster-bootstrap CI.\nSwitching to another method is not counted as discontinuation.") +
    theme_minimal(base_size = 12) + theme(legend.position = "top")
  if (flip) p + coord_flip() else p
}

# 7a. By method (sorted by 2024 rate)
dm <- disc_method %>% ungroup() %>%
  mutate(method = coalesce(unname(method_lab[as.character(code)]), as.character(code)))
ord <- dm %>% filter(year == 2024) %>% arrange(disc12) %>% pull(method)
dm  <- dm %>% mutate(method = factor(method, levels = union(ord, unique(method))))
ggsave("outputs/charts/disc_method.png",
       plot_disc(dm, "method", "12-month discontinuation by method", flip = TRUE),
       width = 8, height = 6, dpi = 300)

# 7b. By wealth, education, zone
dw <- disc_wealth %>% mutate(wealth = factor(wealth,
        levels = c("poorest", "poorer", "middle", "richer", "richest")))
de <- disc_educ %>% mutate(educ = factor(educ,
        levels = c("no education", "primary", "secondary", "higher")))
ggsave("outputs/charts/disc_wealth.png",
       plot_disc(dw, "wealth", "12-month discontinuation by wealth"),
       width = 8, height = 5, dpi = 300)
ggsave("outputs/charts/disc_educ.png",
       plot_disc(de, "educ", "12-month discontinuation by education"),
       width = 8, height = 5, dpi = 300)
ggsave("outputs/charts/disc_region.png",
       plot_disc(disc_region, "region", "12-month discontinuation by zone"),
       width = 9, height = 5, dpi = 300)

# 7c. The combined picture: each zone's movement from 2018 to 2024
# x = modern contraceptive use, y = 12-month discontinuation.
# Moving right = more use. Moving down = better retention.
traj <- r_chg %>%
  transmute(region = as.character(group), mcpr_2018 = p_2018, mcpr_2024 = p_2024) %>%
  left_join(
    disc_region %>% ungroup() %>%
      transmute(year, region = as.character(region), disc12) %>%
      pivot_wider(names_from = year, values_from = disc12, names_prefix = "disc_"),
    by = "region")

p_traj <- ggplot(traj, aes(x = mcpr_2018, y = disc_2018)) +
  geom_segment(aes(xend = mcpr_2024, yend = disc_2024),
               arrow = arrow(length = unit(0.25, "cm")), colour = "#08519c", linewidth = 0.8) +
  geom_point(colour = "grey50", size = 2) +
  geom_text(aes(label = str_to_title(region)), vjust = -0.9, size = 3.5) +
  scale_x_continuous(labels = scales::percent) +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Use vs. retention by zone, 2018 to 2024",
       x = "Modern contraceptive use (women 15-49)",
       y = "12-month discontinuation rate",
       caption = "Arrows run from 2018 to 2024. Right and down is better.\nSource: NDHS 2018 & 2024.") +
  theme_minimal(base_size = 12)
ggsave("outputs/charts/use_vs_discontinuation_zones.png", p_traj,
       width = 9, height = 6, dpi = 300)

# ---- End --------------------------------------------------------------------
# Notes for the write-up:
# - Discontinuation: switching methods is censored; sterilization, E and L excluded.
# - n in discontinuation tables = episodes, not women.
# - Subgroup comparisons are descriptive; no multiplicity adjustment applied.
# - 95% CIs for discontinuation come from cluster (PSU) bootstrap.
