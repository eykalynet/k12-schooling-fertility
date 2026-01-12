/*===============================================================
Project: K–12 Schooling and Fertility
File:    12_robustness_hazard.do

Course:  ECON421 — Education and Human Capital in Developing Economies
Author:  Erika Salvador '28 (esalvador28@amherst.edu)

Purpose:
  Robustness check using a discrete-time hazard model for FIRST birth.

  Outputs:
    (1) FE hazard LPM treatment effect (reghdfe): SHS × Post
    (2) Empirical age-specific annual hazards:
          h(a) = Pr(first birth at age a | childless up to age a)
    (3) LaTeX table with SHS × Post coefficient and age hazards (ages 13–48)
    (4) Hazard-by-age plot and CSV for external plotting

Inputs:
  D:/ECON421/Results/output/dhs_with_shs_enrollment_exposure.dta

Outputs:
  - $TABLE/draft2/hazard_firstbirth.tex
  - $OUT/fig/hazard_firstbirth_age.pdf
  - $OUT/fig/hazard_firstbirth_age.csv
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
capture mkdir "$OUT/fig"

*--------------------------------------------------------------*
* 1. Load data                                                 *
*--------------------------------------------------------------*
use "$OUT/dhs_with_shs_enrollment_exposure.dta", clear

*--------------------------------------------------------------*
* 2. Required variable names                                   *
*--------------------------------------------------------------*
local exp      "shs_per_1000_g10"
local wt       "w"
local yearvar  "survey_year"
local agevar   "age"
local afbvar   "age_first_birth"

* Full individual controls
local controls_full ///
    "urban wealth_index rel_prot rel_inc rel_muslim rel_other eth_cebuano eth_ilocano eth_other"

*--------------------------------------------------------------*
* 3. Verify required variables                                 *
*--------------------------------------------------------------*
foreach v in `exp' `wt' `yearvar' `agevar' `afbvar' prov_key {
    capture confirm variable `v'
    if _rc {
        di as error "Required variable `v' not found."
        exit 198
    }
}

* Province FE
capture confirm variable prov_fe
if _rc {
    encode prov_key, gen(prov_fe)
}
label var prov_fe "Province FE id"

* Cohort / birth year
capture confirm variable birth_year
if _rc {
    gen birth_year = `yearvar' - `agevar' if !missing(`yearvar', `agevar')
}
capture confirm variable cohort
if _rc {
    gen cohort = birth_year
}

* Treatment × exposure
gen treated_true = (cohort >= 2000)
gen treated_shs  = treated_true * `exp'

*--------------------------------------------------------------*
* 4. Define hazard age window                                  *
*--------------------------------------------------------------*
local min_age 12
local max_age 49

* Core sample restrictions
drop if missing(`agevar', cohort, prov_fe, `yearvar', `exp', `wt')
keep if `agevar' >= `min_age'

* Risk-set entry: childless at min_age
drop if !missing(`afbvar') & `afbvar' < `min_age'

*--------------------------------------------------------------*
* 5. Build person–year panel                                   *
*--------------------------------------------------------------*
gen long woman_id = _n

gen byte max_age_i = cond(`agevar' > `max_age', `max_age', `agevar')
drop if max_age_i < `min_age' | missing(max_age_i)

gen int n_ages = max_age_i - (`min_age' - 1)
expand n_ages

bysort woman_id: gen int age_at = `min_age' - 1 + _n
assert inrange(age_at, `min_age', `max_age')

* Hazard outcome
gen byte first_birth = 0
replace first_birth = 1 if !missing(`afbvar') & (`afbvar' == age_at)

* Drop ages after first birth
bysort woman_id (age_at): gen byte ever = sum(first_birth)
drop if ever >= 1 & first_birth == 0
drop ever

label var age_at      "Age (person-year)"
label var first_birth "First birth at age a"

*--------------------------------------------------------------*
* 6. FE hazard LPM treatment effect                             *
*--------------------------------------------------------------*
capture which reghdfe
if _rc ssc install reghdfe, replace

quietly reghdfe first_birth treated_shs i.age_at `controls_full' ///
    [pw=`wt'], absorb(prov_fe cohort `yearvar') vce(cluster prov_fe)
estimates store m1

scalar N1  = e(N)
scalar R21 = e(r2)

local N1_str  : display %9.0fc N1
local R21_str : display %6.4f R21

* SHS × Post coefficient
tempname b se p
scalar `b'  = _b[treated_shs]
scalar `se' = _se[treated_shs]
scalar `p'  = 2*ttail(e(df_r), abs(`b'/`se'))

local star ""
if (`p' < 0.01)      local star "***"
else if (`p' < 0.05) local star "**"
else if (`p' < 0.10) local star "*"

local bcell_1  : display %7.4f `b'
local secell_1 : display %7.4f `se'
local bcell_1 "`bcell_1'`star'"
local secell_1 "(`secell_1')"

*--------------------------------------------------------------*
* 7. Empirical hazard-by-age (levels)                           *
*--------------------------------------------------------------*
preserve
    keep if inrange(age_at, 13, 48)

    gen double __wy = `wt' * first_birth
    gen double __w2 = `wt'^2

    collapse (sum) sw=`wt' (sum) sy=__wy (sum) sw2=__w2, by(age_at)

    gen double hazard = sy / sw
    gen double n_eff  = (sw^2) / sw2
    gen double se_h   = sqrt(hazard*(1-hazard)/n_eff)

    gen double ci_low  = max(hazard - 1.96*se_h, 0)
    gen double ci_high = min(hazard + 1.96*se_h, 1)

    tempfile haz_age
    save `haz_age', replace
    export delimited using "$OUT/fig/hazard_firstbirth_age.csv", replace
restore

*--------------------------------------------------------------*
* 8. LaTeX table                                               *
*--------------------------------------------------------------*
use `haz_age', clear
sort age_at

capture file close fh
file open fh using "$TABLE_D2/hazard_firstbirth.tex", write replace

file write fh "\begin{table}[htbp]" _n
file write fh "\centering" _n
file write fh "\footnotesize" _n
file write fh "\caption{Discrete-time hazard model for age at first birth (linear probability)}" _n
file write fh "\label{tab:hazard_firstbirth}" _n
file write fh "\begin{tabular}{@{}lc@{}}" _n
file write fh "\toprule" _n
file write fh " & (1) Full controls \\\\" _n
file write fh "\midrule" _n

file write fh "\textit{Variables} \\\\" _n
file write fh "SHS$\times$Post & `bcell_1' \\\\" _n
file write fh "               & `secell_1' \\\\" _n
file write fh "\addlinespace[3pt]" _n

file write fh "\textit{Age-specific annual probabilities} \\\\" _n

quietly count
local K = r(N)

forvalues i=1/`K' {
    local a  = age_at[`i']
    local hh = hazard[`i']
    local ss = se_h[`i']

    local hhstr : display %7.4f `hh'
    local ssstr : display %7.4f `ss'

    file write fh "Age `a' & `hhstr' \\\\" _n
    file write fh "       & (`ssstr') \\\\" _n
}

file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Fit statistics} \\\\" _n
file write fh "Number of observations & `N1_str' \\\\" _n
file write fh "$R^2$                 & `R21_str' \\\\" _n

file write fh "\bottomrule" _n
file write fh ///
"\multicolumn{2}{p{0.95\\linewidth}}{\footnotesize Standard errors in parentheses are clustered at the province level for the SHS$\times$Post coefficient. The dependent variable is an indicator for having a first birth at age $a$. The person--year sample includes one observation per woman--age from `min_age' to 49 (or interview age, whichever is smaller), excludes ages after first birth, and omits women who gave birth before age `min_age'. The model includes province, cohort, survey-year, and single-year age fixed effects and is weighted using DHS sampling weights.} \\\\" _n

file write fh "\end{tabular}" _n
file write fh "\end{table}" _n
file close fh

*--------------------------------------------------------------*
* 9. Plot: hazard by age                                       *
*--------------------------------------------------------------*
twoway ///
    (rarea ci_high ci_low age_at, sort) ///
    (line hazard age_at, sort), ///
    xlabel(13(2)49) ///
    xtitle("Age") ///
    ytitle("Annual probability of first birth") ///
    title("Discrete-time hazard of first birth by age") ///
    legend(off) ///
    name(hazard_firstbirth_age, replace)

graph export "$OUT/fig/hazard_firstbirth_age.pdf", replace

*========================= END OF FILE ========================*
