/*===============================================================
Project: K–12 Schooling and Fertility
File:    05_build_shs_enrollment_exposure.do

Course:  ECON421 — Education and Human Capital in Developing Economies
Author:  Erika Salvador '28 (esalvador28@amherst.edu)

Purpose:
  Construct province-level SHS exposure:
    SHS_per_1000 = (# SHS schools in SY 2016–2017) /
                   (Grade 10 enrollment in SY 2015–2016 / 1,000).

Inputs:
  D:/ECON421/Results/division_province_lookup.csv
  D:/ECON421/Results/list_of_shs_2016-2017.csv
  D:/ECON421/Results/grade_10_enrollment_2015-2016.csv

Outputs:
  D:/ECON421/Results/output/shs_enrollment_exposure_province.dta

Notes:
  - Division→province mapping is applied via (region, division) lookup.
  - SHS counts are deduplicated by school_id before collapsing.
===============================================================*/

version 17
clear all
set more off
set maxvar 32767

*--------------------------- PATHS ----------------------------*
global ROOT "D:\ECON421"
global RAW  "$ROOT\Results"
global OUT  "$ROOT\Results\output"

*--------------------------------------------------------------*
* 0. Division–Province lookup (Region + Division → Province)
*--------------------------------------------------------------*
import delimited using "$RAW/division_province_lookup.csv", ///
    clear varnames(1) stringcols(_all) case(lower)

* Basic cleaning of names
foreach v of varlist region division province {
    replace `v' = strtrim(`v')
}

tempfile div_prov
save `div_prov', replace


*--------------------------------------------------------------*
* 1. SHS counts by province (SY 2016–2017)
*--------------------------------------------------------------*
import delimited using "$RAW/list_of_shs_2016-2017.csv", ///
    clear varnames(1) stringcols(_all) case(lower)

* Clean region/division names for merge
foreach v of varlist region division {
    replace `v' = strtrim(`v')
}

* Deduplicate schools just in case
bysort school_id: keep if _n == 1

* Merge to get province
merge m:1 region division using `div_prov', ///
    keepusing(province) ///
    keep(match master) nogen

* Count schools using a numeric dummy
gen one = 1
collapse (count) shs_schools = one, by(province)

label var shs_schools "Number of SHS schools, SY 2016–2017"

tempfile shs_prov
save `shs_prov', replace


*--------------------------------------------------------------*
* 2. Grade 10 enrollment by province (SY 2015–2016)
*--------------------------------------------------------------*
import delimited using "$RAW/grade_10_enrollment_2015-2016.csv", ///
    clear varnames(1) stringcols(_all) case(lower)

* Clean region/division names for merge
foreach v of varlist region division {
    replace `v' = strtrim(`v')
}

* (Optional) Restrict to public schools only
* keep if lower(status) == "public"

* Convert male/female to numeric
destring male female, replace ignore(" ,")

* Total Grade 10 enrollment at the school level
gen g10_enroll = male + female
label var g10_enroll "Grade 10 enrollment per school, SY 2015–2016"

* Merge to get province
merge m:1 region division using `div_prov', ///
    keepusing(province) ///
    keep(match master) nogen

* Sum enrollment to province level
collapse (sum) g10_enroll, by(province)
label var g10_enroll "Grade 10 enrollment, SY 2015–2016"

tempfile enroll_prov
save `enroll_prov', replace


*--------------------------------------------------------------*
* 3. Merge components + construct SHS exposure variable
*--------------------------------------------------------------*
use `shs_prov', clear
merge 1:1 province using `enroll_prov', nogen

gen shs_per_1000_g10 = shs_schools / (g10_enroll/1000)
label var shs_per_1000_g10 ///
    "SHS schools per 1,000 Grade 10 students (2016–17 / 2015–16)"

order province shs_schools g10_enroll shs_per_1000_g10


*--------------------------------------------------------------*
* 4. Save final province-level exposure file
*--------------------------------------------------------------*
save "$OUT/shs_enrollment_exposure_province.dta", replace
