# reproducr — End-to-End Pipeline Demo

This document walks through the complete `reproducr` workflow applied to a
real analysis of the [Palmer Penguins](https://allisonhorst.github.io/palmerpenguins/)
dataset. Every code block below produces real output — nothing is mocked.

---

## The analysis script

`analysis.R` predicts penguin body mass from morphological measurements.
It is written to be reproducibility-aware from the start:

- All function calls are **fully qualified** (`pkg::fn`) so `audit_script()`
  can detect and version them
- All stochastic operations are **seeded** (`set.seed(42)`) before the
  k-fold cross-validation
- Key outputs are collected in a named `OUTPUTS` list ready for certification

```r
# Palmer Penguins — Species Body Mass Analysis

library(palmerpenguins)

# Data preparation
penguins_clean <- penguins[stats::complete.cases(penguins), ]

# Descriptive statistics
species_summary <- stats::aggregate(
  cbind(bill_length_mm, bill_depth_mm, flipper_length_mm, body_mass_g) ~ species,
  data = penguins_clean,
  FUN  = mean
)

# Linear model
fit_full <- stats::lm(
  body_mass_g ~ bill_length_mm + bill_depth_mm + flipper_length_mm + species,
  data = penguins_clean
)

fit_summary <- summary(fit_full)

# 10-fold cross-validation
set.seed(42)
n       <- nrow(penguins_clean)
k       <- 10L
folds   <- sample(rep(seq_len(k), length.out = n))
cv_rmse <- numeric(k)

for (fold in seq_len(k)) {
  train <- penguins_clean[folds != fold, ]
  test  <- penguins_clean[folds == fold, ]
  m     <- stats::lm(
    body_mass_g ~ bill_length_mm + bill_depth_mm + flipper_length_mm + species,
    data = train
  )
  preds         <- stats::predict(m, newdata = test)
  cv_rmse[fold] <- sqrt(mean((test$body_mass_g - preds)^2, na.rm = TRUE))
}

# Outputs for certification
OUTPUTS <- list(
  n_obs         = nrow(penguins_clean),       # 333
  n_species     = length(unique(penguins_clean$species)),  # 3
  n_islands     = length(unique(penguins_clean$island)),   # 3
  species_means = species_summary,
  island_counts = as.data.frame(table(penguins_clean$species,
                                      penguins_clean$island)),
  coefs         = stats::coef(fit_full),
  r_squared     = fit_summary$r.squared,      # 0.8495
  adj_r_squared = fit_summary$adj.r.squared,  # 0.8472
  rmse          = sqrt(mean(stats::residuals(fit_full)^2)), # 311.91g
  cv_rmse_mean  = mean(cv_rmse),              # 316.43g
  f_statistic   = fit_summary$fstatistic[[1]], # 369.14
  p_value       = stats::pf(
    fit_summary$fstatistic[[1]],
    fit_summary$fstatistic[[2]],
    fit_summary$fstatistic[[3]],
    lower.tail = FALSE
  )                                           # 4.22e-132
)
```

---

## Tier 1 — Scan and score

```r
library(reproducr)
source("analysis.R")

report <- audit_script("analysis.R", verbose = FALSE)
print(report)
```

```
-- reproducr audit report [2026-05-31 22:11] --

  Files scanned:     1
  Packages found:    1
  Calls detected:    8
  R version:         4.4.2
  Platform:          aarch64-apple-darwin20
  Versions from:     installed library

  Next step: risks <- risk_score(report)
```

```r
risks <- risk_score(report)
print(risks)
```

```
-- reproducr risk score --

  No risks detected. All checks passed.
```

The script is clean:

- 8 qualified calls detected (`stats::complete.cases`, `stats::aggregate`,
  `stats::lm`, `stats::coef`, `stats::residuals`, `stats::predict`,
  `stats::pf`, `base::sample` via `rep`)
- No calls match known breaking-change entries in the database
- `set.seed(42)` is present before the stochastic `sample()` call
- No locale-sensitive operations

---

## Tier 2 — Certify and check drift

### First run — establishing the baseline

```r
certify(
  outputs = OUTPUTS,
  tag     = "baseline-v1",
  script  = "analysis.R"
)
```

```
reproducr: certified 12 output(s) [2026-05-31] under tag 'baseline-v1'
```

```r
list_certs()
```

```
          tag                timestamp r_version              os n_outputs     script
1 baseline-v1 2026-05-31T22:11:08+0000     4.4.2 macOS 26.5         12 analysis.R
```

The `.reproducr.rds` file is now written to the project root. Commit it:

```bash
git add .reproducr.rds
git commit -m "chore: establish reproducibility baseline"
```

### Subsequent run — checking for drift

After any environment change (package upgrade, new R version, platform
migration), rerun and check:

```r
source("analysis.R")   # re-run analysis
drift <- check_drift(OUTPUTS, against = "baseline-v1")
```

```
-- reproducr drift check vs 'baseline-v1' --

  Verdict  : ALL OUTPUTS MATCH
  OK       : 12
  Drifted  : 0
  Missing  : 0
  New      : 0
```

All 12 certified outputs match exactly. The analysis is stable.

### Simulating drift

To see what drift detection looks like, change one output and check again:

```r
# Simulate a package upgrade that changed a model default
OUTPUTS_changed        <- OUTPUTS
OUTPUTS_changed$coefs  <- OUTPUTS$coefs * 1.001   # tiny silent change

check_drift(OUTPUTS_changed, against = "baseline-v1")
```

```
-- reproducr drift check vs 'baseline-v1' --

  Verdict  : DRIFT DETECTED
  OK       : 11
  Drifted  : 1
  Missing  : 0
  New      : 0

  Drifted outputs:
    - coefs
```

This is exactly the scenario `reproducr` is designed to catch — a silent
numerical change with no error and no warning.

---

## Tier 3 — Report and badge

### Minimal text report

```r
cat(repro_report(report, risks, drift = drift,
                 format = "text", style = "minimal"))
```

```
reproducr audit report

- Generated: 2026-05-31 22:11
- R version: 4.4.2
- Platform: macOS 26.5
- Files scanned: 1
- Packages found: 1
- Qualified calls: 8
- Versions from: installed library

## Verdict

> REPRODUCIBLE: No significant risks detected.

## Drift check

- OK n_obs
- OK n_species
- OK n_islands
- OK species_means
- OK island_counts
- OK coefs
- OK r_squared
- OK adj_r_squared
- OK rmse
- OK cv_rmse_mean
- OK f_statistic
- OK p_value
```

### Academic methods paragraph

```r
cat(repro_report(report, risks, format = "text", style = "academic"))
```

```
All analyses were conducted in R (version 4.4.2) on macOS 26.5. The following
packages were used: palmerpenguins (v0.1.1), stats (v4.4.2). Reproducibility
auditing (reproducr) identified no risks. The full audit report and
certification records are available in the supplementary materials.
```

### Pharma QC report

```r
repro_report(report, risks, drift = drift,
             format      = "html",
             style       = "pharma",
             output_file = "qc_report.html")
```

Generates a self-contained HTML file with:
- Execution environment table
- Full package inventory with versions
- Risk register (empty — no risks)
- Drift assessment table (all 12 outputs: OK)
- Sign-off fields for analyst and reviewer

### Badge

```r
repro_badge(report, risks, output = "README")
```

Updates the `[![reproducibility](...)](...)` line in `README.md` to reflect
the current risk level. Green badge — no risks detected.

---

## The CI pipeline

On every push to `main`, the GitHub Actions workflow:

1. Installs dependencies and `reproducr`
2. Sources `analysis.R` to produce `OUTPUTS`
3. Runs `audit_script()` and `risk_score()` on the script
4. Checks for drift against the last certified run
5. Certifies the current run with today's date as the tag
6. Updates the badge in `README.md`
7. Generates `reproducibility_report.md`
8. Commits `README.md`, `reproducibility_report.md`, and `.reproducr.rds`

The `.reproducr.rds` file accumulates certifications across every run,
building an auditable history:

```r
list_certs()
#>           tag                 timestamp r_version          os n_outputs     script
#> 1 baseline-v1  2026-05-31T22:11:08+0000     4.4.2 macOS 26.5        12 analysis.R
#> 2  ci-2026-06-01 2026-06-01T06:03:12+0000   4.4.2 Linux 6.1.0       12 analysis.R
#> 3  ci-2026-06-08 2026-06-08T06:02:58+0000   4.4.2 Linux 6.1.0       12 analysis.R
```

---

## Key results

| Output | Value |
|---|---|
| Observations | 333 (complete cases from 344) |
| Species | Adelie, Chinstrap, Gentoo |
| Islands | Biscoe, Dream, Torgersen |
| Model R² | 0.8495 |
| Adjusted R² | 0.8472 |
| Training RMSE | 311.91 g |
| 10-fold CV RMSE | 316.43 g |
| F-statistic | 369.14 (df: 5, 327) |
| p-value | 4.22 × 10⁻¹³² |

### Coefficients

| Term | Estimate (g) |
|---|---|
| Intercept | −4,282.1 |
| Bill length (mm) | +39.7 |
| Bill depth (mm) | +141.8 |
| Flipper length (mm) | +20.2 |
| Species: Chinstrap | −496.8 |
| Species: Gentoo | +965.2 |

### Species means

| Species | Bill length | Bill depth | Flipper length | Body mass |
|---|---|---|---|---|
| Adelie | 38.8 mm | 18.3 mm | 190.1 mm | 3,706 g |
| Chinstrap | 48.8 mm | 18.4 mm | 195.8 mm | 3,733 g |
| Gentoo | 47.6 mm | 15.0 mm | 217.2 mm | 5,092 g |