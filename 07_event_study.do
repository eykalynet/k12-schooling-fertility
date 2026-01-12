/*===============================================================
Project: K–12 Schooling and Fertility
File:    07_eventstudy_fertility_timing.do

Course:  ECON421 — Education and Human Capital in Developing Economies
Author:  Erika Salvador '28 (esalvador28@amherst.edu)

Purpose:
  Cohort-based event-study of province-level SHS exposure effects on
  primary fertility-timing outcomes (birth_by18, birth_by20, age_first_birth).

Inputs:
  D:/ECON421/Results/output/dhs_with_shs_enrollment_exposure.dta

Outputs:
  D:/ECON421/Results/output/table/draft2/eventstudy_fertility_timing.tex
===============================================================*/

version 17
clear all
set more off
set maxvar 32767

*--------------------------------------------------------------*
* 0. Paths & data
*--------------------------------------------------------------*
global ROOT  "D:/ECON421"
global DATA  "$ROOT/Results"
global OUT   "$ROOT/Results/output"
global TABLE "$OUT/table/draft2/"

capture mkdir "$OUT"
capture mkdir "$TABLE"

use "$OUT/dhs_with_shs_enrollment_exposure.dta", clear


*------------------------------*
* 1. Province FE and cohort variables
*------------------------------*

* Province FE: encode prov_key (string) to numeric if needed
capture confirm variable prov_fe
if _rc {
    capture confirm variable prov_key
    if _rc {
        di as error "Variable prov_key not found; cannot create province FE."
        exit 198
    }
    encode prov_key, gen(prov_fe)
}
label var prov_fe "Province FE id"

* (Re)construct birth year and relative cohort bins
capture drop birth_year rel_cohort rel_bin rel_bin2

* Birth year (from survey_year and age)
capture confirm variable birth_year
if _rc {
    capture confirm variable age
    if _rc {
        di as error "Variables birth_year and age not found; cannot construct birth_year."
        exit 198
    }
    gen birth_year = survey_year - age
}
label var birth_year "Birth year (survey_year - age)"

* Relative cohort distance from first treated (2000)
gen rel_cohort = birth_year - 2000 if !missing(birth_year)
label var rel_cohort "Cohort distance from first treated (2000)"

* Bin relative cohorts into [-5, 5]
gen rel_bin = rel_cohort
replace rel_bin = -5 if rel_cohort <= -5 & !missing(rel_cohort)
replace rel_bin =  5 if rel_cohort >=  5 & !missing(rel_cohort)

label define relbin_lab ///
    -5 "<= -5" ///
    -4 "-4" ///
    -3 "-3" ///
    -2 "-2" ///
    -1 "-1 (last pre)" ///
     0 "0 (first treated)" ///
     1 "1" ///
     2 "2" ///
     3 "3" ///
     4 "4" ///
     5 ">= 5", replace
label values rel_bin relbin_lab

* Shift to start at 0 for interactions (0 = <= -5, omitted bin)
gen rel_bin2 = rel_bin + 5
label var rel_bin2 "Shifted cohort distance (0 = <= -5)"

label define relbin2_lab ///
     0 "<= -5" ///
     1 "-4" ///
     2 "-3" ///
     3 "-2" ///
     4 "-1 (last pre)" ///
     5 "0 (first treated)" ///
     6 "1" ///
     7 "2" ///
     8 "3" ///
     9 "4" ///
    10 ">= 5", replace
label values rel_bin2 relbin2_lab


*------------------------------*
* 2. Locals
*------------------------------*

* Primary outcomes only (fertility timing)
local ylist ///
    birth_by18 birth_by20 age_first_birth

* Key vars
local exp     shs_per_1000_g10
local provfe  prov_fe
local cohort  birth_year
local year    survey_year
local wt      w

* Baseline individual controls (do NOT include educ_years, hh size)
* Base categories: Catholic, Tagalog
local ctrls ///
    urban wealth_index ///
    rel_prot rel_inc rel_muslim rel_other ///
    eth_cebuano eth_ilocano eth_other


*------------------------------*
* 3. Install packages (if needed)
*------------------------------*

capture which reghdfe
if _rc ssc install reghdfe, replace

capture which esttab
if _rc ssc install estout, replace


*------------------------------*
* 4. Event-study regressions (continuous exposure)
*------------------------------*
* Spec: i.rel_bin2#c.shs_per_1000_g10 + controls
*   - rel_bin2 bins as above, base = 0 (<= -5)
*   - coefficient for bin k is the effect at cohort-bin k
* FE: province, birth_year, survey_year
* Clustered at province
* Pre-trend test: bins -4,-3,-2,-1 (rel_bin2 = 1,2,3,4)
* Post-treatment test: bins 0,1,2,3,4,≥5 (rel_bin2 = 5,6,7,8,9,10)

