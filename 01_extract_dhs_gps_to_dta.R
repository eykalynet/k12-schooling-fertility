# ===============================================================
# Project: K–12 Schooling and Fertility
# File:    01_extract_dhs_gps_to_dta.R
#
# Course:  ECON421 — Education and Human Capital in Developing Economies
# Author:  Erika Salvador ’28 (esalvador28@amherst.edu)
#
# Purpose:
#  Read DHS GPS shapefiles (PHGE##FL) for the Philippines,
#  drop geometry (retain attributes only), and export
#  Stata-compatible .dta files for subsequent merging.
#
# Inputs:
#  D:/ECON421/Results/gps/{year}/PHGE##FL/PHGE##FL.shp
#
# Outputs:
#  D:/ECON421/Results/gps/gps_raw_{year}.dta
#
# Notes:
#  - Scripts are numbered and should be run in order.
#  - Paths are defined relative to D:/ECON421/Results.
# ===============================================================

library(sf)
library(haven)
library(dplyr)

root <- "D:/ECON421"
gps_root <- file.path(root, "Results", "gps")

# Years + corresponding PHGE codes 
years  <- c(2003, 2008, 2013, 2017, 2022)
gecode <- c(   43,   52,   61,   71,   81)  

for (i in seq_along(years)) {
  yr  <- years[i]
  gc  <- gecode[i]
  
  shp_dir  <- file.path(gps_root, yr, paste0("PHGE", gc, "FL"))
  shp_file <- file.path(shp_dir, paste0("PHGE", gc, "FL.shp"))
  
  if (!file.exists(shp_file)) {
    next
  }
    gps_sf <- st_read(shp_file, quiet = TRUE)
  
  # Drop geometry, keep attributes only
  gps_df <- gps_sf |> 
    st_drop_geometry() |>
    mutate(survey_year = yr)
  
  # Output .dta file
  out_file <- file.path(gps_root, paste0("gps_raw_", yr, ".dta"))
  write_dta(gps_df, out_file)
}