/*===============================================================
Project: K–12 Schooling and Fertility
File:    04_merge_gps_muni_to_outcomes.do

Course:  ECON421 — Education and Human Capital in Developing Economies
Author:  Erika Salvador '28 (esalvador28@amherst.edu)

Purpose:
  Merge municipality identifiers derived from DHS GPS clusters (GADM level-2)
  onto the DHS outcome dataset, clean key municipality/province fields, and
  create an indicator for whether a DHS record has matched GPS information.

Inputs:
  D:/ECON421/Results/outcome_vars.dta
  D:/ECON421/Results/gps/gps_muni_allwaves.dta

Outputs:
  D:/ECON421/Results/outcome_vars_with_muni.dta

Notes:
  - Merge is m:1 on (survey_year, cluster_id).
  - Observations in GPS-only are dropped; outcomes-only remain (e.g., 2013).
  - NCR municipality names are standardized and reassigned into district
    "provinces" for consistency in downstream province-level analysis.
===============================================================*/

version 17
clear all
set more off
set maxvar 32767

*-------------------------- PATHS ---------------------------*
global ROOT "D:\ECON421"
global DATA "$ROOT\Results"
global GPS  "$ROOT\Results\gps"

* 1. Load outcomes
use "$DATA\outcome_vars.dta", clear

* 2. Merge GPS+municipality
merge m:1 survey_year cluster_id using ///
    "$GPS\gps_muni_allwaves.dta"

* _merge = 1 : in outcomes only  (includes 2013 and non-GPS clusters)
* _merge = 3 : matched to GPS+municipality
drop if _merge == 2   // clusters that exist only in gps_muni
gen byte has_gps = (_merge == 3)
label var has_gps "Cluster has GPS+municipality info"
drop _merge

* 3. Clean municipality variables
capture rename NAME_1 gadm_prov_name
capture rename NAME_2 gadm_muni_name
capture rename GID_1  gadm_prov_id
capture rename GID_2  gadm_muni_id

label var gadm_prov_name "Province name (GADM level 1)"
label var gadm_muni_name "Municipality name (GADM level 2)"
label var gadm_prov_id   "Province ID (GADM level 1)"
label var gadm_muni_id   "Municipality ID (GADM level 2)"

* Fix GADM NCR municipality spellings
replace gadm_muni_name = "City of San Juan"   if gadm_prov_name == "Metropolitan Manila" & gadm_muni_name == "San Juan"
replace gadm_muni_name = "Caloocan City"      if gadm_prov_name == "Metropolitan Manila" & gadm_muni_name == "Kalookan City"
replace gadm_muni_name = "Las Piñas City"     if gadm_prov_name == "Metropolitan Manila" & inlist(gadm_muni_name, "Las PiÃ±as", "Las Piñas")
replace gadm_muni_name = "Malabon City"       if gadm_prov_name == "Metropolitan Manila" & gadm_muni_name == "Malabon"
replace gadm_muni_name = "Mandaluyong City"   if gadm_prov_name == "Metropolitan Manila" & gadm_muni_name == "Mandaluyong"
replace gadm_muni_name = "Marikina City"      if gadm_prov_name == "Metropolitan Manila" & gadm_muni_name == "Marikina"
replace gadm_muni_name = "Muntinlupa City"    if gadm_prov_name == "Metropolitan Manila" & gadm_muni_name == "Muntinlupa"
replace gadm_muni_name = "Parañaque City"     if gadm_prov_name == "Metropolitan Manila" & gadm_muni_name == "Parañaque"
replace gadm_muni_name = "Valenzuela City"    if gadm_prov_name == "Metropolitan Manila" & gadm_muni_name == "Valenzuela"

* Reassign NCR municipalities into "district provinces"
gen muni_lc = lower(trim(gadm_muni_name))

replace gadm_prov_name = "Northern Manila District" ///
    if inlist(muni_lc, "caloocan city", "malabon city", "navotas", "valenzuela city")

replace gadm_prov_name = "Eastern Manila District" ///
    if inlist(muni_lc, "city of san juan", "mandaluyong city", "marikina city", ///
                        "pasig city", "quezon city")

replace gadm_prov_name = "Capital District" ///
    if muni_lc == "manila"

replace gadm_prov_name = "Southern Manila District" ///
    if inlist(muni_lc, "las piñas city", "las piã±as city", "makati city", "muntinlupa city", ///
                        "parañaque city", "pasay city", "pateros", "taguig")

drop muni_lc

*------------------------------------------------------------------*
* 4. For unmatched DHS records: fill missing gadm_prov_name
*    using DHS province names (only if gadm_prov_name is empty)
*------------------------------------------------------------------*

capture confirm string variable sprov
if _rc {
    decode sprov, gen(sprov_str)
}
else {
    gen sprov_str = sprov
}

gen str80 prov_lc = lower(trim(sprov_str))

