/******************************************************************
   robustness_lopo.do
   ECON421 — Erika Salvador

   Purpose:
     - Leave-one-province-out (LOPO) robustness for fertility timing.
       Outcomes:
         * age_first_birth
         * birth_by18
         * birth_by20

       Specification:
         y = β · (SHS exposure × Post) + FE + X + ε
           with province, cohort, and survey-year fixed effects,
           full individual controls, and province-clustered SEs.

   Steps:
     (1) Build DiD sample and estimate baseline coefficients.
     (2) For each province p:
           - Drop p from the sample
           - Re-estimate DiD
           - Store β, SE, and p-value for each outcome
     (3) Produce:
           - main_did_timing_lopo.tex       (summary LOPO table)
           - main_did_timing_lopo_full.tex  (full LOPO appendix table)

   Data in:
     - $OUT/dhs_with_shs_enrollment_exposure.dta

   Output:
     - $OUT/lopo_did_timing.dta
     - $TABLE/draft2/main_did_timing_lopo.tex
     - $TABLE/draft2/main_did_timing_lopo_full.tex
******************************************************************/


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
* 1. Load merged DHS + SHS data and build DiD sample           *
*--------------------------------------------------------------*/
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

*------------------ Province name (string) --------------------*
capture confirm variable prov_name
if _rc {
    capture confirm variable prov_key
    if !_rc {
        gen str40 prov_name = prov_key
    }
    else {
        gen str40 prov_name = ""
    }
}
label var prov_name "Province name"

*------------------ Treatment, exposure, cohorts --------------*
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

*------------------ Controls, FE, weights ---------------------*
local controls_full ///
    "urban wealth_index rel_prot rel_inc rel_muslim rel_other eth_cebuano eth_ilocano eth_other"

local provfe   "prov_fe"
local wt       "w"
local cohortfe "cohort"
local year     "survey_year"
local absorb_base "`provfe' `cohortfe' `year'"

* Outcomes (timing)
local out_age "age_first_birth"
local out_b18 "birth_by18"
local out_b20 "birth_by20"

capture which reghdfe
if _rc ssc install reghdfe, replace

* Keep only women used in timing DiD (non-missing SHS)
keep if !missing(treated_shs)

tempfile main
save `main', replace

*--------------------------------------------------------------*
* 2. Baseline DiD coefficients (full sample)                   *
*--------------------------------------------------------------*/
use `main', clear

* Age at first birth
quietly reghdfe `out_age' treated shs treated_shs ///
    `controls_full' [pw = `wt'] if !missing(`out_age'), ///
    absorb(`absorb_base') vce(cluster `provfe')
scalar b0_age  = _b[treated_shs]
scalar se0_age = _se[treated_shs]
scalar p0_age  = 2*ttail(e(df_r), abs(b0_age/se0_age))

* Birth by 18
quietly reghdfe `out_b18' treated shs treated_shs ///
    `controls_full' [pw = `wt'] if !missing(`out_b18'), ///
    absorb(`absorb_base') vce(cluster `provfe')
scalar b0_b18  = _b[treated_shs]
scalar se0_b18 = _se[treated_shs]
scalar p0_b18  = 2*ttail(e(df_r), abs(b0_b18/se0_b18))

* Birth by 20
quietly reghdfe `out_b20' treated shs treated_shs ///
    `controls_full' [pw = `wt'] if !missing(`out_b20'), ///
    absorb(`absorb_base') vce(cluster `provfe')
scalar b0_b20  = _b[treated_shs]
scalar se0_b20 = _se[treated_shs]
scalar p0_b20  = 2*ttail(e(df_r), abs(b0_b20/se0_b20))

* Format baseline with stars and SEs
local star_age ""
if (p0_age<0.01)      local star_age "***"
else if (p0_age<0.05) local star_age "**"
else if (p0_age<0.10) local star_age "*"

local star_b18 ""
if (p0_b18<0.01)      local star_b18 "***"
else if (p0_b18<0.05) local star_b18 "**"
else if (p0_b18<0.10) local star_b18 "*"

local star_b20 ""
if (p0_b20<0.01)      local star_b20 "***"
else if (p0_b20<0.05) local star_b20 "**"
else if (p0_b20<0.10) local star_b20 "*"

local base_age  : display %6.3f b0_age
local base_b18  : display %6.3f b0_b18
local base_b20  : display %6.3f b0_b20
local se_age    : display %6.3f se0_age
local se_b18    : display %6.3f se0_b18
local se_b20    : display %6.3f se0_b20

local base_age  "`base_age'`star_age'"
local base_b18  "`base_b18'`star_b18'"
local base_b20  "`base_b20'`star_b20'"

*--------------------------------------------------------------*
* 3. Province list                                             *
*--------------------------------------------------------------*/
use `main', clear
keep prov_fe prov_name
bysort prov_fe: keep if _n == 1
tempfile provlist
save `provlist', replace

levelsof prov_fe, local(prov_ids)

