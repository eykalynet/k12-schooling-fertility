# ------------------------------------------------------------
# Discrete-time hazard of first birth by age
# Final, clean plotting script (CSV -> grayscale + tight grid)
# ------------------------------------------------------------

library(tidyverse)

# ------------------------------------------------------------
# 1. Load hazard data from CSV
# ------------------------------------------------------------

hazard_df <- read_csv(
  "D:/ECON421/Results/output/fig/hazard_firstbirth_age.csv",
  show_col_types = FALSE
)

# Expected columns:
# age_at | hazard | se_h | ci_low | ci_high

# ------------------------------------------------------------
# 2. Basic checks (prevents silent errors)
# ------------------------------------------------------------

stopifnot(
  all(c("age_at", "hazard", "se_h", "ci_low", "ci_high") %in% names(hazard_df))
)

# ------------------------------------------------------------
# 3. Clean + create percentage-point series for plotting
# ------------------------------------------------------------

hazard_df <- hazard_df %>%
  transmute(
    age      = age_at,
    hazard   = hazard,
    lower    = pmax(ci_low, 0),
    upper    = pmax(ci_high, 0),
    # percentage points
    hazard_pp = 100 * hazard,
    lower_pp  = 100 * pmax(ci_low, 0),
    upper_pp  = 100 * pmax(ci_high, 0)
  )

# ------------------------------------------------------------
# 4. Plot
# ------------------------------------------------------------

ggplot(hazard_df, aes(x = age, y = hazard_pp)) +
  # dashed zero line
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.7, color = "black") +
  
  # CI error bars (grayscale)
  geom_errorbar(
    aes(ymin = lower_pp, ymax = upper_pp),
    width = 0.15,
    linewidth = 0.6,
    color = "black"
  ) +
  
  # points (grayscale)
  geom_point(size = 2.6, color = "black") +
  
  labs(
    title = "Discrete-time hazard of first birth by age",
    x = "Age",
    y = "Annual probability of first birth (percentage points)"
  ) +
  
  # TIGHT GRID: add minor breaks
  scale_x_continuous(
    breaks = seq(13, 49, by = 2),
    minor_breaks = seq(13, 49, by = 1)
  ) +
  scale_y_continuous(
    breaks = seq(0, 15, by = 2.5),
    minor_breaks = seq(0, 15, by = 0.5),
    limits = c(0, 15),
    expand = c(0, 0)
  ) +
  
  theme_minimal(base_size = 15) +
  theme(
    # tighter/cleaner grayscale grid
    panel.grid.major = element_line(color = "grey80", linewidth = 0.7),
    panel.grid.minor = element_line(color = "grey90", linewidth = 0.5),
    
    # thick rectangle
    panel.border = element_rect(color = "black", fill = NA, linewidth = 1.1)
  )