eststo clear

foreach y of local ylist {

    di as txt "==========================================================="
    di as txt "  EVENT STUDY FOR OUTCOME: `y'"
    di as txt "==========================================================="

    preserve
        * Drop obs with missing outcome, exposure, FE vars, or rel_bin2
        keep if !missing(`y', `exp', `provfe', `cohort', `year', `wt', rel_bin2)

        * Event-study regression: continuous exposure × cohort bins + controls
        reghdfe `y' i.rel_bin2#c.`exp' `ctrls' ///
            [pw = `wt'], ///
            absorb(`provfe' `cohort' `year') ///
            vce(cluster `provfe')

        *------------------------------------------------------*
        * Pre-trend F-test: bins -4,-3,-2,-1
        *   (rel_bin2 = 1,2,3,4)
        *------------------------------------------------------*
        capture noisily test ///
            1.rel_bin2#c.`exp' ///
            2.rel_bin2#c.`exp' ///
            3.rel_bin2#c.`exp' ///
            4.rel_bin2#c.`exp'

        if _rc {
            scalar p_pre = .
        }
        else {
            scalar p_pre = r(p)
        }

        *------------------------------------------------------*
        * Post-treatment F-test: bins 0,1,2,3,4,≥5
        *   (rel_bin2 = 5,6,7,8,9,10)
        *------------------------------------------------------*
        capture noisily test ///
            5.rel_bin2#c.`exp' ///
            6.rel_bin2#c.`exp' ///
            7.rel_bin2#c.`exp' ///
            8.rel_bin2#c.`exp' ///
            9.rel_bin2#c.`exp' ///
           10.rel_bin2#c.`exp'

        if _rc {
            scalar p_post = .
        }
        else {
            scalar p_post = r(p)
        }

        *------------------------------------------------------*
        * Pre/post observation counts
        *   Pre: rel_bin <= -1   (including the ≤-5 base bin)
        *   Post: rel_bin >= 0
        *   (Same sample restrictions as regression)
        *------------------------------------------------------*
        quietly count if !missing(`y', `exp', `provfe', `cohort', `year', `wt', rel_bin, rel_bin2) ///
            & rel_bin <= -1
        scalar N_pre = r(N)

        quietly count if !missing(`y', `exp', `provfe', `cohort', `year', `wt', rel_bin, rel_bin2) ///
            & rel_bin >= 0
        scalar N_post = r(N)

        * Store estimates and add stats
        estimates store EST_`y'
        estadd scalar p_pretrend  = p_pre,  replace
        estadd scalar p_posttrend = p_post, replace
        estadd scalar N_pre       = N_pre,  replace
        estadd scalar N_post      = N_post, replace

    restore
}


*------------------------------*
* 5. LaTeX table: Fertility timing (primary outcomes)
*------------------------------*
* Rows = cohort bins -5..5, columns = outcomes
* Column order: (1) Age at first birth, (2) Birth by 18, (3) Birth by 20

esttab ///
    EST_age_first_birth ///
    EST_birth_by18 ///
    EST_birth_by20 ///
    using "$TABLE/eventstudy_fertility_timing.tex", ///
    replace ///
    keep(*.rel_bin2#c.shs_per_1000_g10) ///
    coeflabels( ///
        1.rel_bin2#c.shs_per_1000_g10  "-4" ///
        2.rel_bin2#c.shs_per_1000_g10  "-3" ///
        3.rel_bin2#c.shs_per_1000_g10  "-2" ///
        4.rel_bin2#c.shs_per_1000_g10  "-1 (last pre)" ///
        5.rel_bin2#c.shs_per_1000_g10  "0 (first treated)" ///
        6.rel_bin2#c.shs_per_1000_g10  "1" ///
        7.rel_bin2#c.shs_per_1000_g10  "2" ///
        8.rel_bin2#c.shs_per_1000_g10  "3" ///
        9.rel_bin2#c.shs_per_1000_g10  "4" ///
       10.rel_bin2#c.shs_per_1000_g10  ">= 5" ///
    ) ///
    mtitles( ///
        "Age at first birth" ///
        "Birth by 18" ///
        "Birth by 20" ///
    ) ///
    stats(p_pretrend p_posttrend N_pre N_post N, ///
          labels("Pre-trend F-test p-value" ///
                 "Post-treatment F-test p-value" ///
                 "Pre-treatment observations" ///
                 "Post-treatment observations" ///
                 "Total observations") ///
          fmt(3 3 0 0 0)) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    label booktabs nonotes
