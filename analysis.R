# Palmer Penguins — Species Body Mass Analysis
# reproducr-example: https://github.com/ndohpenngit/reproducr-example
#
# This script demonstrates a reproducr-aware analysis workflow:
#   - All qualified calls use pkg::fn namespace
#   - All stochastic calls are preceded by set.seed()
#   - Key outputs are collected in OUTPUTS for certification

# ---- dependencies -----------------------------------------------------------

library(palmerpenguins)

# ---- data preparation -------------------------------------------------------

# Remove incomplete cases
penguins_clean <- penguins[stats::complete.cases(penguins), ]

# Split by species for summaries
adelie    <- penguins_clean[penguins_clean$species == "Adelie",    ]
chinstrap <- penguins_clean[penguins_clean$species == "Chinstrap", ]
gentoo    <- penguins_clean[penguins_clean$species == "Gentoo",    ]

# ---- descriptive statistics -------------------------------------------------

species_summary <- stats::aggregate(
  cbind(bill_length_mm, bill_depth_mm, flipper_length_mm, body_mass_g) ~ species,
  data = penguins_clean,
  FUN  = mean
)

island_counts <- as.data.frame(table(penguins_clean$species, penguins_clean$island))
names(island_counts) <- c("species", "island", "n")

# ---- modelling --------------------------------------------------------------

# Linear model: predict body mass from bill and flipper measurements
fit_full <- stats::lm(
  body_mass_g ~ bill_length_mm + bill_depth_mm + flipper_length_mm + species,
  data = penguins_clean
)

fit_summary <- summary(fit_full)

# Cross-validated RMSE using k-fold
set.seed(42)
n          <- nrow(penguins_clean)
k          <- 10L
folds      <- sample(rep(seq_len(k), length.out = n))
cv_rmse    <- numeric(k)

for (fold in seq_len(k)) {
  train <- penguins_clean[folds != fold, ]
  test  <- penguins_clean[folds == fold, ]
  m     <- stats::lm(
    body_mass_g ~ bill_length_mm + bill_depth_mm + flipper_length_mm + species,
    data = train
  )
  preds       <- stats::predict(m, newdata = test)
  cv_rmse[fold] <- sqrt(mean((test$body_mass_g - preds)^2, na.rm = TRUE))
}

# ---- key outputs ------------------------------------------------------------
# These are the values that reproducr will hash and certify.
# Any change to these after certification will be flagged as drift.

OUTPUTS <- list(
  # Data properties
  n_obs          = nrow(penguins_clean),
  n_species      = length(unique(penguins_clean$species)),
  n_islands      = length(unique(penguins_clean$island)),

  # Descriptive statistics
  species_means  = species_summary,
  island_counts  = island_counts,

  # Model results
  coefs          = stats::coef(fit_full),
  r_squared      = fit_summary$r.squared,
  adj_r_squared  = fit_summary$adj.r.squared,
  rmse           = sqrt(mean(stats::residuals(fit_full)^2)),
  cv_rmse_mean   = mean(cv_rmse),

  # Inference
  f_statistic    = fit_summary$fstatistic[[1]],
  p_value        = stats::pf(
    fit_summary$fstatistic[[1]],
    fit_summary$fstatistic[[2]],
    fit_summary$fstatistic[[3]],
    lower.tail = FALSE
  )
)
