/*===============================================================
Project: K–12 Schooling and Fertility
File:    10_robustness_trend_absorbing.do

Course:  ECON421 — Education and Human Capital in Developing Economies
Author:  Erika Salvador '28 (esalvador28@amherst.edu)

Purpose:
  Trend-absorbing robustness checks for the main DiD estimates using
  continuous SHS exposure:
    y = β0·Treated + β1·SHS + β2·(Treated × SHS) + FE + ε

  Outcomes:
    - age_first_birth
    - birth_by18
    - birth_by20

  All specifications use the FULL individual controls:
    urban, wealth_index, religion indicators, ethnicity indicators

  Robustness specifications:
    (1) Baseline FE: province, cohort, survey-year
    (2) + Province-specific cohort trends
    (3) Region × cohort fixed effects
    (4) Province × survey-year fixed effects
    (5) Baseline FE + DHS province-year fertility controls

Inputs:
  D:/ECON421/Results/output/dhs_with_shs_enrollment_exposure.dta
  D:/ECON421/Results/output/province_fertility_controls_dhs.dta

Outputs:
  D:/ECON421/Results/output/table/draft2/main_did_timing_trendrobust.tex
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

*------------------ Region FE (numeric) -----------------------*
capture confirm variable region_fe
if _rc {
    * If numeric region already exists, just copy it
    capture confirm variable region
    if _rc == 0 {
        gen region_fe = region
    }
    else {
        * Otherwise, encode region_name (string from DHS GPS)
        capture confirm variable region_name
        if _rc {
            di as error "No region, region_fe, or region_name variable found. Please create a region FE variable."
            exit 198
        }
        encode region_name, gen(region_fe)
    }
}
label var region_fe "Region FE id"

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
* 4. Merge province-level fertility controls
*------------------------------*
preserve
tempfile base
save `base', replace

use "$OUT/province_fertility_controls_dhs.dta", clear
isid prov_fe survey_year

tempfile fertctrl
save `fertctrl', replace

restore
merge m:1 prov_fe survey_year using `fertctrl', keep(match master) nogen

* fertility controls used in spec 5
local fertcontrols "pf_ceb_40_49 pf_birthby18 pf_birthby25"

*------------------------------*
* 5. Controls & FE
*------------------------------*
local controls_full "urban wealth_index rel_prot rel_inc rel_muslim rel_other eth_cebuano eth_ilocano eth_other"

local provfe   "prov_fe"
local wt       "w"
local cohortfe "cohort"
local year     "survey_year"

capture which reghdfe
if _rc ssc install reghdfe, replace

* Helper interactions / groups for robustness specs
capture drop region_cohort prov_year
egen region_cohort = group(region_fe cohort)
egen prov_year     = group(prov_fe survey_year)

*------------------------------*
* 6. Define outcomes and specs
*------------------------------*

local out1 "age_first_birth"
local out2 "birth_by18"
local out3 "birth_by20"
local out_all "`out1' `out2' `out3'"

local specs "spec1 spec2 spec3 spec4 spec5"

*------------------------------*
* 7. Run robustness regressions
*------------------------------*

foreach s of local specs {
    foreach y of local out_all {

        if "`s'" == "spec1" {                     // Baseline FE
            local absorb "`provfe' `cohortfe' `year'"
            local ctrls  "`controls_full'"
            local addvars ""
        }
        else if "`s'" == "spec2" {                // + prov-specific cohort trend
            local absorb "`provfe' `cohortfe' `year'"
            local ctrls  "`controls_full'"
            local addvars "c.cohort#i.`provfe'"
        }
        else if "`s'" == "spec3" {                // region×cohort FE
            local absorb "`provfe' region_cohort `year'"
            local ctrls  "`controls_full'"
            local addvars ""
        }
        else if "`s'" == "spec4" {                // prov×survey-year FE
            local absorb "prov_year `cohortfe'"
            local ctrls  "`controls_full'"
            local addvars ""
        }
        else if "`s'" == "spec5" {                // baseline FE + DHS fertility controls
            local absorb "`provfe' `cohortfe' `year'"
            local ctrls  "`controls_full' `fertcontrols'"
            local addvars ""
        }

        quietly reghdfe `y' treated shs treated_shs ///
            `ctrls' `addvars' [pw = `wt'], ///
            absorb(`absorb') vce(cluster `provfe')

        capture scalar b  = _b[treated_shs]
        capture scalar se = _se[treated_shs]

        if _rc {
            local cellb_`s'_`y'  "--"
            local cellse_`s'_`y' ""
            local N_`s'_`y'      ""
            local R2_`s'_`y'     ""
        }
        else {
            scalar p = 2*ttail(e(df_r), abs(b/se))
            local star ""
            if (p<0.01)      local star "***"
            else if (p<0.05) local star "**"
            else if (p<0.10) local star "*"

            local bstr  : display %6.3f b
            local sestr : display %6.3f se

            local cellb_`s'_`y'  "`bstr'`star'"
            local cellse_`s'_`y' "(`sestr')"

            local N_`s'_`y'   : display %9.0fc e(N)
            local R2_`s'_`y'  : display %6.3f  e(r2)
        }
    }
}

*------------------------------*
* 8. Yes/No patterns for robustness structure
*------------------------------*

foreach s of local specs {
    if "`s'" == "spec1" {
        local trend_pc_`s'   "No"
        local fe_rc_`s'      "No"
        local fe_py_`s'      "No"
        local dhs_fert_`s'   "No"
    }
    else if "`s'" == "spec2" {
        local trend_pc_`s'   "Yes"
        local fe_rc_`s'      "No"
        local fe_py_`s'      "No"
        local dhs_fert_`s'   "No"
    }
    else if "`s'" == "spec3" {
        local trend_pc_`s'   "No"
        local fe_rc_`s'      "Yes"
        local fe_py_`s'      "No"
        local dhs_fert_`s'   "No"
    }
    else if "`s'" == "spec4" {
        local trend_pc_`s'   "No"
        local fe_rc_`s'      "No"
        local fe_py_`s'      "Yes"
        local dhs_fert_`s'   "No"
    }
    else if "`s'" == "spec5" {
        local trend_pc_`s'   "No"
        local fe_rc_`s'      "No"
        local fe_py_`s'      "No"
        local dhs_fert_`s'   "Yes"
    }
}

*------------------------------*
* 9. Write LaTeX table (stacked panels)
*------------------------------*

capture file close fh
file open fh using "$TABLE_D2/main_did_timing_trendrobust.tex", write replace

file write fh "\begin{table}[htbp]" _n
file write fh "\centering" _n
file write fh "\footnotesize" _n
file write fh "\caption{Difference-in-differences estimates of SHS exposure on fertility timing outcomes: trend-absorbing robustness checks}" _n
file write fh "\label{tab:main_did_timing_trendrobust}" _n
file write fh "\begin{tabular}{@{}lccccc@{}}" _n
file write fh "\toprule" _n

*----------------- PANEL A: Age at first birth ----------------*
local y "`out1'"
file write fh " & \multicolumn{5}{c}{\textbf{Panel A: Age at first birth}}\\\\" _n
file write fh "\cmidrule(lr){2-6}" _n
file write fh "Model: & 1$^\dagger$ & 2 & 3 & 4 & 5 \\\\" _n
file write fh "\midrule" _n

file write fh "\textit{Variables} \\\\" _n
file write fh "SHS$\times$Post" ///
    " & `cellb_spec1_`y'' & `cellb_spec2_`y'' & `cellb_spec3_`y'' & `cellb_spec4_`y'' & `cellb_spec5_`y'' \\\\" _n
file write fh " " ///
    " & `cellse_spec1_`y'' & `cellse_spec2_`y'' & `cellse_spec3_`y'' & `cellse_spec4_`y'' & `cellse_spec5_`y'' \\\\" _n

file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Trend-absorbing and additional controls} \\\\" _n

file write fh "Province-specific cohort trend" ///
    " & `trend_pc_spec1' & `trend_pc_spec2' & `trend_pc_spec3' & `trend_pc_spec4' & `trend_pc_spec5' \\\\" _n
file write fh "Region$\times$cohort FE" ///
    " & `fe_rc_spec1' & `fe_rc_spec2' & `fe_rc_spec3' & `fe_rc_spec4' & `fe_rc_spec5' \\\\" _n
file write fh "Province$\times$survey-year FE" ///
    " & `fe_py_spec1' & `fe_py_spec2' & `fe_py_spec3' & `fe_py_spec4' & `fe_py_spec5' \\\\" _n
file write fh "Province-level fertility controls (DHS)" ///
    " & `dhs_fert_spec1' & `dhs_fert_spec2' & `dhs_fert_spec3' & `dhs_fert_spec4' & `dhs_fert_spec5' \\\\" _n

file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Fit statistics} \\\\" _n
file write fh "Number of observations" ///
    " & `N_spec1_`y'' & `N_spec2_`y'' & `N_spec3_`y'' & `N_spec4_`y'' & `N_spec5_`y'' \\\\" _n
file write fh "R-squared" ///
    " & `R2_spec1_`y'' & `R2_spec2_`y'' & `R2_spec3_`y'' & `R2_spec4_`y'' & `R2_spec5_`y'' \\\\" _n

file write fh "\midrule[0.8pt]" _n

*----------------- PANEL B: Birth by 18 -----------------------*
local y "`out2'"
file write fh " & \multicolumn{5}{c}{\textbf{Panel B: Had a birth by age 18}}\\\\" _n
file write fh "\cmidrule(lr){2-6}" _n
file write fh "Model: & 6$^\dagger$ & 7 & 8 & 9 & 10 \\\\" _n
file write fh "\midrule" _n

file write fh "\textit{Variables} \\\\" _n
file write fh "SHS$\times$Post" ///
    " & `cellb_spec1_`y'' & `cellb_spec2_`y'' & `cellb_spec3_`y'' & `cellb_spec4_`y'' & `cellb_spec5_`y'' \\\\" _n
file write fh " " ///
    " & `cellse_spec1_`y'' & `cellse_spec2_`y'' & `cellse_spec3_`y'' & `cellse_spec4_`y'' & `cellse_spec5_`y'' \\\\" _n

file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Trend-absorbing and additional controls} \\\\" _n

file write fh "Province-specific cohort trend" ///
    " & `trend_pc_spec1' & `trend_pc_spec2' & `trend_pc_spec3' & `trend_pc_spec4' & `trend_pc_spec5' \\\\" _n
file write fh "Region$\times$cohort FE" ///
    " & `fe_rc_spec1' & `fe_rc_spec2' & `fe_rc_spec3' & `fe_rc_spec4' & `fe_rc_spec5' \\\\" _n
file write fh "Province$\times$survey-year FE" ///
    " & `fe_py_spec1' & `fe_py_spec2' & `fe_py_spec3' & `fe_py_spec4' & `fe_py_spec5' \\\\" _n
file write fh "Province-level fertility controls (DHS)" ///
    " & `dhs_fert_spec1' & `dhs_fert_spec2' & `dhs_fert_spec3' & `dhs_fert_spec4' & `dhs_fert_spec5' \\\\" _n

file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Fit statistics} \\\\" _n
file write fh "Number of observations" ///
    " & `N_spec1_`y'' & `N_spec2_`y'' & `N_spec3_`y'' & `N_spec4_`y'' & `N_spec5_`y'' \\\\" _n
file write fh "R-squared" ///
    " & `R2_spec1_`y'' & `R2_spec2_`y'' & `R2_spec3_`y'' & `R2_spec4_`y'' & `R2_spec5_`y'' \\\\" _n

file write fh "\midrule[0.8pt]" _n

*----------------- PANEL C: Birth by 20 -----------------------*
local y "`out3'"
file write fh " & \multicolumn{5}{c}{\textbf{Panel C: Had a birth by age 20}}\\\\" _n
file write fh "\cmidrule(lr){2-6}" _n
file write fh "Model: & 11$^\dagger$ & 12 & 13 & 14 & 15 \\\\" _n
file write fh "\midrule" _n

file write fh "\textit{Variables} \\\\" _n
file write fh "SHS$\times$Post" ///
    " & `cellb_spec1_`y'' & `cellb_spec2_`y'' & `cellb_spec3_`y'' & `cellb_spec4_`y'' & `cellb_spec5_`y'' \\\\" _n
file write fh " " ///
    " & `cellse_spec1_`y'' & `cellse_spec2_`y'' & `cellse_spec3_`y'' & `cellse_spec4_`y'' & `cellse_spec5_`y'' \\\\" _n

file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Trend-absorbing and additional controls} \\\\" _n

file write fh "Province-specific cohort trend" ///
    " & `trend_pc_spec1' & `trend_pc_spec2' & `trend_pc_spec3' & `trend_pc_spec4' & `trend_pc_spec5' \\\\" _n
file write fh "Region$\times$cohort FE" ///
    " & `fe_rc_spec1' & `fe_rc_spec2' & `fe_rc_spec3' & `fe_rc_spec4' & `fe_rc_spec5' \\\\" _n
file write fh "Province$\times$survey-year FE" ///
    " & `fe_py_spec1' & `fe_py_spec2' & `fe_py_spec3' & `fe_py_spec4' & `fe_py_spec5' \\\\" _n
file write fh "Province-level fertility controls (DHS)" ///
    " & `dhs_fert_spec1' & `dhs_fert_spec2' & `dhs_fert_spec3' & `dhs_fert_spec4' & `dhs_fert_spec5' \\\\" _n

file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Fit statistics} \\\\" _n
file write fh "Number of observations" ///
    " & `N_spec1_`y'' & `N_spec2_`y'' & `N_spec3_`y'' & `N_spec4_`y'' & `N_spec5_`y'' \\\\" _n
file write fh "R-squared" ///
    " & `R2_spec1_`y'' & `R2_spec2_`y'' & `R2_spec3_`y'' & `R2_spec4_`y'' & `R2_spec5_`y'' \\\\" _n

file write fh "\bottomrule" _n

file write fh "\multicolumn{6}{p{0.90\linewidth}}{\footnotesize Standard errors in parentheses, clustered at the province level. All specifications include the same baseline individual controls (urban residence, household wealth quintile dummies, and religion and ethnicity) and the main fixed effects: province, birth-cohort, and survey-year. Robustness models vary the trend-absorbing structure or add province-level fertility controls constructed from DHS microdata as described in Appendix~\\ref{app:fertilitycontrols}. $^\dagger$ denotes the preferred baseline specification in each panel. *, **, *** denote significance at the 10\%, 5\%, and 1\% levels, respectively.} \\\\" _n

file write fh "\end{tabular}" _n
file write fh "\end{table}" _n

file close fh
