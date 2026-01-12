/*===============================================================
Project: K–12 Schooling and Fertility
File:    15_robustness_placebo_did.do

Course:  ECON421 — Education and Human Capital in Developing Economies
Author:  Erika Salvador '28 (esalvador28@amherst.edu)

Purpose:
  Placebo difference-in-differences checks using pre-reform cohorts.

  The analysis assigns pseudo-eligibility cutoffs to cohorts born in
  1975, 1980, 1985, and 1990, and estimates placebo treatment effects
  using the same specification, controls, and fixed effects as the
  main fertility-timing DiD.

  Outcomes:
    • Age at first birth
    • Had a birth by age 18
    • Had a birth by age 20

  Specification:
    y = SHS × PseudoPost + SHS + PseudoPost + FE + ε
    with province, cohort, and survey-year fixed effects,
    full individual controls, and province-clustered standard errors.

Inputs:
  D:/ECON421/Results/output/dhs_with_shs_enrollment_exposure.dta

Outputs:
  - $TABLE/draft2/main_did_timing_placebo.tex
===============================================================*/

version 17
clear all
set more off
set maxvar 32767

*--------------------------------------------------------------*
* Paths                                                        *
*--------------------------------------------------------------*
global ROOT  "D:/ECON421"
global DATA  "$ROOT/Results"
global OUT   "$DATA/output"
global TABLE "$OUT/table"
global TABLE_D2 "$TABLE/draft2"

capture mkdir "$TABLE_D2"

*--------------------------------------------------------------*
* Load data                                                    *
*--------------------------------------------------------------*
use "$OUT/dhs_with_shs_enrollment_exposure.dta", clear

* Create province FE if needed
capture confirm variable prov_fe
if _rc {
    encode prov_key, gen(prov_fe)
}

* Create cohort (birth_year = survey_year − age)
capture confirm variable birth_year
if _rc {
    gen birth_year = survey_year - age
}
capture confirm variable cohort
if _rc {
    gen cohort = birth_year
}

* Restrict to placebo sample
keep if cohort >= 1975 & cohort <= 1993

* Exposure variable
local exp shs_per_1000_g10

* Controls (full specification)
local ctrls "urban wealth_index rel_prot rel_inc rel_muslim rel_other eth_cebuano eth_ilocano eth_other"

local provfe   "prov_fe"
local cohortfe "cohort"
local year     "survey_year"
local wt       "w"

* Outcomes
local outcomes "age_first_birth birth_by18 birth_by20"

* Placebo cutoffs → 4 columns (UPDATED)
local cut1 1975     // UPDATED
local cut2 1980     // UPDATED
local cut3 1985     // UPDATED
local cut4 1990     // UPDATED

local cuts "`cut1' `cut2' `cut3' `cut4'"

* Storage for LaTeX cells
forvalues i = 1/12 {
    local cellb_`i' ""
    local cellse_`i' ""
    local N`i' ""
    local R2_`i' ""
}

*--------------------------------------------------------------*
* RUN REGRESSIONS (3 outcomes × 4 columns = 12 models)        *
*--------------------------------------------------------------*
local col = 0

