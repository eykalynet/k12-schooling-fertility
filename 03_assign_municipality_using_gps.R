#===============================================================
# Project: K–12 Schooling and Fertility
# File:    03_assign_municipality_using_gps.R
#
# Course:  ECON421 — Education and Human Capital in Developing Economies
# Author:  Erika Salvador ’28 (esalvador28@amherst.edu)
#
# Purpose:
#   Assign each DHS GPS cluster to a municipality using a spatial join
#   (GADM level-2). Outputs a cluster-level file with municipality
#   identifiers/attributes appended for downstream merges.
#
# Inputs:
#   D:/ECON421/Results/gps/gps_clusters_allwaves.dta
#   D:/ECON421/Results/gps/municipalities_shapefile/gadm41_PHL_2.shp
#
# Outputs:
#   D:/ECON421/Results/gps/gps_muni_allwaves.dta
#
# Notes:
#   - Coordinates assumed WGS84 (EPSG:4326).
#   - Spatial join is left join (clusters outside polygons remain missing).
#===============================================================

library(sf)
library(haven)
library(dplyr)

gps_dir  <- "D:/ECON421/Results/gps"
shp_dir  <- file.path(gps_dir, "municipalities_shapefile")

# Read GPS clusters
gps <- read_dta(file.path(gps_dir, "gps_clusters_allwaves.dta"))

gps_sf <- st_as_sf(
  gps,
  coords = c("longnum", "latnum"),
  crs = 4326,
  remove = FALSE   # keep latnum/longnum as regular columns
)

# Read municipality shapefile (GADM level-2 = municipalities)
muni_file <- file.path(shp_dir, "gadm41_PHL_2.shp")
muni <- st_read(muni_file, quiet = TRUE)

# Spatial join: cluster -> municipality
gps_muni <- st_join(gps_sf, muni, left = TRUE)

# Drop geometry; keep all attributes (GPS + municipality info)
gps_muni_df <- gps_muni |> st_drop_geometry()

out_file <- file.path(gps_dir, "gps_muni_allwaves.dta")
write_dta(gps_muni_df, out_file)