*--------------------------------------------------------------*
* 4. LOPO estimates: postfile with β, SE, p                    *
*--------------------------------------------------------------*/
tempname memhold
postfile `memhold' int prov_fe str40 provname ///
    double b_age_first  se_age_first  p_age_first ///
           b_birth_by18 se_birth_by18 p_birth_by18 ///
           b_birth_by20 se_birth_by20 p_birth_by20 ///
    using "$OUT/lopo_did_timing.dta", replace

foreach p of local prov_ids {

    * Province name
    use `provlist', clear
    keep if prov_fe == `p'
    local thisname = prov_name[1]

    * Drop this province and re-estimate
    use `main', clear
    drop if prov_fe == `p'

    * Age at first birth
    quietly reghdfe `out_age' treated shs treated_shs ///
        `controls_full' [pw = `wt'] if !missing(`out_age'), ///
        absorb(`absorb_base') vce(cluster `provfe')
    scalar b1  = _b[treated_shs]
    scalar se1 = _se[treated_shs]
    scalar p1  = 2*ttail(e(df_r), abs(b1/se1))

    * Birth by 18
    quietly reghdfe `out_b18' treated shs treated_shs ///
        `controls_full' [pw = `wt'] if !missing(`out_b18'), ///
        absorb(`absorb_base') vce(cluster `provfe')
    scalar b2  = _b[treated_shs]
    scalar se2 = _se[treated_shs]
    scalar p2  = 2*ttail(e(df_r), abs(b2/se2))

    * Birth by 20
    quietly reghdfe `out_b20' treated shs treated_shs ///
        `controls_full' [pw = `wt'] if !missing(`out_b20'), ///
        absorb(`absorb_base') vce(cluster `provfe')
    scalar b3  = _b[treated_shs]
    scalar se3 = _se[treated_shs]
    scalar p3  = 2*ttail(e(df_r), abs(b3/se3))

    * Store row
    post `memhold' (`p') ("`thisname'") ///
        (b1) (se1) (p1) ///
        (b2) (se2) (p2) ///
        (b3) (se3) (p3)
}

