# SHARE country-specific visit-period audit

Run date: 2026-07-28. The raw Gateway harmonized file was read with selected columns only; no raw data or mortality outcomes were modified.

## Scope and fields

- Source: `D:\AI_project\sql\share harmonised\GH_SHARE_g.dta`
- Country grouping: `country` (29 labeled SHARE countries); `isocountry` is retained as a cross-check.
- Baseline: wave 4, 2011 interview year/month, `r4iwy`/`r4iwm`, restricted to `r4iwstat == 1` for completed respondent interviews.
- Follow-up: wave 6, 2015 interview year/month, `r6iwy`/`r6iwm`, restricted to `r6iwstat == 1`.
- A month is represented by its first calendar day because the Gateway fields contain year and month but no interview day.

## Overall findings

- Source rows: **158,764**.
- Valid wave-4 respondent interview months: **57,982**; observed range **2010-05 to 2012-04**; years observed: **2010, 2011, 2012**.
- Valid wave-6 respondent interview months: **68,055**; observed range **2015-01 to 2015-11**; years observed: **2015**.
- Respondents with valid dates in both waves: **34,683**; paired interval range **35 to 64 months**, median **47.0 months**.
- The nominal 2011-to-2015 interval is not identical for every respondent: the country table reports the number at exactly 48 months and the number outside 48 months.

## Interpretation boundary

The table describes fieldwork timing and the resulting variation in the calendar interval between wave 4 and wave 6. It does not define the final mortality censoring date, impute missing interview dates, or estimate country effects.

The 2010 and 2012 wave-4 values are retained as observed source values. They should not be silently recoded to 2011; if the analysis requires a fixed 2011 baseline, those records need an explicit inclusion rule decided by Claude/PI.

## Outputs

- Country summary: `D:\AI_project\project3\results\share_country_visit_period_audit\share_country_visit_period_summary_2026-07-28.csv`
- Country-month distribution: `D:\AI_project\project3\results\share_country_visit_period_audit\share_country_visit_period_monthly_2026-07-28.csv`
- Paired respondent intervals: `D:\AI_project\project3\results\share_country_visit_period_audit\share_country_visit_period_pairs_2026-07-28.csv`
- Field definitions: `D:\AI_project\project3\results\share_country_visit_period_audit\share_country_visit_period_field_definitions_2026-07-28.csv`
- Run metadata: `D:\AI_project\project3\results\share_country_visit_period_audit\share_country_visit_period_metadata_2026-07-28.json`
- Log: `D:\AI_project\project3\logs\share_country_visit_period_audit_2026-07-28.log`
