/*===============================================================
Project: K–12 Schooling and Fertility
File:    08_diff_in_diff.do

Course:  ECON421 — Education and Human Capital in Developing Economies
Author:  Erika Salvador '28 (esalvador28@amherst.edu)

Purpose:
  Main DiD estimates with continuous SHS exposure:
    y = β0·Treated + β1·SHS + β2·(Treated × SHS) + FE + ε
  Three specifications:
    (1) Baseline: no individual controls
    (2) + SES:    urban, wealth_index
    (3) + Full:   SES + religion + ethnicity
  Treated cohorts are those born in 2000 or later (SHS-eligible).
  All regressions include province, birth-cohort, and survey-year fixed
  effects, with standard errors clustered at the province level.

Inputs:
  D:/ECON421/Results/output/dhs_with_shs_enrollment_exposure.dta

Outputs:
  D:/ECON421/Results/output/table/draft2/main_did_timing.tex

===============================================================*/

version 17
clear all
set more off
set maxvar 32767

*------------------------------*
* 0. Paths
*------------------------------*
global ROOT  "D:/ECON421"
global DATA  "$ROOT/Results"
global OUT   "$DATA/output"
global TABLE "$OUT/table"

capture mkdir "$DATA"
capture mkdir "$OUT"
capture mkdir "$TABLE"

global TABLE_D2 "$TABLE/draft2"
capture mkdir "$TABLE_D2"

*------------------------------*
* 1. Load merged DHS + SHS data
*------------------------------*
use "$OUT/dhs_with_shs_enrollment_exposure.dta", clear

*------------------ Province FE (numeric) ---------------------*
capture confirm variable prov_fe
if _rc {
    capture confirm variable prov_key
    if _rc {
        di as error "prov_key not found; cannot create province FE."
        exit 198
    }
    encode prov_key, gen(prov_fe)
}
label var prov_fe "Province FE id"

*------------------------------*
* 2. Remove unmatched provinces (safety)
*------------------------------*
local exp shs_per_1000_g10
drop if missing(`exp')

*------------------------------*
* 3. Construct cohort and treatment
*------------------------------*
capture confirm variable birth_year
if _rc {
    gen birth_year = survey_year - age if !missing(survey_year, age)
}
capture confirm variable cohort
if _rc {
    gen cohort = birth_year
}

gen treated_true = (cohort >= 2000)
gen post_true    = treated_true   // first SHS-eligible cohort = 2000+

* DiD regressors: Treated, SHS, Treated × SHS
capture drop treated shs treated_shs
gen treated     = treated_true
gen shs         = `exp'
gen treated_shs = treated * shs

*------------------------------*
* 4. Controls & FE
*------------------------------*
local controls_none ""
local controls_ses  "urban wealth_index"
local controls_full "urban wealth_index rel_prot rel_inc rel_muslim rel_other eth_cebuano eth_ilocano eth_other"

local provfe   "prov_fe"
local wt       "w"
local cohortfe "cohort"
local year     "survey_year"

capture which reghdfe
if _rc ssc install reghdfe, replace

*------------------------------*
* 5. Timing outcome list
*------------------------------*
* Column blocks:
*   - Age at first birth: models (1)–(3)
*   - Birth by 18:        models (4)–(6)
*   - Birth by 20:        models (7)–(9)
local out_timing "age_first_birth birth_by18 birth_by20"

*------------------------------*
* 6. Timing table: Chaisemartin-style wide layout
*------------------------------*

capture file close fh
file open fh using "$TABLE_D2/main_did_timing.tex", write replace

* Storage: outcome labels, 9 columns (3 specs × 3 outcomes)
local i   = 0
local col = 0

foreach y of local out_timing {

    * Outcome labels for column groups
    if "`y'" == "age_first_birth" local ylab "Age at first birth"
    else if "`y'" == "birth_by18" local ylab "Had a birth by age 18"
    else if "`y'" == "birth_by20" local ylab "Had a birth by age 20"

    local ++i
    local ylab`i' "`ylab'"

    * Models: 1 = baseline, 2 = SES, 3 = full
    forvalues s = 1/3 {
        local ++col

        if `s' == 1 local ctrls "`controls_none'"
        else if `s' == 2 local ctrls "`controls_ses'"
        else if `s' == 3 local ctrls "`controls_full'"

        quietly reghdfe `y' treated shs treated_shs ///
            `ctrls' [pw = `wt'], ///
            absorb(`provfe' `cohortfe' `year') vce(cluster `provfe')

        * Save coefficient and SE for the interaction Treated×SHS only
        capture scalar b  = _b[treated_shs]
        capture scalar se = _se[treated_shs]
        if _rc {
            local cellb_`col'  "--"
            local cellse_`col' ""
        }
        else {
            scalar p = 2*ttail(e(df_r), abs(b/se))
            local star ""
            if (p<0.01)      local star "***"
            else if (p<0.05) local star "**"
            else if (p<0.10) local star "*"
            local bstr  : display %6.3f b
            local sestr : display %6.3f se
            local cellb_`col'  "`bstr'`star'"
            local cellse_`col' "(`sestr')"
        }

        * Save N and R2 for this model
        local N`col'   : display %9.0fc e(N)
        local R2_`col' : display %6.3f  e(r2)
    }
}

