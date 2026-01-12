/*===============================================================
Project: K–12 Schooling and Fertility
File:    11_robustness_windows_highshs.do

Course:  ECON421 — Education and Human Capital in Developing Economies
Author:  Erika Salvador '28 (esalvador28@amherst.edu)

Purpose:
  Second set of robustness checks for fertility-timing DiD.

  Check 1 (Cohort-window robustness):
    - Baseline full sample
    - Restrict to cohorts within ±2 of the 2000 cutoff
    - Restrict to cohorts within ±3 of the 2000 cutoff

  Check 2 (Binary "high exposure" provinces):
    - Replace continuous SHS exposure with indicators for provinces at/above:
        • median
        • 75th percentile
        • 90th percentile
    - Estimate DiD using HighExposure × Post interaction.

Inputs:
  D:/ECON421/Results/output/dhs_with_shs_enrollment_exposure.dta

Outputs:
  D:/ECON421/Results/output/table/draft2/main_did_timing_bandwidth.tex
  D:/ECON421/Results/output/table/draft2/main_did_timing_highshs.tex
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
    capture confirm variable region
    if _rc == 0 {
        gen region_fe = region
    }
    else {
        capture confirm variable region_name
        if _rc {
            di as error "No region, region_fe, or region_name variable found."
            exit 198
        }
        encode region_name, gen(region_fe)
    }
}
label var region_fe "Region FE id"

*------------------------------*
* 2. Treatment, exposure, controls, FE
*------------------------------*
local exp shs_per_1000_g10
drop if missing(`exp')

capture confirm variable birth_year
if _rc {
    gen birth_year = survey_year - age if !missing(survey_year, age)
}
capture confirm variable cohort
if _rc {
    gen cohort = birth_year
}

gen treated_true = (cohort >= 2000)
gen post_true    = treated_true

capture drop treated shs treated_shs
gen treated     = treated_true
gen shs         = `exp'
gen treated_shs = treated * shs

* Full individual controls (same as main timing DiD)
local controls_full ///
    "urban wealth_index rel_prot rel_inc rel_muslim rel_other eth_cebuano eth_ilocano eth_other"

local provfe   "prov_fe"
local wt       "w"
local cohortfe "cohort"
local year     "survey_year"

capture which reghdfe
if _rc ssc install reghdfe, replace

local absorb_base "`provfe' `cohortfe' `year'"

local out_age "age_first_birth"
local out_b18 "birth_by18"
local out_b20 "birth_by20"

*==============================================================*
* CHECK 1: Cohort-window robustness (baseline, ±2, ±3)
*==============================================================*

local cutoff = 2000
local low2   = `cutoff' - 2
local high2  = `cutoff' + 2
local low3   = `cutoff' - 3
local high3  = `cutoff' + 3

local samples "full bw2 bw3"

foreach y in `out_age' `out_b18' `out_b20' {

    foreach s of local samples {

        if "`s'" == "full" {
            local cond "if !missing(treated_shs, `y')"
        }
        else if "`s'" == "bw2" {
            local cond "if inrange(cohort, `low2', `high2') & !missing(treated_shs, `y')"
        }
        else if "`s'" == "bw3" {
            local cond "if inrange(cohort, `low3', `high3') & !missing(treated_shs, `y')"
        }

        quietly reghdfe `y' treated shs treated_shs ///
            `controls_full' [pw = `wt'] `cond', ///
            absorb(`absorb_base') vce(cluster `provfe')

        scalar b  = _b[treated_shs]
        scalar se = _se[treated_shs]
        scalar p  = 2*ttail(e(df_r), abs(b/se))
        scalar N  = e(N)
        scalar R2 = e(r2)

        local star ""
        if (p<0.01)      local star "***"
        else if (p<0.05) local star "**"
        else if (p<0.10) local star "*"

        local bstr  : display %6.3f b
        local sestr : display %6.3f se

        local cellb_`s'_`y'  "`bstr'`star'"
        local cellse_`s'_`y' "(`sestr')"

        local N_`s'_`y'  : display %9.0fc N
        local R2_`s'_`y' : display %6.3f R2
    }
}

*------------------ LaTeX table: cohort windows ------------------*
capture file close fh
file open fh using "$TABLE_D2/main_did_timing_bandwidth.tex", write replace

file write fh "\begin{table}[htbp]" _n
file write fh "\centering" _n
file write fh "\footnotesize" _n
file write fh "\caption{Difference-in-differences estimates of SHS exposure on fertility timing outcomes: robustness to comparison cohorts}" _n
file write fh "\label{tab:main_did_timing_bandwidth}" _n
file write fh "\begin{tabular}{@{}l*{9}{c}@{}}" _n
file write fh "\toprule" _n

file write fh " & \multicolumn{3}{c}{Age at first birth} & \multicolumn{3}{c}{Had a birth by age 18} & \multicolumn{3}{c}{Had a birth by age 20} \\\\" _n
file write fh " & (1) Baseline & (2) $\pm2$ cohorts & (3) $\pm3$ cohorts & (4) Baseline & (5) $\pm2$ cohorts & (6) $\pm3$ cohorts & (7) Baseline & (8) $\pm2$ cohorts & (9) $\pm3$ cohorts \\\\" _n
file write fh "\midrule" _n

file write fh "\textit{Variables} \\\\" _n
file write fh "SHS$\times$Post" ///
    " & `cellb_full_`out_age'' & `cellb_bw2_`out_age'' & `cellb_bw3_`out_age''" ///
    " & `cellb_full_`out_b18'' & `cellb_bw2_`out_b18'' & `cellb_bw3_`out_b18''" ///
    " & `cellb_full_`out_b20'' & `cellb_bw2_`out_b20'' & `cellb_bw3_`out_b20'' \\\\" _n

file write fh " " ///
    " & `cellse_full_`out_age'' & `cellse_bw2_`out_age'' & `cellse_bw3_`out_age''" ///
    " & `cellse_full_`out_b18'' & `cellse_bw2_`out_b18'' & `cellse_bw3_`out_b18''" ///
    " & `cellse_full_`out_b20'' & `cellse_bw2_`out_b20'' & `cellse_bw3_`out_b20'' \\\\" _n

file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Fit statistics} \\\\" _n

file write fh "Number of observations" ///
    " & `N_full_`out_age'' & `N_bw2_`out_age'' & `N_bw3_`out_age''" ///
    " & `N_full_`out_b18'' & `N_bw2_`out_b18'' & `N_bw3_`out_b18''" ///
    " & `N_full_`out_b20'' & `N_bw2_`out_b20'' & `N_bw3_`out_b20'' \\\\" _n

file write fh "R-squared" ///
    " & `R2_full_`out_age'' & `R2_bw2_`out_age'' & `R2_bw3_`out_age''" ///
    " & `R2_full_`out_b18'' & `R2_bw2_`out_b18'' & `R2_bw3_`out_b18''" ///
    " & `R2_full_`out_b20'' & `R2_bw2_`out_b20'' & `R2_bw3_`out_b20'' \\\\" _n

file write fh "\bottomrule" _n
file write fh ///
"\multicolumn{10}{p{0.96\linewidth}}{\footnotesize Standard errors in parentheses, clustered at the province level. All specifications include province, birth-cohort, and survey-year fixed effects and the full set of individual controls (urban residence, household wealth quintile dummies, and indicators for religion and ethnicity). Baseline models use the full estimation sample. $\pm2$-cohort models restrict the sample to cohorts `low2'--`high2'; $\pm3$-cohort models restrict the sample to cohorts `low3'--`high3' around the SHS eligibility cutoff. *, **, *** denote significance at the 10\%, 5\%, and 1\% levels, respectively.} \\\\" _n

file write fh "\end{tabular}" _n
file write fh "\end{table}" _n
file close fh

*==============================================================*
* CHECK 2: Binary high-exposure provinces (median / p75 / p90)
*==============================================================*

preserve

* Percentile cutoffs for SHS exposure (weighted)
_pctile shs_per_1000_g10 [pw = `wt'], p(50 75 90)
scalar p50 = r(r1)
scalar p75 = r(r2)
scalar p90 = r(r3)

gen high50 = (shs_per_1000_g10 >= p50) if !missing(shs_per_1000_g10)
gen high75 = (shs_per_1000_g10 >= p75) if !missing(shs_per_1000_g10)
gen high90 = (shs_per_1000_g10 >= p90) if !missing(shs_per_1000_g10)

foreach h in 50 75 90 {
    gen high`h'_post = high`h' * post_true
}

local cutlist "50 75 90"

foreach y in `out_age' `out_b18' `out_b20' {
    foreach c of local cutlist {

        quietly reghdfe `y' high`c' post_true high`c'_post ///
            `controls_full' [pw = `wt'], ///
            absorb(`absorb_base') vce(cluster `provfe')

        scalar b  = _b[high`c'_post]
        scalar se = _se[high`c'_post]
        scalar p  = 2*ttail(e(df_r), abs(b/se))
        scalar N  = e(N)
        scalar R2 = e(r2)

        local star ""
        if (p<0.01)      local star "***"
        else if (p<0.05) local star "**"
        else if (p<0.10) local star "*"

        local bstr  : display %6.3f b
        local sestr : display %6.3f se

        local cellb_cut`c'_`y'  "`bstr'`star'"
        local cellse_cut`c'_`y' "(`sestr')"

        local N_cut`c'_`y'  : display %9.0fc N
        local R2_cut`c'_`y' : display %6.3f R2
    }
}

*------------------ LaTeX table: high exposure ------------------*
capture file close fh
file open fh using "$TABLE_D2/main_did_timing_highshs.tex", write replace

file write fh "\begin{table}[htbp]" _n
file write fh "\centering" _n
file write fh "\footnotesize" _n
file write fh "\caption{Difference-in-differences estimates using binary high-exposure provinces}" _n
file write fh "\label{tab:main_did_timing_highshs}" _n
file write fh "\begin{tabular}{@{}lccc@{}}" _n
file write fh "\toprule" _n

*----------------- PANEL A: Age at first birth -----------------*
local y "`out_age'"
file write fh " & \multicolumn{3}{c}{\textbf{Panel A: Age at first birth}}\\\\ " _n
file write fh "\cmidrule(lr){2-4}" _n
file write fh "Model: & 1 & 2 & 3 \\\\" _n
file write fh "\midrule" _n

file write fh "\textit{Variables} \\\\" _n
file write fh "High exposure$\times$Post" ///
    " & `cellb_cut50_`y'' & `cellb_cut75_`y'' & `cellb_cut90_`y'' \\\\" _n
file write fh " " ///
    " & `cellse_cut50_`y'' & `cellse_cut75_`y'' & `cellse_cut90_`y'' \\\\" _n

file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Definition and fit} \\\\" _n
file write fh "High-exposure threshold" ///
    " & $\geq$ median & $\geq$ 75th percentile & $\geq$ 90th percentile \\\\" _n
file write fh "Number of observations" ///
    " & `N_cut50_`y'' & `N_cut75_`y'' & `N_cut90_`y'' \\\\" _n
file write fh "R-squared" ///
    " & `R2_cut50_`y'' & `R2_cut75_`y'' & `R2_cut90_`y'' \\\\" _n

file write fh "\midrule[0.8pt]" _n

*----------------- PANEL B: Birth by 18 ------------------------*
local y "`out_b18'"
file write fh " & \multicolumn{3}{c}{\textbf{Panel B: Had a birth by age 18}}\\\\ " _n
file write fh "\cmidrule(lr){2-4}" _n
file write fh "Model: & 4 & 5 & 6 \\\\" _n
file write fh "\midrule" _n

file write fh "\textit{Variables} \\\\" _n
file write fh "High exposure$\times$Post" ///
    " & `cellb_cut50_`y'' & `cellb_cut75_`y'' & `cellb_cut90_`y'' \\\\" _n
file write fh " " ///
    " & `cellse_cut50_`y'' & `cellse_cut75_`y'' & `cellse_cut90_`y'' \\\\" _n

file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Definition and fit} \\\\" _n
file write fh "High-exposure threshold" ///
    " & $\geq$ median & $\geq$ 75th percentile & $\geq$ 90th percentile \\\\" _n
file write fh "Number of observations" ///
    " & `N_cut50_`y'' & `N_cut75_`y'' & `N_cut90_`y'' \\\\" _n
file write fh "R-squared" ///
    " & `R2_cut50_`y'' & `R2_cut75_`y'' & `R2_cut90_`y'' \\\\" _n

file write fh "\midrule[0.8pt]" _n

*----------------- PANEL C: Birth by 20 ------------------------*
local y "`out_b20'"
file write fh " & \multicolumn{3}{c}{\textbf{Panel C: Had a birth by age 20}}\\\\ " _n
file write fh "\cmidrule(lr){2-4}" _n
file write fh "Model: & 7 & 8 & 9 \\\\" _n
file write fh "\midrule" _n

file write fh "\textit{Variables} \\\\" _n
file write fh "High exposure$\times$Post" ///
    " & `cellb_cut50_`y'' & `cellb_cut75_`y'' & `cellb_cut90_`y'' \\\\" _n
file write fh " " ///
    " & `cellse_cut50_`y'' & `cellse_cut75_`y'' & `cellse_cut90_`y'' \\\\" _n

file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Definition and fit} \\\\" _n
file write fh "High-exposure threshold" ///
    " & $\geq$ median & $\geq$ 75th percentile & $\geq$ 90th percentile \\\\" _n
file write fh "Number of observations" ///
    " & `N_cut50_`y'' & `N_cut75_`y'' & `N_cut90_`y'' \\\\" _n
file write fh "R-squared" ///
    " & `R2_cut50_`y'' & `R2_cut75_`y'' & `R2_cut90_`y'' \\\\" _n

file write fh "\bottomrule" _n
file write fh ///
"\multicolumn{4}{p{0.94\linewidth}}{\footnotesize Standard errors in parentheses, clustered at the province level. Each model replaces the continuous SHS exposure with a binary indicator for provinces at or above the median, 75th, or 90th percentile of the SHS schools-per-1{,}000 Grade 10 students distribution. All regressions include province, birth-cohort, and survey-year fixed effects and the same full set of individual controls (urban residence, household wealth quintile dummies, and indicators for religion and ethnicity). *, **, *** denote significance at the 10\%, 5\%, and 1\% levels, respectively.} \\\\" _n

file write fh "\end{tabular}" _n
file write fh "\end{table}" _n
file close fh

restore

*========================= END OF FILE ========================*
