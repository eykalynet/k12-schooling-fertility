/*===============================================================
Project: K–12 Schooling and Fertility
File:    18_mechanism_check_intensity.do

Course:  ECON421 — Education and Human Capital in Developing Economies
Author:  Erika Salvador '28 (esalvador28@amherst.edu)

Purpose:
  Mechanism check: sexual exposure intensity (conditional on ever having sex).

  Outcomes:
    sex_last4w  sex_3m  sex_12m  partners_12m  multi_partner  any_nonmarital

  Specification:
    y = β0·Treated + β1·SHS + β2·(Treated × SHS) + X_i'θ + FE + ε
    with province, birth-cohort, and survey-year fixed effects,
    DHS sampling weights, and province-clustered standard errors.

  Specifications:
    (1) Baseline (no individual controls)
    (2) + SES controls: urban, wealth_index
    (3) + Socio-cultural controls: religion + ethnicity

Inputs:
  D:/ECON421/Results/output/dhs_with_shs_enrollment_exposure.dta

Outputs:
  - $TABLE_D2/mech_exposure.tex
===============================================================*/

version 17
clear all
set more off
set maxvar 32767

*--------------------------------------------------------------*
* 0. Paths                                                     *
*--------------------------------------------------------------*
global ROOT     "D:/ECON421"
global DATA     "$ROOT/Results"
global OUT      "$DATA/output"
global TABLE    "$OUT/table"
global TABLE_D2 "$TABLE/draft2"

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
    capture confirm variable prov_key
    if _rc {
        di as error "prov_key not found; cannot create province FE."
        exit 198
    }
    encode prov_key, gen(prov_fe)
}
label var prov_fe "Province FE id"

* Exposure (SHS)
local exp shs_per_1000_g10
drop if missing(`exp')

* Need ever_sex restriction
capture confirm variable ever_sex
if _rc {
    di as error "ever_sex not found (needed for restriction ever_sex==1)."
    exit 198
}

*--------------------------------------------------------------*
* 2. Cohort + treatment                                        *
*--------------------------------------------------------------*
capture confirm variable birth_year
if _rc {
    capture confirm variable age
    if _rc {
        di as error "age not found; cannot construct birth_year."
        exit 198
    }
    gen birth_year = survey_year - age
}
label var birth_year "Birth year (survey_year - age)"

capture confirm variable cohort
if _rc gen cohort = birth_year
label var cohort "Birth cohort"

gen treated_true = (cohort >= 2000) if !missing(cohort)
gen treated      = treated_true
gen shs          = `exp'
gen treated_shs  = treated * shs
label var treated_shs "Treated × SHS exposure"

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
* 4. Outcomes (stacked mini-panels)                            *
*--------------------------------------------------------------*
local outcomes "sex_last4w sex_3m sex_12m partners_12m multi_partner any_nonmarital"

foreach y of local outcomes {
    capture confirm variable `y'
    if _rc {
        di as error "`y' not found."
        exit 198
    }
}

*--------------------------------------------------------------*
* 5. Run regressions & store coef/SE/stars + fit stats          *
*--------------------------------------------------------------*
local row = 0
foreach y of local outcomes {

    local ++row

    local ylab : variable label `y'
    if "`ylab'"=="" local ylab "`y'"
    local ylab`row' "`ylab'"

    forvalues s=1/3 {

        if `s'==1 local ctrls "`controls_none'"
        if `s'==2 local ctrls "`controls_ses'"
        if `s'==3 local ctrls "`controls_full'"

        quietly reghdfe `y' treated shs treated_shs ///
            `ctrls' [pw=`wt'] if ever_sex==1, ///
            absorb(`provfe' `cohortfe' `yearfe') ///
            vce(cluster `provfe')

        * Fit statistics (outcome-specific)
        local N_`row'_`s' : display %9.0fc e(N)
        capture local R2_`row'_`s' : display %6.3f e(r2)
        if _rc local R2_`row'_`s' "."

        * Default coef display
        local cellb_`row'_`s'  "--"
        local cellse_`row'_`s' ""

        capture scalar b  = _b[treated_shs]
        capture scalar se = _se[treated_shs]

        if !_rc {
            scalar p = 2*ttail(e(df_r), abs(b/se))
            local star ""
            if p<0.01 local star "***"
            else if p<0.05 local star "**"
            else if p<0.10 local star "*"

            local bstr  : display %6.3f b
            local sestr : display %6.3f se
            local cellb_`row'_`s'  "`bstr'`star'"
            local cellse_`row'_`s' "(`sestr')"
        }
    }
}

*--------------------------------------------------------------*
* 6. Write LaTeX: stacked mini-panels                           *
*     Each outcome gets:
*       header + model row + variables + controls + fit stats
*--------------------------------------------------------------*
capture file close fh
file open fh using "$TABLE_D2/mech_exposure.tex", write replace

file write fh "\begin{table}[htbp]" _n
file write fh "\centering" _n
file write fh "\renewcommand{\arraystretch}{0.92}" _n
file write fh "\caption{Sexual exposure intensity as a mechanism}" _n
file write fh "\label{tab:mech_exposure}" _n
file write fh "\begin{tabular}{@{}lccc@{}}" _n
file write fh "\toprule" _n

forvalues r=1/`row' {

    * Outcome header
    file write fh " & \multicolumn{3}{c}{`ylab`r''} \\\\" _n
    file write fh "\cmidrule(lr){2-4}" _n
    file write fh "Model: & (1) & (2) & (3) \\\\" _n
    file write fh "\midrule" _n

    * Variables
    file write fh "\textit{Variables} \\\\" _n
    file write fh "$\text{Treated}_{c} \times \text{SHS}_{p}$ & `cellb_`r'_1' & `cellb_`r'_2' & `cellb_`r'_3' \\\\" _n
    file write fh " & `cellse_`r'_1' & `cellse_`r'_2' & `cellse_`r'_3' \\\\" _n

    * Controls first
    file write fh "\addlinespace[2pt]" _n
    file write fh "\textit{Controls} \\\\" _n
    file write fh "Urban residence & No & Yes & Yes \\\\" _n
    file write fh "Wealth index    & No & Yes & Yes \\\\" _n
    file write fh "Religion        & No & No  & Yes \\\\" _n
    file write fh "Ethnicity       & No & No  & Yes \\\\" _n

    * Fit statistics after controls (outcome-specific)
    file write fh "\addlinespace[2pt]" _n
    file write fh "\textit{Fit statistics} \\\\" _n
    file write fh "Number of observations & `N_`r'_1' & `N_`r'_2' & `N_`r'_3' \\\\" _n
    file write fh "R-squared              & `R2_`r'_1' & `R2_`r'_2' & `R2_`r'_3' \\\\" _n

    * Separator between mini-panels (not after last)
    if `r' < `row' file write fh "\midrule" _n
}

file write fh "\bottomrule" _n
file write fh "\end{tabular}" _n

file write fh "\vspace{4pt}" _n
file write fh "\parbox{0.88\linewidth}{\small" _n
file write fh "\textit{Notes:} Standard errors in parentheses, clustered at the province level. All regressions include province, birth-cohort, and survey-year fixed effects and are weighted using DHS sampling weights. The sample is restricted to women who report ever having sex (ever\_sex$=1$). Individual controls (urban residence, household wealth index, religion, and ethnicity) are added sequentially across columns. *, **, *** denote significance at the 10\%, 5\%, and 1\% levels." _n
file write fh "}" _n

file write fh "\end{table}" _n
file close fh

display as text "Done: stacked sexual exposure mechanism table written to $TABLE_D2/mech_exposure.tex"