* Only touch observations where gadm_prov_name is currently empty
replace gadm_prov_name = "Zamboanga del Norte"    if gadm_prov_name == "" & prov_lc == "zamboanga del norte"
replace gadm_prov_name = "Davao del Sur"          if gadm_prov_name == "" & prov_lc == "davao del sur"
replace gadm_prov_name = "Samar"                  if gadm_prov_name == "" & prov_lc == "samar (western)"
replace gadm_prov_name = "Capital District"       if gadm_prov_name == "" & prov_lc == "ncr 1"
replace gadm_prov_name = "Nueva Ecija"            if gadm_prov_name == "" & prov_lc == "nueva ecija"
replace gadm_prov_name = "North Cotabato"         if gadm_prov_name == "" & prov_lc == "cotabato (north)"
replace gadm_prov_name = "Oriental Mindoro"       if gadm_prov_name == "" & prov_lc == "oriental mindoro"
replace gadm_prov_name = "Zambales"               if gadm_prov_name == "" & prov_lc == "zambales"
replace gadm_prov_name = "Maguindanao"            if gadm_prov_name == "" & prov_lc == "maguindanao"
replace gadm_prov_name = "Davao del Norte"        if gadm_prov_name == "" & prov_lc == "davao del norte"
replace gadm_prov_name = "Camarines Norte"        if gadm_prov_name == "" & prov_lc == "camarines norte"
replace gadm_prov_name = "Palawan"                if gadm_prov_name == "" & prov_lc == "palawan"
replace gadm_prov_name = "Northern Samar"         if gadm_prov_name == "" & prov_lc == "northern samar"
replace gadm_prov_name = "Iloilo"                 if gadm_prov_name == "" & prov_lc == "iloilo"
replace gadm_prov_name = "Benguet"                if gadm_prov_name == "" & prov_lc == "benguet"
replace gadm_prov_name = "Cavite"                 if gadm_prov_name == "" & prov_lc == "cavite"
replace gadm_prov_name = "Lanao del Norte"        if gadm_prov_name == "" & prov_lc == "lanao del norte"
replace gadm_prov_name = "Quezon"                 if gadm_prov_name == "" & prov_lc == "quezon"
replace gadm_prov_name = "Sultan Kudarat"         if gadm_prov_name == "" & prov_lc == "sultan kudarat"
replace gadm_prov_name = "Southern Manila District" ///
    if gadm_prov_name == "" & prov_lc == "ncr 5 & 6"
replace gadm_prov_name = "Bukidnon"               if gadm_prov_name == "" & prov_lc == "bukidnon"
replace gadm_prov_name = "Cebu"                   if gadm_prov_name == "" & prov_lc == "cebu"
replace gadm_prov_name = "La Union"               if gadm_prov_name == "" & prov_lc == "la union"
replace gadm_prov_name = "Camarines Sur"          if gadm_prov_name == "" & prov_lc == "camarines sur"
replace gadm_prov_name = "Eastern Manila District" ///
    if gadm_prov_name == "" & prov_lc == "ncr 2 & 3"
replace gadm_prov_name = "Basilan"                if gadm_prov_name == "" & prov_lc == "isabela city"
replace gadm_prov_name = "Basilan"                if gadm_prov_name == "" & prov_lc == "basilan"
replace gadm_prov_name = "Albay"                  if gadm_prov_name == "" & prov_lc == "albay"
replace gadm_prov_name = "South Cotabato"         if gadm_prov_name == "" & prov_lc == "south cotabato"
replace gadm_prov_name = "Zamboanga del Sur"      if gadm_prov_name == "" & prov_lc == "zamboanga del sur"
replace gadm_prov_name = "Davao Oriental"         if gadm_prov_name == "" & prov_lc == "davao oriental"
replace gadm_prov_name = "Aklan"                  if gadm_prov_name == "" & prov_lc == "aklan"
replace gadm_prov_name = "Sulu"                   if gadm_prov_name == "" & prov_lc == "sulu"
replace gadm_prov_name = "Capiz"                  if gadm_prov_name == "" & prov_lc == "capiz"
replace gadm_prov_name = "Laguna"                 if gadm_prov_name == "" & prov_lc == "laguna"
replace gadm_prov_name = "Isabela"                if gadm_prov_name == "" & prov_lc == "isabela"
replace gadm_prov_name = "Batangas"               if gadm_prov_name == "" & prov_lc == "batangas"
replace gadm_prov_name = "Romblon"                if gadm_prov_name == "" & prov_lc == "romblon"
replace gadm_prov_name = "Zamboanga Sibugay"      if gadm_prov_name == "" & prov_lc == "zamboanga sibugay"
replace gadm_prov_name = "Pangasinan"             if gadm_prov_name == "" & prov_lc == "pangasinan"
replace gadm_prov_name = "Misamis Oriental"       if gadm_prov_name == "" & prov_lc == "misamis oriental"
replace gadm_prov_name = "Bulacan"                if gadm_prov_name == "" & prov_lc == "bulacan"
replace gadm_prov_name = "Agusan del Sur"         if gadm_prov_name == "" & prov_lc == "agusan del sur"
replace gadm_prov_name = "Antique"                if gadm_prov_name == "" & prov_lc == "antique"
replace gadm_prov_name = "Masbate"                if gadm_prov_name == "" & prov_lc == "masbate"
replace gadm_prov_name = "Cagayan"                if gadm_prov_name == "" & prov_lc == "cagayan"
replace gadm_prov_name = "Occidental Mindoro"     if gadm_prov_name == "" & prov_lc == "occidental mindoro"
replace gadm_prov_name = "Rizal"                  if gadm_prov_name == "" & prov_lc == "rizal"
replace gadm_prov_name = "Guimaras"               if gadm_prov_name == "" & prov_lc == "guimaras"
replace gadm_prov_name = "Dinagat Islands" ///
    if gadm_prov_name == "" & (prov_lc == "85" | sprov == 85)
