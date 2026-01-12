/*===============================================================
Project: K–12 Schooling and Fertility
File:    13_robustness_trimming_regions.do

Course:  ECON421 — Education and Human Capital in Developing Economies
Author:  Erika Salvador '28 (esalvador28@amherst.edu)

Purpose:
  Robustness checks for fertility-timing DiD estimates:

    (1) Trimming extreme SHS exposure values
        - Baseline sample
        - Drop bottom 10% of SHS exposure
        - Drop top 10% of SHS exposure
        - Drop both bottom and top 10% (middle 80%)

    (2) Excluding influential regions
        - Baseline sample
        - Excluding National Capital Region (NCR)
        - Excluding BARMM (formerly ARMM)
        - Excluding both NCR and BARMM

Inputs:
  - $OUT/dhs_with_shs_enrollment_exposure.dta

Outputs:
  - $TABLE/draft2/main_did_timing_trim.tex       (Check 1: trimming)
  - $TABLE/draft2/main_did_timing_regions.tex    (Check 2: NCR/BARMM)
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

capture mkdir "$DATA"
capture mkdir "$OUT"
capture mkdir "$TABLE"

global TABLE_D2 "$TABLE/draft2"
capture mkdir "$TABLE_D2"

*--------------------------------------------------------------*
* 1. Load merged DHS + SHS data                                *
*--------------------------------------------------------------*
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

*------------------ Region name / FE --------------------------*
capture confirm variable region_name
if _rc {
    capture confirm variable region_fe
    if _rc {
        capture confirm variable region
        if _rc {
            di as error "No region_name, region_fe, or region variable found."
            exit 198
        }
        else {
            decode region, gen(region_name)
        }
    }
    else {
        decode region_fe, gen(region_name)
    }
}

*--------------------------------------------------------------*
* 2. Standardize region names (for NCR/BARMM flags)            *
*--------------------------------------------------------------*
capture drop region_raw region_std region_std_fe
gen strL  region_raw = lower(strtrim(region_name))
gen str30 region_std = ""

* NCR variants
replace region_std = "NCR" if ///
    regexm(region_raw, "national capital") | ///
    regexm(region_raw, " ncr") | ///
    region_raw == "ncr"

* BARMM / ARMM variants
replace region_std = "BARMM" if ///
    regexm(region_raw, "muslim mindanao") | ///
    regexm(region_raw, "bangsamoro") | ///
    regexm(region_raw, "barmm") | ///
    regexm(region_raw, "armm")

* CAR / Cordillera
replace region_std = "CAR" if ///
    regexm(region_raw, "cordillera")

* Ilocos Region
replace region_std = "Ilocos Region" if ///
    regexm(region_raw, "ilocos") | ///
    regexm(region_raw, "region i ")

* Cagayan Valley
replace region_std = "Cagayan Valley" if ///
    regexm(region_raw, "cagayan valley") | ///
    regexm(region_raw, "region ii ")

* Central Luzon
replace region_std = "Central Luzon" if ///
    regexm(region_raw, "central luzon") | ///
    regexm(region_raw, "region iii ")

* CALABARZON
replace region_std = "CALABARZON" if ///
    regexm(region_raw, "calabarzon") | ///
    regexm(region_raw, "region iva")  | ///
    region_raw == "4"

* MIMAROPA
replace region_std = "MIMAROPA" if ///
    regexm(region_raw, "mimaropa") | ///
    regexm(region_raw, "ivb - mimaropa") | ///
    region_raw == "17"

* Bicol Region
replace region_std = "Bicol Region" if ///
    regexm(region_raw, "bicol") | ///
    regexm(region_raw, "region v ")

* Western Visayas
replace region_std = "Western Visayas" if ///
    regexm(region_raw, "western visayas") | ///
    regexm(region_raw, "region vi ")

* Central Visayas
replace region_std = "Central Visayas" if ///
    regexm(region_raw, "central visayas") | ///
    regexm(region_raw, "region vii ")

* Eastern Visayas
replace region_std = "Eastern Visayas" if ///
    regexm(region_raw, "eastern visayas") | ///
    regexm(region_raw, "region viii")

* Zamboanga Peninsula
replace region_std = "Zamboanga Peninsula" if ///
    regexm(region_raw, "zamboanga peninsula") | ///
    regexm(region_raw, "region ix ")

* Northern Mindanao
replace region_std = "Northern Mindanao" if ///
    regexm(region_raw, "northern mindanao") | ///
    regexm(region_raw, "region x ")

* Davao Region
replace region_std = "Davao Region" if ///
    regexm(region_raw, "davao") | ///
    regexm(region_raw, "region xi ")

* SOCCSKSARGEN
replace region_std = "SOCCSKSARGEN" if ///
    regexm(region_raw, "soccsk") | ///
    regexm(region_raw, "region xii")

* Caraga
replace region_std = "Caraga" if ///
    regexm(region_raw, "caraga") | ///
    regexm(region_raw, "region xiii")

* Fallback: if still blank, keep original (proper-cased)
replace region_std = proper(region_raw) if region_std == "" & region_raw != ""

encode region_std, gen(region_std_fe)
label var region_std_fe "Standardized region FE"

* NCR/BARMM flags
capture drop is_ncr is_barmm
gen byte is_ncr   = (region_std == "NCR")
gen byte is_barmm = (region_std == "BARMM")

*--------------------------------------------------------------*
* 3. Treatment, exposure, controls, FE                         *
*--------------------------------------------------------------*
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

*--------------------------------------------------------------*
* 4. Percentile cutoffs for SHS exposure (for trimming)        *
*--------------------------------------------------------------*
_pctile shs_per_1000_g10 [pw = `wt'], p(10 90)
local p10 = r(r1)
local p90 = r(r2)

*==============================================================*
* 5. CHECK 1: Trimming exposure extremes                       *
*==============================================================*
local trims "base low10 high10 mid80"

foreach y in `out_age' `out_b18' `out_b20' {

    foreach s of local trims {

        if "`s'" == "base" {
            local cond "if !missing(treated_shs, `y')"
        }
        else if "`s'" == "low10" {
            local cond "if shs_per_1000_g10 >= `p10' & !missing(treated_shs, `y')"
        }
        else if "`s'" == "high10" {
            local cond "if shs_per_1000_g10 <= `p90' & !missing(treated_shs, `y')"
        }
        else if "`s'" == "mid80" {
            local cond "if inrange(shs_per_1000_g10, `p10', `p90') & !missing(treated_shs, `y')"
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

*------------------ LaTeX table: trimming --------------------*
capture file close fh
file open fh using "$TABLE_D2/main_did_timing_trim.tex", write replace

file write fh "\begin{table}[htbp]" _n
file write fh "\centering" _n
file write fh "\footnotesize" _n
file write fh "\caption{Difference-in-differences estimates of SHS exposure on fertility timing outcomes: robustness to trimming exposure}" _n
file write fh "\label{tab:main_did_timing_trim}" _n
file write fh "\begin{tabular}{@{}l*{4}{c}@{}}" _n
file write fh "\toprule" _n
file write fh "Model: & (1) & (2) & (3) & (4) \\\\" _n
file write fh " & Baseline & Drop bottom 10\% & Drop top 10\% & Middle 80\% \\\\" _n
file write fh "\midrule" _n

local y "`out_age'"
file write fh "\textbf{Age at first birth} \\\\" _n
file write fh "\textit{Variables} \\\\" _n
file write fh "SHS$\times$Post" ///
    " & `cellb_base_`y'' & `cellb_low10_`y'' & `cellb_high10_`y'' & `cellb_mid80_`y'' \\\\" _n
file write fh " " ///
    " & `cellse_base_`y'' & `cellse_low10_`y'' & `cellse_high10_`y'' & `cellse_mid80_`y'' \\\\" _n
file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Fit statistics} \\\\" _n
file write fh "Number of observations" ///
    " & `N_base_`y'' & `N_low10_`y'' & `N_high10_`y'' & `N_mid80_`y'' \\\\" _n
file write fh "R-squared" ///
    " & `R2_base_`y'' & `R2_low10_`y'' & `R2_high10_`y'' & `R2_mid80_`y'' \\\\" _n
file write fh "\addlinespace[6pt]" _n

local y "`out_b18'"
file write fh "\textbf{Had a birth by age 18} \\\\" _n
file write fh "\textit{Variables} \\\\" _n
file write fh "SHS$\times$Post" ///
    " & `cellb_base_`y'' & `cellb_low10_`y'' & `cellb_high10_`y'' & `cellb_mid80_`y'' \\\\" _n
file write fh " " ///
    " & `cellse_base_`y'' & `cellse_low10_`y'' & `cellse_high10_`y'' & `cellse_mid80_`y'' \\\\" _n
file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Fit statistics} \\\\" _n
file write fh "Number of observations" ///
    " & `N_base_`y'' & `N_low10_`y'' & `N_high10_`y'' & `N_mid80_`y'' \\\\" _n
file write fh "R-squared" ///
    " & `R2_base_`y'' & `R2_low10_`y'' & `R2_high10_`y'' & `R2_mid80_`y'' \\\\" _n
file write fh "\addlinespace[6pt]" _n

local y "`out_b20'"
file write fh "\textbf{Had a birth by age 20} \\\\" _n
file write fh "\textit{Variables} \\\\" _n
file write fh "SHS$\times$Post" ///
    " & `cellb_base_`y'' & `cellb_low10_`y'' & `cellb_high10_`y'' & `cellb_mid80_`y'' \\\\" _n
file write fh " " ///
    " & `cellse_base_`y'' & `cellse_low10_`y'' & `cellse_high10_`y'' & `cellse_mid80_`y'' \\\\" _n
file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Fit statistics} \\\\" _n
file write fh "Number of observations" ///
    " & `N_base_`y'' & `N_low10_`y'' & `N_high10_`y'' & `N_mid80_`y'' \\\\" _n
file write fh "R-squared" ///
    " & `R2_base_`y'' & `R2_low10_`y'' & `R2_high10_`y'' & `R2_mid80_`y'' \\\\" _n

file write fh "\bottomrule" _n
file write fh ///
"\multicolumn{5}{p{0.96\linewidth}}{\footnotesize Standard errors in parentheses, clustered at the province level. All specifications include province, birth-cohort, and survey-year fixed effects and the full set of individual controls (urban residence, household wealth quintile dummies, and indicators for religion and ethnicity). Column (1) uses the full estimation sample. Column (2) excludes observations in the bottom 10\% of the SHS schools-per-1{,}000 Grade 10 students distribution; Column (3) excludes the top 10\%; Column (4) retains only the middle 80\%. *, **, *** denote significance at the 10\%, 5\%, and 1\% levels, respectively.} \\\\" _n
file write fh "\end{tabular}" _n
file write fh "\end{table}" _n
file close fh

*==============================================================*
* 6. CHECK 2: Excluding NCR and BARMM                          *
*==============================================================*
preserve

local regsamp "base noncr nobarmm noboth"

foreach y in `out_age' `out_b18' `out_b20' {

    foreach s of local regsamp {

        if "`s'" == "base" {
            local cond "if !missing(treated_shs, `y')"
        }
        else if "`s'" == "noncr" {
            local cond "if is_ncr==0 & !missing(treated_shs, `y')"
        }
        else if "`s'" == "nobarmm" {
            local cond "if is_barmm==0 & !missing(treated_shs, `y')"
        }
        else if "`s'" == "noboth" {
            local cond "if is_ncr==0 & is_barmm==0 & !missing(treated_shs, `y')"
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

capture file close fh
file open fh using "$TABLE_D2/main_did_timing_regions.tex", write replace

file write fh "\begin{table}[htbp]" _n
file write fh "\centering" _n
file write fh "\footnotesize" _n
file write fh "\caption{Difference-in-differences estimates of SHS exposure on fertility timing outcomes: excluding NCR and BARMM}" _n
file write fh "\label{tab:main_did_timing_regions}" _n
file write fh "\begin{tabular}{@{}l*{4}{c}@{}}" _n
file write fh "\toprule" _n
file write fh "Model: & (1) & (2) & (3) & (4) \\\\" _n
file write fh " & Baseline & Excl.\ NCR & Excl.\ BARMM & Excl.\ NCR \& BARMM \\\\" _n
file write fh "\midrule" _n

local y "`out_age'"
file write fh "\textbf{Age at first birth} \\\\" _n
file write fh "\textit{Variables} \\\\" _n
file write fh "SHS$\times$Post" ///
    " & `cellb_base_`y'' & `cellb_noncr_`y'' & `cellb_nobarmm_`y'' & `cellb_noboth_`y'' \\\\" _n
file write fh " " ///
    " & `cellse_base_`y'' & `cellse_noncr_`y'' & `cellse_nobarmm_`y'' & `cellse_noboth_`y'' \\\\" _n
file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Excluded regions} \\\\" _n
file write fh "Exclude NCR & No & Yes & No & Yes \\\\" _n
file write fh "Exclude BARMM & No & No & Yes & Yes \\\\" _n
file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Fit statistics} \\\\" _n
file write fh "Number of observations" ///
    " & `N_base_`y'' & `N_noncr_`y'' & `N_nobarmm_`y'' & `N_noboth_`y'' \\\\" _n
file write fh "R-squared" ///
    " & `R2_base_`y'' & `R2_noncr_`y'' & `R2_nobarmm_`y'' & `R2_noboth_`y'' \\\\" _n
file write fh "\addlinespace[6pt]" _n

local y "`out_b18'"
file write fh "\textbf{Had a birth by age 18} \\\\" _n
file write fh "\textit{Variables} \\\\" _n
file write fh "SHS$\times$Post" ///
    " & `cellb_base_`y'' & `cellb_noncr_`y'' & `cellb_nobarmm_`y'' & `cellb_noboth_`y'' \\\\" _n
file write fh " " ///
    " & `cellse_base_`y'' & `cellse_noncr_`y'' & `cellse_nobarmm_`y'' & `cellse_noboth_`y'' \\\\" _n
file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Excluded regions} \\\\" _n
file write fh "Exclude NCR & No & Yes & No & Yes \\\\" _n
file write fh "Exclude BARMM & No & No & Yes & Yes \\\\" _n
file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Fit statistics} \\\\" _n
file write fh "Number of observations" ///
    " & `N_base_`y'' & `N_noncr_`y'' & `N_nobarmm_`y'' & `N_noboth_`y'' \\\\" _n
file write fh "R-squared" ///
    " & `R2_base_`y'' & `R2_noncr_`y'' & `R2_nobarmm_`y'' & `R2_noboth_`y'' \\\\" _n
file write fh "\addlinespace[6pt]" _n

local y "`out_b20'"
file write fh "\textbf{Had a birth by age 20} \\\\" _n
file write fh "\textit{Variables} \\\\" _n
file write fh "SHS$\times$Post" ///
    " & `cellb_base_`y'' & `cellb_noncr_`y'' & `cellb_nobarmm_`y'' & `cellb_noboth_`y'' \\\\" _n
file write fh " " ///
    " & `cellse_base_`y'' & `cellse_noncr_`y'' & `cellse_nobarmm_`y'' & `cellse_noboth_`y'' \\\\" _n
file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Excluded regions} \\\\" _n
file write fh "Exclude NCR & No & Yes & No & Yes \\\\" _n
file write fh "Exclude BARMM & No & No & Yes & Yes \\\\" _n
file write fh "\addlinespace[3pt]" _n
file write fh "\textit{Fit statistics} \\\\" _n
file write fh "Number of observations" ///
    " & `N_base_`y'' & `N_noncr_`y'' & `N_nobarmm_`y'' & `N_noboth_`y'' \\\\" _n
file write fh "R-squared" ///
    " & `R2_base_`y'' & `R2_noncr_`y'' & `R2_nobarmm_`y'' & `R2_noboth_`y'' \\\\" _n

file write fh "\bottomrule" _n
file write fh ///
"\multicolumn{5}{p{0.96\linewidth}}{\footnotesize Standard errors in parentheses, clustered at the province level. All specifications include province, birth-cohort, and survey-year fixed effects and the same full set of individual controls (urban residence, household wealth quintile dummies, and indicators for religion and ethnicity). Column (1) uses the full estimation sample. Column (2) excludes provinces in the National Capital Region (NCR). Column (3) excludes provinces in the Bangsamoro Autonomous Region in Muslim Mindanao (BARMM, formerly ARMM). Column (4) excludes both NCR and BARMM. *, **, *** denote significance at the 10\%, 5\%, and 1\% levels, respectively.} \\\\" _n
file write fh "\end{tabular}" _n
file write fh "\end{table}" _n
file close fh

restore

*========================= END OF FILE ========================*
