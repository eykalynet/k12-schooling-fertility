/*===============================================================
Project: K–12 Schooling and Fertility
File:    16_mechanism_check_human_capital.do

Course:  ECON421 — Education and Human Capital in Developing Economies
Author:  Erika Salvador '28 (esalvador28@amherst.edu)

Purpose:
  Mechanism check: human capital.

  This file estimates the effect of SHS exposure on educational
  attainment (years of schooling) using the same DiD structure as the
  main fertility-timing analysis.

  Outcome:
    • educ_years

  Specification:
    y = β0·Treated + β1·SHS + β2·(Treated × SHS) + FE + ε
    with province, birth-cohort, and survey-year fixed effects,
    DHS sampling weights, and province-clustered standard errors.

  Specifications:
    (1) Baseline (no individual controls)
    (2) + SES controls: urban, wealth_index
    (3) + Socio-cultural controls: religion + ethnicity

Inputs:
  D:/ECON421/Results/output/dhs_with_shs_enrollment_exposure.dta

Outputs:
  - $TABLE/draft2/mech_humancapital.tex
===============================================================*/

version 17
clear all
set more off
set maxvar 32767

*--------------------------------------------------------------*
* 0. Paths                                                     *
*--------------------------------------------------------------*
global ROOT  "D:/ECON421"
global DATA  "$ROOT/Results"
global OUT   "$DATA/output"
global TABLE "$OUT/table"
global TABLE_D2 "$TABLE/draft2"

capture mkdir "$DATA"
capture mkdir "$OUT"
capture mkdir "$TABLE"
capture mkdir "$TABLE_D2"

*--------------------------------------------------------------*
* 1. Load data                                                 *
*--------------------------------------------------------------*
use "$OUT/dhs_with_shs_enrollment_exposure.dta", clear

* Province FE
capture confirm variable prov_fe
if _rc {
    encode prov_key, gen(prov_fe)
}

* Drop missing exposure
local exp shs_per_1000_g10
drop if missing(`exp')

*--------------------------------------------------------------*
* 2. Cohort + treatment                                        *
*--------------------------------------------------------------*
capture confirm variable birth_year
if _rc gen birth_year = survey_year - age

capture confirm variable cohort
if _rc gen cohort = birth_year

gen treated_true = (cohort >= 2000)

gen treated     = treated_true
gen shs         = `exp'
gen treated_shs = treated * shs

*--------------------------------------------------------------*
* 3. Controls, FE, weights                                     *
*--------------------------------------------------------------*
local controls_none ""
local controls_ses  "urban wealth_index"
local controls_full "urban wealth_index rel_prot rel_inc rel_muslim rel_other eth_cebuano eth_ilocano eth_other"

local provfe   "prov_fe"
local cohortfe "cohort"
local yearfe   "survey_year"
local wt       "w"

capture which reghdfe
if _rc ssc install reghdfe, replace

*--------------------------------------------------------------*
* 4. Outcome                                                   *
*--------------------------------------------------------------*
local y "educ_years"
local ylab : variable label `y'
if "`ylab'"=="" local ylab "Years of education"

*--------------------------------------------------------------*
* 5. Run regressions                                           *
*--------------------------------------------------------------*
forvalues s = 1/3 {

    if `s'==1 local ctrls "`controls_none'"
    if `s'==2 local ctrls "`controls_ses'"
    if `s'==3 local ctrls "`controls_full'"

    quietly reghdfe `y' treated shs treated_shs ///
        `ctrls' [pw=`wt'], ///
        absorb(`provfe' `cohortfe' `yearfe') vce(cluster `provfe')

    capture scalar b  = _b[treated_shs]
    capture scalar se = _se[treated_shs]

    if _rc {
        local cellb_`s'  "--"
        local cellse_`s' ""
    }
    else {
        scalar p = 2*ttail(e(df_r), abs(b/se))
        local star ""
        if p<0.01 local star "***"
        else if p<0.05 local star "**"
        else if p<0.10 local star "*"

        local cellb_`s'  : display %6.3f b
        local cellb_`s'  "`cellb_`s''`star'"
        local cellse_`s' : display %6.3f se
        local cellse_`s' "(`cellse_`s'')"
    }

    local N`s'   : display %9.0fc e(N)
    local R2_`s' : display %6.3f  e(r2)
}

*--------------------------------------------------------------*
* 6. Write LaTeX                                               *
*--------------------------------------------------------------*
capture file close fh
file open fh using "$TABLE_D2/mech_humancapital.tex", write replace

file write fh "\begin{table}[htbp]" _n
file write fh "\centering" _n
file write fh "\caption{Mechanisms: human capital}" _n
file write fh "\label{tab:mech_humancapital}" _n
file write fh "\begin{tabular}{lccc}" _n
file write fh "\toprule" _n
file write fh " & \multicolumn{3}{c}{`ylab'} \\\\" _n
file write fh "\cmidrule(lr){2-4}" _n
file write fh "Model: & (1) & (2) & (3) \\\\" _n
file write fh "\midrule" _n

file write fh "\textit{Variables} \\\\" _n
file write fh "SHS$\times$Post & `cellb_1' & `cellb_2' & `cellb_3' \\\\" _n
file write fh " & `cellse_1' & `cellse_2' & `cellse_3' \\\\" _n
file write fh "\addlinespace" _n

file write fh "\textit{Controls} \\\\" _n
file write fh "Urban residence & No & Yes & Yes \\\\" _n
file write fh "Wealth index & No & Yes & Yes \\\\" _n
file write fh "Religion & No & No & Yes \\\\" _n
file write fh "Ethnicity & No & No & Yes \\\\" _n
file write fh "\addlinespace" _n

file write fh "\textit{Fit statistics} \\\\" _n
file write fh "Observations & `N1' & `N2' & `N3' \\\\" _n
file write fh "R-squared & `R2_1' & `R2_2' & `R2_3' \\\\" _n
file write fh "\bottomrule" _n

file write fh "\multicolumn{4}{p{0.95\linewidth}}{\footnotesize Standard errors in parentheses, clustered at the province level. All regressions include province, cohort, and survey-year fixed effects. *, **, *** denote significance at the 10\%, 5\%, and 1\% levels.} \\\\" _n

file write fh "\end{tabular}" _n
file write fh "\end{table}" _n
file close fh

display as text "Done: mech_humancapital.tex written."