postclose `memhold'

*--------------------------------------------------------------*
* 5. Load LOPO results and compute summary stats               *
*--------------------------------------------------------------*/
use "$OUT/lopo_did_timing.dta", clear
* vars: prov_fe provname b_* se_* p_*

program define lopo_stats, rclass
    syntax varname
    tempvar v
    gen double `v' = `varlist'

    quietly summarize `v'
    return scalar mean = r(mean)
    return scalar sd   = r(sd)

    sort `v'
    return scalar min = `v'[1]
    return local  minprov = provname[1]

    sort `v'
    return scalar max = `v'[_N]
    return local  maxprov = provname[_N]
end

* Age at first birth
quietly lopo_stats b_age_first
local mean_age    : display %6.3f r(mean)
local sd_age      : display %6.3f r(sd)
local min_age     : display %6.3f r(min)
local max_age     : display %6.3f r(max)
local minprov_age = r(minprov)
local maxprov_age = r(maxprov)

* Birth by 18
quietly lopo_stats b_birth_by18
local mean_b18    : display %6.3f r(mean)
local sd_b18      : display %6.3f r(sd)
local min_b18     : display %6.3f r(min)
local max_b18     : display %6.3f r(max)
local minprov_b18 = r(minprov)
local maxprov_b18 = r(maxprov)

* Birth by 20
quietly lopo_stats b_birth_by20
local mean_b20    : display %6.3f r(mean)
local sd_b20      : display %6.3f r(sd)
local min_b20     : display %6.3f r(min)
local max_b20     : display %6.3f r(max)
local minprov_b20 = r(minprov)
local maxprov_b20 = r(maxprov)

*--------------------------------------------------------------*
* 6. SUMMARY LOPO TABLE (Table: main_did_timing_lopo.tex)      *
*--------------------------------------------------------------*/
capture file close fh
file open fh using "$TABLE_D2/main_did_timing_lopo.tex", write replace

file write fh "\begin{table}[htbp]" _n
file write fh "\centering" _n
file write fh "\footnotesize" _n
file write fh "\caption{Leave-one-province-out (LOPO) robustness of SHS effects on fertility timing}" _n
file write fh "\label{tab:main_did_timing_lopo}" _n
file write fh "\begin{tabular}{@{}lccc@{}}" _n
file write fh "\toprule" _n
file write fh " & Age at first birth & Had a birth by 18 & Had a birth by 20 \\\\" _n
file write fh "\midrule" _n

file write fh "\textit{Baseline DiD coefficient} & `base_age' & `base_b18' & `base_b20' \\\\" _n
file write fh "\textit{Baseline standard error} & (`se_age') & (`se_b18') & (`se_b20') \\\\" _n
file write fh "\addlinespace[3pt]" _n

file write fh "\textit{Mean LOPO coefficient} & `mean_age' & `mean_b18' & `mean_b20' \\\\" _n
file write fh "\textit{Std.\ dev.\ across provinces} & `sd_age' & `sd_b18' & `sd_b20' \\\\" _n
file write fh "\addlinespace[3pt]" _n

file write fh "\textit{Minimum LOPO coefficient} & `min_age' & `min_b18' & `min_b20' \\\\" _n
file write fh "\textit{Province at minimum} & `minprov_age' & `minprov_b18' & `minprov_b20' \\\\" _n
file write fh "\addlinespace[3pt]" _n

file write fh "\textit{Maximum LOPO coefficient} & `max_age' & `max_b18' & `max_b20' \\\\" _n
file write fh "\textit{Province at maximum} & `maxprov_age' & `maxprov_b18' & `maxprov_b20' \\\\" _n

file write fh "\bottomrule" _n
file write fh ///
"\multicolumn{4}{p{0.96\linewidth}}{\footnotesize Entries report the coefficient on SHS exposure interacted with the post-reform cohort indicator (SHS$\times$Post) from the main difference-in-differences specification. ``Baseline DiD coefficient'' shows the full-sample estimate, with standard errors clustered at the province level and significance indicated by *, **, and *** at the 10\%, 5\%, and 1\% levels, respectively. LOPO rows summarize the distribution of coefficients when each province is sequentially excluded from the sample. Minimum and maximum rows report the smallest and largest LOPO coefficients, along with the provinces whose exclusion generates those values. All regressions include province, birth-cohort, and survey-year fixed effects and the full set of individual controls.} \\\\" _n

file write fh "\end{tabular}" _n
file write fh "\end{table}" _n

file close fh

*--------------------------------------------------------------*
* 7. FULL APPENDIX TABLE (one row per removed province)        *
*--------------------------------------------------------------*/
use "$OUT/lopo_did_timing.dta", clear
sort provname

capture file close fh2
file open fh2 using "$TABLE_D2/main_did_timing_lopo_full.tex", write replace

file write fh2 "\begin{table}[htbp]" _n
file write fh2 "\centering" _n
file write fh2 "\scriptsize" _n
file write fh2 "\caption{Leave-one-province-out (LOPO) coefficients by dropped province}" _n
file write fh2 "\label{tab:main_did_timing_lopo_full}" _n
file write fh2 "\begin{tabular}{@{}lccc@{}}" _n
file write fh2 "\toprule" _n
file write fh2 "Removed province & Age at first birth & Had a birth by 18 & Had a birth by 20 \\\\" _n
file write fh2 "\midrule" _n

quietly {
    local N = _N
    forvalues i = 1/`N' {

        * Province name, escape &
        local pname = provname[`i']
        local pname = subinstr("`pname'","&","\&",.)

        * --- Age at first birth ---
        local b1  = b_age_first[`i']
        local se1 = se_age_first[`i']
        local p1  = p_age_first[`i']

        local star1 ""
        if (`p1'<0.01)      local star1 "***"
        else if (`p1'<0.05) local star1 "**"
        else if (`p1'<0.10) local star1 "*"

        local b1s  : display %6.3f `b1'
        local se1s : display %6.3f `se1'
        local cell1 "`b1s'`star1' (`se1s')"

        * --- Birth by 18 ---
        local b2  = b_birth_by18[`i']
        local se2 = se_birth_by18[`i']
        local p2  = p_birth_by18[`i']

        local star2 ""
        if (`p2'<0.01)      local star2 "***"
        else if (`p2'<0.05) local star2 "**"
        else if (`p2'<0.10) local star2 "*"

        local b2s  : display %6.3f `b2'
        local se2s : display %6.3f `se2'
        local cell2 "`b2s'`star2' (`se2s')"

        * --- Birth by 20 ---
        local b3  = b_birth_by20[`i']
        local se3 = se_birth_by20[`i']
        local p3  = p_birth_by20[`i']

        local star3 ""
        if (`p3'<0.01)      local star3 "***"
        else if (`p3'<0.05) local star3 "**"
        else if (`p3'<0.10) local star3 "*"

        local b3s  : display %6.3f `b3'
        local se3s : display %6.3f `se3'
        local cell3 "`b3s'`star3' (`se3s')"

        * Write row
        file write fh2 "`pname' & `cell1' & `cell2' & `cell3' \\\\" _n
    }
}

file write fh2 "\bottomrule" _n
file write fh2 ///
"\multicolumn{4}{p{0.96\linewidth}}{\footnotesize Each row reports the coefficient on SHS$\times$Post from re-estimating the main difference-in-differences specification after excluding the indicated province from the sample. Standard errors, in parentheses, are clustered at the province level. Stars indicate significance of the SHS$\times$Post coefficient within each leave-one-province-out regression at the 10\%, 5\%, and 1\% levels, respectively. All regressions include province, birth-cohort, and survey-year fixed effects and the full set of individual controls.} \\\\" _n

file write fh2 "\end{tabular}" _n
file write fh2 "\end{table}" _n

file close fh2

*========================= END OF FILE ========================*