foreach y of local outcomes {

    foreach c of local cuts {

        local ++col

        * Generate pseudo-treatment
        gen pseudo   = (cohort >= `c')
        gen shsXpost = pseudo * `exp'

        quietly reghdfe `y' shsXpost pseudo `exp' ///
            `ctrls' [pw=`wt'], ///
            absorb(`provfe' `cohortfe' `year') vce(cluster `provfe')

        * Extract coefficient + SE
        capture scalar b  = _b[shsXpost]
        capture scalar se = _se[shsXpost]

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

            local cellb_`col'  : display %6.3f b "`star'"
            local cellse_`col' : display "(" %6.3f se ")"
        }

        * Fit stats
        local N`col'   : display %9.0fc e(N)
        local R2_`col' : display %6.3f  e(r2)

        drop pseudo shsXpost
    }
}

*--------------------------------------------------------------*
* WRITE LaTeX TABLE                                            *
*--------------------------------------------------------------*
capture file close fh
file open fh using "$TABLE_D2/main_did_timing_placebo.tex", write replace

file write fh "\begin{table}[htbp]" _n
file write fh "\centering" _n
file write fh "\small" _n
file write fh "\renewcommand{\arraystretch}{0.92}" _n
file write fh "\caption{Placebo difference-in-differences using pre-reform cohorts}" _n
file write fh "\label{tab:main_did_timing_placebo}" _n
file write fh "\begin{tabular}{@{}lcccc@{}}" _n
file write fh "\toprule" _n

***************************************************************
*** PANEL A ***************************************************
***************************************************************
file write fh " & \multicolumn{4}{c}{Age at first birth} \\\\" _n
file write fh "\cmidrule(lr){2-5}" _n
file write fh "Model: & (1)\$^{\dagger}\$ & (2) & (3) & (4) \\\\" _n
file write fh "\midrule" _n

file write fh "\textit{Variables} \\\\" _n
file write fh "SHS\$\\times\$Post (placebo)"
forvalues j = 1/4 {
    file write fh " & `cellb_`j'''"
}
file write fh " \\\\" _n

file write fh " "
forvalues j = 1/4 {
    file write fh " & `cellse_`j'''"
}
file write fh " \\\\" _n

file write fh "\addlinespace[2pt]\n\specialrule{0.05pt}{1pt}{1pt}\n\addlinespace[2pt]" _n

file write fh "\textit{Placebo cutoff} \\\\" _n
file write fh "Cutoff used & `cut1' & `cut2' & `cut3' & `cut4' \\\\" _n

file write fh "\addlinespace[2pt]\n\specialrule{0.05pt}{1pt}{1pt}\n\addlinespace[2pt]" _n

file write fh "\textit{Fit statistics} \\\\" _n
file write fh "Number of observations"
forvalues j = 1/4 {
    file write fh " & `N`j'''"
}
file write fh " \\\\" _n

file write fh "R-squared"
forvalues j = 1/4 {
    file write fh " & `R2_`j'''"
}
file write fh " \\\\" _n

file write fh "\midrule[0.8pt]" _n

***************************************************************
*** PANEL B ***************************************************
***************************************************************
file write fh " & \multicolumn{4}{c}{Had a birth by age 18} \\\\" _n
file write fh "\cmidrule(lr){2-5}" _n
file write fh "Model: & (5)\$^{\dagger}\$ & (6) & (7) & (8) \\\\" _n
file write fh "\midrule" _n

file write fh "\textit{Variables} \\\\" _n
file write fh "SHS\$\\times\$Post (placebo)"
forvalues j = 5/8 {
    file write fh " & `cellb_`j'''"
}
file write fh " \\\\" _n

file write fh " "
forvalues j = 5/8 {
    file write fh " & `cellse_`j'''"
}
file write fh " \\\\" _n

file write fh "\addlinespace[2pt]\n\specialrule{0.05pt}{1pt}{1pt}\n\addlinespace[2pt]" _n

file write fh "\textit{Placebo cutoff} \\\\" _n
file write fh "Cutoff used & `cut1' & `cut2' & `cut3' & `cut4' \\\\" _n

file write fh "\addlinespace[2pt]\n\specialrule{0.05pt}{1pt}{1pt}\n\addlinespace[2pt]" _n

file write fh "\textit{Fit statistics} \\\\" _n
file write fh "Number of observations"
forvalues j = 5/8 {
    file write fh " & `N`j'''"
}
file write fh " \\\\" _n

file write fh "R-squared"
forvalues j = 5/8 {
    file write fh " & `R2_`j'''"
}
file write fh " \\\\" _n

file write fh "\midrule[0.8pt]" _n

***************************************************************
*** PANEL C ***************************************************
***************************************************************
file write fh " & \multicolumn{4}{c}{Had a birth by age 20} \\\\" _n
file write fh "\cmidrule(lr){2-5}" _n
file write fh "Model: & (9)\$^{\dagger}\$ & (10) & (11) & (12) \\\\" _n
file write fh "\midrule" _n

file write fh "\textit{Variables} \\\\" _n
file write fh "SHS\$\\times\$Post (placebo)"
forvalues j = 9/12 {
    file write fh " & `cellb_`j'''"
}
file write fh " \\\\" _n

file write fh " "
forvalues j = 9/12 {
    file write fh " & `cellse_`j'''"
}
file write fh " \\\\" _n

file write fh "\addlinespace[2pt]\n\specialrule{0.05pt}{1pt}{1pt}\n\addlinespace[2pt]" _n

file write fh "\textit{Placebo cutoff} \\\\" _n
file write fh "Cutoff used & `cut1' & `cut2' & `cut3' & `cut4' \\\\" _n

file write fh "\addlinespace[2pt]\n\specialrule{0.05pt}{1pt}{1pt}\n\addlinespace[2pt]" _n

file write fh "\textit{Fit statistics} \\\\" _n
file write fh "Number of observations"
forvalues j = 9/12 {
    file write fh " & `N`j'''"
}
file write fh " \\\\" _n

file write fh "R-squared"
forvalues j = 9/12 {
    file write fh " & `R2_`j'''"
}
file write fh " \\\\" _n

file write fh "\bottomrule" _n
file write fh "\end{tabular}" _n

file write fh "\vspace{4pt}" _n
file write fh "\parbox{0.72\linewidth}{\footnotesize" _n
file write fh "\textit{Notes:} Standard errors in parentheses, clustered at the province level. A dagger (\$^{\dagger}\$) marks the placebo model closest to the preferred baseline specification in Table~\\ref{tab:main_did_timing}. "
file write fh "All regressions include province, birth-cohort, and survey-year fixed effects and the full set of individual controls (urban residence, household wealth, religion, and ethnicity). "
file write fh "The sample includes pre-reform cohorts (1975--1993) who could not have been exposed to SHS. "
file write fh "Pseudo-treatment assigns eligibility to cohorts born in 1975, 1980, 1985, or 1990 and later. "   // UPDATED
file write fh "*, **, *** denote significance at the 10\\%, 5\\%, and 1\\% levels, respectively.}" _n

file write fh "\end{table}" _n
file write fh "\FloatBarrier" _n

file close 


