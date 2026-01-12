/*===============================================================
Project: K–12 Schooling and Fertility
File:    06_merge_shs_enrollment_exposure_to_dhs.do

Course:  ECON421 — Education and Human Capital in Developing Economies
Author:  Erika Salvador '28 (esalvador28@amherst.edu)

Purpose:
  Merge province-level SHS exposure (SHS schools per 1,000 Grade 10 students)
  onto DHS woman-level outcomes using harmonized province name keys.

Inputs:
  D:/ECON421/Results/output/shs_enrollment_exposure_province.dta
  D:/ECON421/Results/outcome_vars_with_muni.dta

Outputs:
  D:/ECON421/Results/output/dhs_with_shs_enrollment_exposure.dta
  D:/ECON421/Results/output/dhs_unmatched_provinces.dta
  D:/ECON421/Results/output/dhs_unmatched_provinces.csv

Notes:
  - Merge is m:1 on prov_key = lower(trim(province name)).
  - Unmatched DHS observations are saved for diagnosing province-name
    mismatches and missing exposure coverage.
===============================================================*/

version 17
clear all
set more off
set maxvar 32767

*--------------------------- PATHS ----------------------------*
global ROOT "D:\ECON421"
global DATA "$ROOT\Results"
global SHS  "$ROOT\Results\output"
global OUT  "$ROOT\Results\output"

*--------------------------------------------------------------*
* 1. Prep SHS exposure file (province-level)
*--------------------------------------------------------------*
use "$SHS/shs_enrollment_exposure_province.dta", clear

* Harmonize key (lower/trim)
gen str80 prov_key = lower(trim(province))
replace prov_key = subinstr(prov_key, "  ", " ", .)

order province prov_key shs_schools g10_enroll shs_per_1000_g10

tempfile shs_expo
save `shs_expo', replace


*--------------------------------------------------------------*
* 2. Load DHS data and build matching province key
*--------------------------------------------------------------*
use "$DATA/outcome_vars_with_muni.dta", clear

* Assume gadm_prov_name holds GADM province name
capture confirm string variable gadm_prov_name
if _rc {
    di as err "Variable gadm_prov_name not found. Check DHS file."
    exit 198
}

gen str80 prov_key = lower(trim(gadm_prov_name))
replace prov_key = subinstr(prov_key, "  ", " ", .)

order prov_key gadm_prov_name


*--------------------------------------------------------------*
* 3. Merge SHS exposure to DHS
*--------------------------------------------------------------*
merge m:1 prov_key using `shs_expo'

tab _merge
* 1 = DHS only (no exposure), 3 = matched

label var shs_schools        "SHS schools, SY 2016–2017 (province)"
label var g10_enroll         "Grade 10 enrollment 2015–2016 (province)"
label var shs_per_1000_g10   "SHS schools per 1,000 G10 students"


*--------------------------------------------------------------*
* Export unmatched DHS observations (no SHS exposure match)
*--------------------------------------------------------------*
preserve
    keep if _merge == 1   // DHS only, no match
    save "$OUT/dhs_unmatched_provinces.dta", replace
    export delimited using "$OUT/dhs_unmatched_provinces.csv", replace
restore


*--------------------------------------------------------------*
* 4. Save merged DHS + exposure file
*--------------------------------------------------------------*
save "$OUT/dhs_with_shs_enrollment_exposure.dta", replace
