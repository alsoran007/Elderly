# Fixed 41-item FI audit (2026-07-29)

All outputs contain exactly 41 named deficit columns and use threshold >=33 valid items.

              metric        value cohort
1           raw_rows 5.455000e+04  SHARE
2         age60_rows 3.660400e+04  SHARE
3    fi_eligible_all 5.417700e+04  SHARE
4  fi_eligible_age60 3.636100e+04  SHARE
5      fi_median_all 1.486486e-01  SHARE
6    fi_median_age60 1.689189e-01  SHARE
7             fi_min 0.000000e+00  SHARE
8             fi_max 9.736842e-01  SHARE
9         item_count 4.100000e+01  SHARE
10         threshold 3.300000e+01  SHARE
11          raw_rows 2.683900e+04   MHAS
12        age60_rows 1.017400e+04   MHAS
13   fi_eligible_all 1.345000e+03   MHAS
14 fi_eligible_age60 8.820000e+02   MHAS
15     fi_median_all 3.212121e-01   MHAS
16   fi_median_age60 3.454545e-01   MHAS
17            fi_min 3.636364e-02   MHAS
18            fi_max 9.090909e-01   MHAS
19        item_count 4.100000e+01   MHAS
20         threshold 3.300000e+01   MHAS
21          raw_rows 9.765000e+03  CLHLS
22        age60_rows 9.749000e+03  CLHLS
23   fi_eligible_all 9.222000e+03  CLHLS
24 fi_eligible_age60 9.207000e+03  CLHLS
25     fi_median_all 1.666667e-01  CLHLS
26   fi_median_age60 1.687500e-01  CLHLS
27            fi_min 0.000000e+00  CLHLS
28            fi_max 7.708333e-01  CLHLS
29        item_count 4.100000e+01  CLHLS
30         threshold 3.300000e+01  CLHLS

Interpretation:
- SHARE/MHAS retain only documented or explicitly flagged substitutes.
- CLHLS unsupported baseline concepts remain NA; death/follow-up variables d14*/d18* were excluded.
- Review mapping rows with status cross_domain_substitute or unsupported before outcome/model work.
