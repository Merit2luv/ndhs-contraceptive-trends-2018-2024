## 2026-09-28
- Set up project folders and RStudio project
- Loaded 2018 IR (41,821 women) and 2024 IR (39,050 women)
- Checked all 13 variables exist in both rounds
- v313: modern = 3 in both rounds. v502: 1 = currently in union/living with a man
- Weighted mCPR validated against official reports:
  - 2018: in union 12.0%, all women 10.5% (FR359, Table 7.2, p.139)
  - 2024: in union 15.3%, all women 13.1% (2024 Final Report, Table 7.3, p.160)
- Published code to public GitHub repo (ndhs-contraceptive-trends-2018-2024)

## 2026-09-29
- Checked v024 (region): codes 1 and 3 swap meaning between rounds
  (2018: 1=north central, 3=north west; 2024: 1=north west, 3=north central)
  Fixed by joining on labels, not raw codes
- Checked v190 (wealth): clean, same codes both rounds
- Checked v106 (education): 2024 adds "don't know" (code 8), not in 2018.
  Excluded from comparison
- Checked v025 (urban/rural): clean, same codes both rounds
- Completed all four breakdowns: region, wealth, education, urban/rural
- All wealth, education and residence changes are statistically clear (CI excludes 0)
- Two region changes are not clear: north central, south east
- Key finding: gains are concentrated among richer, more educated, urban women
  - Wealth: richest +4.9 pts vs poorest +1.5 pts
  - Education: higher +5.3 pts vs no education +2.1 pts
  - Residence: urban +4.2 pts vs rural +2.4 pts
- Next: findings + gaps LinkedIn posts, then discontinuation (calendar variable)