*------------------------------*
* 7. Write LaTeX for timing table
*------------------------------*

file write fh "\begin{table}[htbp]" _n
file write fh "\centering" _n
file write fh "\caption{Difference-in-differences estimates of SHS exposure on fertility timing outcomes}" _n
file write fh "\label{tab:main_did_timing}" _n
file write fh "\begin{tabular}{lccccccccc}" _n
file write fh "\toprule" _n

file write fh " & \multicolumn{3}{c}{`ylab1'} & \multicolumn{3}{c}{`ylab2'} & \multicolumn{3}{c}{`ylab3'} \\\\" _n
file write fh "\cmidrule(lr){2-4} \cmidrule(lr){5-7} \cmidrule(lr){8-10}" _n
file write fh "Model: & (1) & (2) & (3) & (4) & (5) & (6) & (7) & (8) & (9) \\\\" _n
file write fh "\midrule" _n

file write fh "\textit{Variables} \\\\" _n
file write fh "SHS$\times$Post & `cellb_1' & `cellb_2' & `cellb_3' & `cellb_4' & `cellb_5' & `cellb_6' & `cellb_7' & `cellb_8' & `cellb_9' \\\\" _n
file write fh " & `cellse_1' & `cellse_2' & `cellse_3' & `cellse_4' & `cellse_5' & `cellse_6' & `cellse_7' & `cellse_8' & `cellse_9' \\\\" _n
file write fh "\addlinespace" _n

file write fh "\textit{Controls} \\\\" _n
file write fh "Urban residence & No & Yes & Yes & No & Yes & Yes & No & Yes & Yes \\\\" _n
file write fh "Wealth index & No & Yes & Yes & No & Yes & Yes & No & Yes & Yes \\\\" _n
file write fh "Religion & No & No & Yes & No & No & Yes & No & No & Yes \\\\" _n
file write fh "Ethnicity & No & No & Yes & No & No & Yes & No & No & Yes \\\\" _n
file write fh "\addlinespace" _n

file write fh "\textit{Fit statistics} \\\\" _n
file write fh "Observations & `N1' & `N2' & `N3' & `N4' & `N5' & `N6' & `N7' & `N8' & `N9' \\\\" _n
file write fh "R-squared & `R2_1' & `R2_2' & `R2_3' & `R2_4' & `R2_5' & `R2_6' & `R2_7' & `R2_8' & `R2_9' \\\\" _n
file write fh "\bottomrule" _n

file write fh "\multicolumn{10}{p{0.95\linewidth}}{\footnotesize Standard errors in parentheses, clustered at the province level. All regressions include province, birth-cohort, and survey-year fixed effects and are weighted using DHS sampling weights. Birth-by-age indicators are defined among women who have reached the respective age thresholds; age at first birth is defined for women who have had at least one birth. *, **, *** denote significance at the 10\%, 5\%, and 1\% levels, respectively.} \\\\" _n

file write fh "\end{tabular}" _n
file write fh "\end{table}" _n

file close fh
