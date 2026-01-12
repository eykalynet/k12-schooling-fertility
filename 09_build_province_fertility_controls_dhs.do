/*===============================================================
Project: K–12 Schooling and Fertility
File:    09_build_province_fertility_controls_dhs.do

Course:  ECON421 — Education and Human Capital in Developing Economies
Author:  Erika Salvador '28 (esalvador28@amherst.edu)

Purpose:
  Construct province × survey-year fertility controls from DHS microdata
  (same merged file used in the main DiD). Outputs province-year averages
  that can be merged back into individual-level regressions.

Inputs:
  D:/ECON421/Results/output/dhs_with_shs_enrollment_exposure.dta

Outputs:
  D:/ECON421/Results/output/province_fertility_controls_dhs.dta

Notes:
  - Uses DHS sampling weights.
  - Restricts to women ages 15–49.
  - "Completed fertility" proxy uses CEB for ages 40–49.
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

*------------------------------*
* 1. Load DHS + SHS merged data
*------------------------------*
use "$OUT/dhs_with_shs_enrollment_exposure.dta", clear

* Ensure province FE exists (same as 09_main_did.do)
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

* Keep core DHS reproductive-age sample
keep if inrange(age, 15, 49)
drop if missing(prov_fe, survey_year)

* Weight variable
local wt "w"

*------------------------------*
* 2. Construct helper variables
*------------------------------*

* Completed fertility proxy: CEB for women 40–49
gen ceb_40_49 = ceb if inrange(age, 40, 49)

* Birth-by-X indicators already exist from the pipeline:
*   birth_by18, birth_by20, birth_by25
* Eligibility indicators (defined if the birth_byX variable is non-missing)
gen b18_eligible = !missing(birth_by18)
gen b20_eligible = !missing(birth_by20)
gen b25_eligible = !missing(birth_by25)

* Age at first birth among ever-mothers
gen afb_ever = age_first_birth if !missing(age_first_birth)

*------------------------------*
* 3. Collapse to province × survey-year
*------------------------------*
preserve

collapse ///
    (mean) ///
        pf_ceb_mean        = ceb            ///
        pf_ceb_40_49       = ceb_40_49      ///
        pf_birthby18       = birth_by18     ///
        pf_birthby20       = birth_by20     ///
        pf_birthby25       = birth_by25     ///
        pf_afb             = afb_ever       ///
        pf_b18_elig_share  = b18_eligible   ///
        pf_b20_elig_share  = b20_eligible   ///
        pf_b25_elig_share  = b25_eligible   ///
    [pw = `wt'], ///
    by(prov_fe survey_year)

label var pf_ceb_mean       "Mean CEB (15–49, DHS)"
label var pf_ceb_40_49      "Mean CEB (40–49, DHS)"
label var pf_birthby18      "Share with birth by 18 (DHS)"
label var pf_birthby20      "Share with birth by 20 (DHS)"
label var pf_birthby25      "Share with birth by 25 (DHS)"
label var pf_afb            "Mean age at first birth (DHS)"
label var pf_b18_elig_share "Share of women age-eligible for birth_by18"
label var pf_b20_elig_share "Share of women age-eligible for birth_by20"
label var pf_b25_elig_share "Share of women age-eligible for birth_by25"

save "$OUT/province_fertility_controls_dhs.dta", replace

restore
