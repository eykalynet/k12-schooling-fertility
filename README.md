# k12-schooling-fertility

This repository contains the analysis code used for an original empirical paper on the effects of the Philippine K-12 reform (Republic Act 10533) on adolescent fertility.

The scripts reflect the workflow used in the project and are shared for transparency. They are not a self-contained replication package. File paths, directory structures, and intermediate data are specific to the authors’ local setup and will need to be adapted by anyone reusing the code.

---

## Project overview

The paper studies how the introduction of mandatory Senior High School affected fertility timing and related reproductive outcomes among young women in the Philippines.

Identification combines cohort-based exposure to the reform with geographic variation in the rollout of Senior High School across provinces. The empirical analysis relies on difference-in-differences, event studies, and hazard models.

---

## What this repository contains

This repository includes the scripts used to clean data, construct exposure measures, estimate the main specifications, and run robustness and mechanism checks. It is meant to document the analytical process behind the paper rather than to provide a plug-and-play replication.

Users should expect to modify paths and data inputs before running any scripts.

---

## Repository structure

```
.
├── 00_econ421_final_paper.pdf
├── 01_extract_dhs_gps_to_dta.R
├── 02_import_dhs_gps_and_prep.do
├── 03_assign_municipality_using_gps.do
├── 04_merge_gps_muni_to_outcomes.do
├── 05_build_shs_enrollment_exposure.do
├── 06_merge_shs_enrollment_exposure.do
├── 07_event_study.do
├── 08_diff_in_diff.do
├── 09_build_province_fertility_controls.do
├── 10_robustness_trend_absorbing.do
├── 11_robustness_windows_highschool.do
├── 12_robustness_hazard.do
├── 12b_robustness_hazard_graphs.do
├── 13_robustness_trimming_regions.do
├── 14_robustness_lopo.do
├── 15_robustness_placebo_did.do
├── 16_mechanism_check_human_capital.do
├── 17_mechanism_check_sexual_debut.do
├── 18_mechanism_check_intensity.do
├── 19_mechanism_check_contraception.do
├── LICENSE
└── README.md
```

---

## Data

The analysis uses restricted-access microdata and administrative sources, including the Philippine Demographic and Health Surveys and Department of Education records on Senior High School rollout. Raw data are not included. Access to DHS data requires approval from the DHS Program.

---

## Reproducibility

The scripts correspond to those used in the paper. Full reproducibility requires access to the underlying data and reconstruction of intermediate files. The repository is shared to make the empirical approach and workflow transparent.

---

## Author

Erika Lynet Salvador and Alex Coiov

---

## License

MIT License. See the `LICENSE` file for details.
