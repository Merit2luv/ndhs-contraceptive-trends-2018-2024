# Contraceptive Use and Method Retention in Nigeria, 2018 to 2024

Who is Nigeria's rise in modern contraceptive use reaching, and are women sticking with the methods they start?

This project answers both questions using the Nigeria Demographic and Health Surveys (NDHS) of 2018 and 2023-24 (labelled "2024" in the charts and tables).

**Author:** Ofikwu Matthew

## Headline findings

| | 2018 | 2024 | Change (95% CI) |
|---|---|---|---|
| Modern contraceptive use, all women 15-49 | 10.5% | 13.1% | Clear rise |
| 12-month method discontinuation | 34.6% | 31.2% | -3.4 pts (-5.8 to -1.1) |

1. **Use rose almost everywhere.** Every wealth, education and zone group rose significantly except the "poorer" quintile, primary-educated women and the South South zone. The South West gained the most (18.4% to 25.5%).
2. **The wealth gap in use widened.** The richest-poorest gap grew by 3.3 percentage points (95% CI 1.4 to 5.3). In relative terms, the poorest grew faster, but from a very low base (3.5% to 4.6%).
3. **Retention improved nationally.** Discontinuation fell by 3.4 points. The gain was concentrated among the richest women (-4.5 pts, CI -7.8 to -1.4) and in the North West (-10.3 pts, CI -17.0 to -3.9). The poorest women showed no detectable change.
4. **The North East is a flag, not a finding.** Use rose clearly (6.9% to 10.0%) while discontinuation rose from 40.4% to 47.7%. That change is not statistically distinguishable from zero (CI -0.9 to +14.0 pts).
5. **Method matters.** Implants and IUDs have the lowest 12-month discontinuation. Pills and injectables lose roughly half of users within a year.
6. **The gains survive adjustment.** After adjusting for age, residence, wealth, education and zone, the odds of modern use were 31% higher in 2024 (adjusted OR 1.31, 95% CI 1.22 to 1.40). The richest-poorest gap still widened by 3.0 points (95% CI 1.2 to 4.8) in absolute terms. On the odds scale, though, the wealth gradient did not change between surveys (interaction p = 0.96), so the wider gap in points reflects higher starting levels among wealthier women, not a steeper relative advantage.
7. **Part of the retention gain is the method mix.** After adjusting for wealth, education and zone, the 12-month hazard of stopping was 14% lower in 2024 (HR 0.86, 95% CI 0.80 to 0.94). Adding method narrowed that to 9% (HR 0.91, 0.84 to 0.99), consistent with part of the improvement coming from a shift toward stickier methods. Versus the pill, implants and IUDs had about 76% and 79% lower hazard of stopping (HR 0.24 and 0.21).

Full results, charts and interpretation are in [FINDINGS.md](FINDINGS.md).

![Use vs retention by zone](outputs/charts/use_vs_discontinuation_zones.png)

## Data

- NDHS 2018 and NDHS 2023-24 (labelled "2024" throughout), Individual Recode (IR) files, women aged 15-49 (41,821 and 39,050 women).
- **The data are not included in this repository.** DHS data are free but require registration and approval at [dhsprogram.com](https://dhsprogram.com). Place the files at:
  - `data/raw/ir2018.DTA`
  - `data/raw/ir2024.DTA`

## Methods

**Modern contraceptive use.** Standard DHS definition (`v313 == 3`) among all women 15-49. Estimates use the survey design (PSU `v021`, strata `v022`, weights `v005 / 1e6`) via the `survey` package. Changes between rounds are tested as differences of independent estimates, with SE = sqrt(se18² + se24²).

**12-month discontinuation.** Built from the DHS reproductive calendar (`vcal_1`):
- Each woman's calendar is aligned to her interview month using `v018`, giving one row per woman-month over the 5 years before interview.
- An episode is a run of the same method. Episodes that begin at the oldest edge of the window are dropped (left-censored).
- Switching to another method is censored, not counted as discontinuation (DHS convention). Stopping, or an episode ending in pregnancy or other non-use, counts as discontinuation.
- Sterilization, emergency contraception and LAM are excluded from the headline rates.
- Rates come from a weighted discrete-time life table (monthly hazard = weighted stops / weighted at risk, compounded over 12 months).
- 95% CIs come from a **cluster bootstrap by PSU** (500 replicates). Changes between rounds are tested by bootstrapping the 2024-minus-2018 difference.

**Validation checks.**
- `v018` matched the calendar's leading-blank padding for every woman in both rounds.
- The calendar's character at the interview month matched current method (`v312`) almost one-to-one, in both rounds. This was used to build the code map empirically rather than assume it.
- The calendar-based modern use at the interview month (10.5%, 13.1%) matched the survey-weighted estimates.

**Adjusted models** (`analysis_models.R`). Both surveys are pooled in one survey design with year-specific PSUs and strata.
- *Modern use:* survey-weighted logistic regression (adjusted odds ratios) on year, age group, residence, wealth, education and zone. Reference groups: 2018, age 15-19, rural, poorest, no education, North West.
- *Wealth gap:* a global Wald test of the year × wealth interaction on the odds scale, plus a linear probability model with the same terms, so the change in the gap is reported in percentage points.
- *Retention:* survey-weighted Cox models on method-use episodes, follow-up capped at 12 months, with and without method as a covariate. A hazard ratio below 1 means better retention.

## Repository structure

```
analysis.R              # descriptive pipeline: use, discontinuation, charts
analysis_models.R       # adjusted models: logistic, interaction, linear probability, Cox
FINDINGS.md             # results and interpretation
data/raw/               # NDHS files (not included)
outputs/
  charts/               # PNG charts
  models/               # adjusted-model result tables
  *.csv                 # result tables (use, discontinuation, change tests)
  episodes.rds          # cached episode dataset
```

## How to reproduce

1. Get the NDHS 2018 and 2024 IR files and place them in `data/raw/`.
2. Install packages: `haven`, `dplyr`, `tidyr`, `stringr`, `survey`, `survival`, `ggplot2`.
3. Open `analysis.R` in R or RStudio and run it from the project root.
4. Then run `analysis_models.R`. It needs `outputs/episodes.rds`, which `analysis.R` creates.

The discontinuation bootstraps are the slow step. Results are saved to `outputs/` as they finish.

## Limitations

- **Calendar data rely on recall** over up to 5 years, and recall quality can differ between survey rounds.
- **The two discontinuation estimates cover different periods.** Each window is the 5 years before its own survey, so 2018 reflects roughly 2013-2018 and 2024 roughly 2019-2024.
- **`n` in discontinuation tables is episodes, not women.** One woman can contribute several episodes.
- **Subgroup comparisons are descriptive.** No adjustment for multiple comparisons, and splits are one variable at a time, not mutually adjusted.
- **Small cells have wide intervals.** Method-level estimates for IUD and "other traditional" rest on a few hundred episodes.
- **Reasons for discontinuation were not analysed.** The reason codes (`vcal_2`) appear to differ between rounds, so they were not compared. Reasons are recorded in the last month of use, not the month of stopping.
- **Models show associations, not causes.** Adjusted estimates do not establish why the changes happened.
- **Model assumptions.** The linear probability model is an approximation used to report percentage points. The Cox model's proportional-hazards assumption was not formally checked, and it treats each method-use episode as an observation (women can contribute several; standard errors account for clustering by PSU).

## Possible extensions

- Reasons for discontinuation, once the 2024 code list is reconciled with 2018.
- Formal proportional-hazards diagnostics and a discrete-time logistic model as a robustness check on the Cox results.
- State-level estimates, where sample sizes allow.