replace gadm_prov_name = "Mountain Province"      if gadm_prov_name == "" & prov_lc == "mountain province"
replace gadm_prov_name = "Catanduanes"            if gadm_prov_name == "" & prov_lc == "catanduanes"
replace gadm_prov_name = "Bataan"                 if gadm_prov_name == "" & prov_lc == "bataan"
replace gadm_prov_name = "Lanao del Sur"          if gadm_prov_name == "" & prov_lc == "lanao del sur"
replace gadm_prov_name = "Pampanga"               if gadm_prov_name == "" & prov_lc == "pampanga"
replace gadm_prov_name = "Ilocos Norte"           if gadm_prov_name == "" & prov_lc == "ilocos norte"
replace gadm_prov_name = "Negros Oriental"        if gadm_prov_name == "" & prov_lc == "negros oriental"
replace gadm_prov_name = "Bohol"                  if gadm_prov_name == "" & prov_lc == "bohol"
replace gadm_prov_name = "Compostela Valley"      if gadm_prov_name == "" & prov_lc == "compostella valley"
replace gadm_prov_name = "Northern Manila District" ///
    if gadm_prov_name == "" & prov_lc == "ncr 4"
replace gadm_prov_name = "Quirino"                if gadm_prov_name == "" & prov_lc == "quirino"
replace gadm_prov_name = "Negros Occidental"      if gadm_prov_name == "" & prov_lc == "negros occidental"
replace gadm_prov_name = "Aurora"                 if gadm_prov_name == "" & prov_lc == "aurora"
replace gadm_prov_name = "Tarlac"                 if gadm_prov_name == "" & prov_lc == "tarlac"
replace gadm_prov_name = "Surigao del Sur"        if gadm_prov_name == "" & prov_lc == "surigao del sur"
replace gadm_prov_name = "Surigao del norte"      if gadm_prov_name == "" & prov_lc == "agusan del norte"
replace gadm_prov_name = "Kalinga"                if gadm_prov_name == "" & prov_lc == "kalinga"
replace gadm_prov_name = "Southern leyte"         if gadm_prov_name == "" & prov_lc == "southern leyte"
replace gadm_prov_name = "Ilocos sur"             if gadm_prov_name == "" & prov_lc == "ilocos sur"
replace gadm_prov_name = "Marinduque"             if gadm_prov_name == "" & prov_lc == "marinduque"
replace gadm_prov_name = "Surigao del norte"      if gadm_prov_name == "" & prov_lc == "surigao del norte"
replace gadm_prov_name = "Tawi-tawi"              if gadm_prov_name == "" & prov_lc == "tawi-tawi"
replace gadm_prov_name = "Nueva Vizcaya"          if gadm_prov_name == "" & prov_lc == "nueva vizcaya"
replace gadm_prov_name = "Ifugao"                 if gadm_prov_name == "" & prov_lc == "ifugao"
replace gadm_prov_name = "Eastern Samar"          if gadm_prov_name == "" & prov_lc == "eastern samar"
replace gadm_prov_name = "Camiguin"               if gadm_prov_name == "" & prov_lc == "camiguin"
replace gadm_prov_name = "Leyte"                  if gadm_prov_name == "" & prov_lc == "leyte"
replace gadm_prov_name = "Biliran"                if gadm_prov_name == "" & prov_lc == "biliran"
replace gadm_prov_name = "Sorsogon"               if gadm_prov_name == "" & prov_lc == "sorsogon"
replace gadm_prov_name = "Misamis Occidental"     if gadm_prov_name == "" & prov_lc == "misamis occidental"
replace gadm_prov_name = "Abra"                   if gadm_prov_name == "" & prov_lc == "abra"
replace gadm_prov_name = "Sarangani"              if gadm_prov_name == "" & prov_lc == "sarangani"
replace gadm_prov_name = "Apayao"                 if gadm_prov_name == "" & prov_lc == "apayao"
replace gadm_prov_name = "Siquijor"               if gadm_prov_name == "" & prov_lc == "siquijor"
replace gadm_prov_name = "Maguindanao"            if gadm_prov_name == "" & prov_lc == "cotabato city"

drop prov_lc

*------------------------------------------------------------*
* Final housekeeping and save
*------------------------------------------------------------*

ds, has(varlabel)
local keepvars `r(varlist)'

keep `keepvars'
 
order survey_year cluster_id has_gps gadm_prov_name gadm_muni_name ///
      gadm_prov_id gadm_muni_id

compress
save "$DATA\outcome_vars_with_muni.dta", replace
