library(testthat)

# Source the analysis to get OUTPUTS in scope
source(here::here("analysis.R"))

test_that("analysis produces expected number of observations", {
  expect_equal(OUTPUTS$n_obs, 333L)
})

test_that("analysis covers all three species", {
  expect_equal(OUTPUTS$n_species, 3L)
})

test_that("analysis covers all three islands", {
  expect_equal(OUTPUTS$n_islands, 3L)
})

test_that("model R-squared is in a plausible range", {
  expect_true(OUTPUTS$r_squared > 0.85)
  expect_true(OUTPUTS$r_squared < 1.0)
})

test_that("model coefficients have expected names", {
  coef_names <- names(OUTPUTS$coefs)
  expect_true("(Intercept)"       %in% coef_names)
  expect_true("bill_length_mm"    %in% coef_names)
  expect_true("flipper_length_mm" %in% coef_names)
})

test_that("CV RMSE is within acceptable range", {
  expect_true(OUTPUTS$cv_rmse_mean < 400)
  expect_true(OUTPUTS$cv_rmse_mean > 0)
})

test_that("model p-value is highly significant", {
  expect_true(OUTPUTS$p_value < 0.001)
})

test_that("OUTPUTS list has all required keys", {
  required <- c(
    "n_obs", "n_species", "n_islands",
    "species_means", "island_counts",
    "coefs", "r_squared", "adj_r_squared",
    "rmse", "cv_rmse_mean",
    "f_statistic", "p_value"
  )
  expect_true(all(required %in% names(OUTPUTS)))
})
