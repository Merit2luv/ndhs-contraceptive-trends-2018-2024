# Findings: Contraceptive Use and Method Retention in Nigeria, 2018 to 2024

**Data:** NDHS 2018 and 2024, women aged 15-49 (41,821 and 39,050 women).
**Author:** Ofikwu Matthew

## Summary

Modern contraceptive use rose from 10.5% to 13.1%, and women who started a method were somewhat more likely to still be using one a year later: 12-month discontinuation fell from 34.6% to 31.2%. But the gains were uneven. Wealthier and better-educated women, and women in the South West, gained the most. The poorest women showed no detectable improvement in retention, and the North East moved in the wrong direction on retention, though that change is not statistically distinguishable from zero.

Access gets women started. Retention keeps them protected. The two tell different stories in different places.

## 1. Modern contraceptive use

All women 15-49, survey-weighted, 95% confidence intervals.

| | 2018 | 2024 | Change (95% CI) |
|---|---|---|---|
| **Overall** | 10.5% (10.0-11.0) | 13.1% (12.5-13.7) | +2.6 pts |

**By wealth**

| | 2018 | 2024 | Change (95% CI) |
|---|---|---|---|
| Poorest | 3.5% | 4.6% | +1.1 (0.2 to 2.1) |
| Poorer | 5.9% | 7.1% | +1.2 (-0.1 to 2.5), not significant |
| Middle | 9.8% | 12.1% | +2.4 (1.0 to 3.7) |
| Richer | 14.4% | 17.5% | +3.2 (1.8 to 4.6) |
| Richest | 16.9% | 21.3% | +4.5 (2.8 to 6.2) |

**By education**

| | 2018 | 2024 | Change (95% CI) |
|---|---|---|---|
| No education | 4.0% | 5.7% | +1.7 (0.9 to 2.6) |
| Primary | 12.1% | 13.2% | +1.1 (-0.6 to 2.8), not significant |
| Secondary | 13.3% | 15.6% | +2.3 (1.2 to 3.3) |
| Higher | 19.0% | 24.2% | +5.2 (3.2 to 7.1) |

**By zone**

| | 2018 | 2024 | Change (95% CI) |
|---|---|---|---|
| North Central | 11.5% | 13.7% | +2.3 (0.5 to 4.0) |
| North East | 6.9% | 10.0% | +3.1 (1.5 to 4.7) |
| North West | 5.3% | 7.1% | +1.8 (0.4 to 3.3) |
| South East | 10.6% | 13.5% | +2.9 (1.1 to 4.7) |
| South South | 15.5% | 17.1% | +1.7 (-0.2 to 3.5), not significant |
| South West | 18.4% | 25.5% | +7.1 (4.8 to 9.4) |

![Modern use by wealth](outputs/charts/mcpr_wealth.png)
![Modern use by education](outputs/charts/mcpr_educ.png)
![Modern use by zone](outputs/charts/mcpr_region.png)

**The gap widened in absolute terms.** The richest-poorest gap in modern use grew by 3.3 percentage points (95% CI 1.4 to 5.3). In relative terms the picture is different: the poorest grew by about a third (3.5% to 4.6%) against about a quarter for the richest (16.9% to 21.3%), but from a base so low that the absolute gap still grew. Both framings are true, and both should be reported.

## 2. 12-month discontinuation

Share of women who stop using a method within 12 months of starting it. Switching to another method is not counted as discontinuation. 95% cluster-bootstrap CIs.

| | 2018 | 2024 | Change (95% CI) |
|---|---|---|---|
| **Overall** | 34.6% | 31.2% | -3.4 pts (-5.8 to -1.1) |

**By wealth**

| | 2018 | 2024 |
|---|---|---|
| Poorest | 42.2% | 43.5% |
| Poorer | 38.2% | 36.1% |
| Middle | 39.0% | 33.9% |
| Richer | 35.2% | 31.6% |
| Richest | 29.9% | 25.4% |

Tested changes: richest -4.5 pts (CI -7.8 to -1.4), a real decline. Poorest +1.3 pts (CI -6.5 to +10.1), no detectable change.

**By education**

| | 2018 | 2024 |
|---|---|---|
| No education | 42.4% | 39.0% |
| Primary | 33.6% | 32.4% |
| Secondary | 34.0% | 30.6% |
| Higher | 32.6% | 27.2% |

**By zone**

| | 2018 | 2024 |
|---|---|---|
| North Central | 37.4% | 29.9% |
| North East | 40.4% | 47.7% |
| North West | 46.3% | 36.0% |
| South East | 38.6% | 31.3% |
| South South | 31.7% | 27.5% |
| South West | 23.9% | 21.9% |

Tested changes: North West -10.3 pts (CI -17.0 to -3.9), a real decline. North East +7.3 pts (CI -0.9 to +14.0), suggestive only.

![Discontinuation by wealth](outputs/charts/disc_wealth.png)
![Discontinuation by education](outputs/charts/disc_educ.png)
![Discontinuation by zone](outputs/charts/disc_region.png)

**By method.** Implants and IUDs are the stickiest methods, with 12-month discontinuation roughly in the 10-17% range. Condoms sit around 30%. Pills and injectables lose close to half of users within a year, in both rounds. See `outputs/disc_method.csv` for estimates with confidence intervals. Method-level cells are small for some methods, so differences between rounds within a single method should be read with care.

![Discontinuation by method](outputs/charts/disc_method.png)

## 3. Putting use and retention together

![Use vs retention by zone](outputs/charts/use_vs_discontinuation_zones.png)

Each arrow runs from a zone's 2018 position to its 2024 position. Right means more use, down means better retention.

- **North West:** use barely moved, but retention improved sharply. Women who use methods there are staying on them.
- **North East:** use rose clearly, but discontinuation appears to have risen too. More women are starting, and possibly more are stopping. This needs a closer look.
- **South West:** the highest and fastest-rising use, with the lowest discontinuation in both rounds.

## What this does and doesn't show

**Supported by the data:** the national rise in modern use; the national fall in discontinuation; the richest and North West declines in discontinuation; the widening absolute wealth gap in use.

**Not supported:** any claim about why. The shift toward implants, which are among the stickiest methods and whose use grew, is a plausible contributor to better retention, but this analysis does not test that. The North East result and the poorest-women result are consistent with no change.

**Implications worth exploring (hypotheses, not findings):**
- Retention support, such as counselling and follow-up, may matter most for pill and injectable users, who have the highest discontinuation.
- The poorest women gained access but not retention. Cost, supply and follow-up barriers could be investigated.
- The North East warrants a dedicated look at both uptake and discontinuation.

## Method notes and limitations

Full methods are in the [README](README.md). The main limitations: calendar data depend on recall; the two discontinuation windows cover different 5-year periods; `n` counts episodes not women; subgroup results are descriptive and unadjusted for multiple comparisons; and reasons for discontinuation were not analysed.
