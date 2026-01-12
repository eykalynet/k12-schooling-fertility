/*===============================================================
Project: K–12 Schooling and Fertility
File:    02_import_dhs_gps_and_prepare.do

Course:  ECON421 — Education and Human Capital in Developing Economies
Author:  Erika Salvador '28 (esalvador28@amherst.edu)

Purpose:
  Import DHS GPS cluster extracts created by 01_extract_dhs_gps_to_dta.R,
  harmonize core variables across waves, and stack all available GPS waves
  into a single dataset for downstream merges.

Inputs:
  D:/ECON421/Results/gps/gps_raw_YYYY.dta

Outputs:
  D:/ECON421/Results/gps/gps_clusters_allwaves.dta

Notes:
  - DHS did not release GPS for 2013 (Philippines), so 2013 is excluded.
  - Script is quiet and skips waves with missing input files.
===============================================================*/

version 17
clear all
set more off
set maxvar 32767

global ROOT "D:\ECON421"
global GPS  "$ROOT\Results\gps"
global DATA "$ROOT\Results"

* Waves with GPS available (DHS did not release 2013 GPS)
local years 2003 2008 2017 2022

tempfile allgps
save `allgps', emptyok

foreach y of local years {

    capture confirm file "$GPS\gps_raw_`y'.dta"
    if _rc continue

    quietly use "$GPS\gps_raw_`y'.dta", clear

    * Ensure survey_year exists
    capture confirm variable survey_year
    if _rc gen survey_year = `y'

    * Cluster ID
    capture rename DHSCLUST cluster_id

    * Latitude / longitude (typical DHS GPS names)
    capture rename LATNUM  latnum
    capture rename LONGNUM longnum

    * Urban / rural (if present)
    capture rename URBAN_RURA urban_rural

    * Admin1 region name (if present)
    capture rename ADM1NAME region_name

    * Keep only relevant vars
    local keepvars survey_year cluster_id DHSID DHSCC DHSYEAR ///
        latnum longnum urban_rural region_name
    keep `keepvars'

    append using `allgps'
    save `allgps', replace
}

use `allgps', clear
order survey_year cluster_id DHSID DHSCC DHSYEAR latnum longnum urban_rural region_name
sort  survey_year cluster_id
compress

label var survey_year  "DHS survey year"
label var cluster_id   "DHS cluster (v001)"
label var DHSID        "DHS survey identifier"
label var DHSCC        "Country code (DHS)"
label var DHSYEAR      "DHS year (from GPS file)"
label var latnum       "Cluster latitude (decimal degrees)"
label var longnum      "Cluster longitude (decimal degrees)"
label var urban_rural  "Urban/rural (from DHS GPS)"
label var region_name  "Admin1 name (from DHS GPS)"

save "$GPS\gps_clusters_allwaves.dta", replace
