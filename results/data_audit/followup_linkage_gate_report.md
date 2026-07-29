# Follow-up linkage and mortality-source gate

This Phase 1 artifact links source fields and coverage only. It is not the final analysis-ready 5-year outcome.
Raw data under D:/AI_project/sql were read only and were not modified.

## CHARLS
- CHARLS 2015/2018/2020 Sample_Infor linkage and 2020 Exit_Module date fields were processed by the preceding follow-up linkage stage.
- Sample_Infor died status and later-wave absence remain distinct from a validated death date or final censoring date.

## KLoSA
- KLoSA w01/w02 main-file coverage was linked; the newly available w02 EXIT source contains 187 unique PID records and is linked by PID.
- w02 EXIT dates are mortality-source candidates; wstat interpretation, date precedence, and administrative censoring remain to be confirmed.

## HRS
- HRS Exit A_R source rows: 5985 across waves 2012/2014/2016/2018/2020.
- Wave-specific rows: 2012=1187; 2014=1242; 2016=1310; 2018=980; 2020=1266.
- All parsed HRS Exit A_R IDs are unique; overlap with the 2012 RAND fat-file reference is 0/1125/1256/895/1169 by wave.
- 2012/2014/2016 were parsed from the supplied fixed-width .da files using their matching .dct column positions; 2018/2020 were read from the supplied Stata A_R files.
- Death year/month are retained as raw and cleaned fields. Month 98 and year 9998 are marked unresolved rather than converted to valid dates.
- Exit A_R records are mortality-source candidates; a final event requires a valid death date and an approved administrative censoring rule.

## Required next gate
- Confirm CHARLS death-date and administrative censoring rules.
- Confirm KLoSA death-date precedence, wstat interpretation, and administrative censoring rules.
- Confirm HRS death-date precedence across Exit A_R waves and the approved administrative censoring date for each baseline.
- Only then create final five-year event, time-at-risk, and censoring variables.
