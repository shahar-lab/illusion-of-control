# Reference: Priors and MCMC Sampling

**MANDATORY:** You must not run or compile a `brms` model until the user has explicitly approved the formula and the specific priors in Phase 1. Do not silently guess priors.

This document outlines how to structure the R script that defines the priors, runs the MCMC sampling, and saves the resulting model as an artifact.

## Standard Workflow

1. **Load dependencies:** `brms`, `here`, and `readr`.
2. **Load data:** Read the cleaned data directly from the top-level `data/data_filtered/` directory using `here::here()`. Do not copy data into the local folder.
3. **Define Priors:** Translate the user-approved priors into a `brms::prior()` vector.
4. **Fit the Model:** Run `brm()`. Standardize on 4 chains, 2000 iter, 1000 warmup. Use the `cmdstanr` backend if available.
5. **Save Artifact:** Save the fitted model `.rds` object to the local `artifacts/` folder.

---

## Example 1: Simple / Multiple Regression
*(Use this pattern for standard fixed-effects models)*

```r
# Load libraries
library(brms)
library(here)
library(readr)

# 1. Load Data
# IMPORTANT: Read from the top-level filtered data folder using 'here'
df <- read_csv(here::here("data", "data_filtered", "clean_dataset.csv"))

# 2. Define User-Approved Priors
# Use exactly what the user approved in Phase 1.
my_priors <- c(
  prior(normal(0, 10), class = "Intercept"),
  prior(normal(0, 5), class = "b", coef = "predictor1"),
  prior(cauchy(0, 2), class = "sigma")
)

# 3. Fit the Model
model_fit <- brm(
  formula = outcome ~ 1 + predictor1 + predictor2,
  data = df,
  family = gaussian(),
  prior = my_priors,
  chains = 4,
  iter = 2000,
  warmup = 1000,
  backend = "cmdstanr",
  cores = 4,
  seed = 1234
)

# 4. Save Artifact
# Save the heavy .rds file to the dedicated local artifacts folder
saveRDS(model_fit, here::here("analysis", "<folder_name>", "artifacts", "model_fit.rds"))
```

## Example 2: Hierarchical / Mixed-Effects
*(Use this pattern when dealing with random intercepts/slopes)*

```r

# Load libraries
library(brms)
library(here)
library(readr)

df <- read_csv(here::here("data", "data_filtered", "clean_dataset_repeated.csv"))

my_priors <- c(
  prior(normal(0, 5), class = "Intercept"),
  prior(normal(0, 2), class = "b"),
  prior(cauchy(0, 1), class = "sd"), # Prior for random effects SD
  prior(lkj(2), class = "cor")       # Prior for random effects correlation
)

model_hierarchical <- brm(
  formula = outcome ~ 1 + predictor + (1 + predictor | subject_id),
  data = df,
  family = gaussian(),
  prior = my_priors,
  chains = 4,
  iter = 2000,
  warmup = 1000,
  backend = "cmdstanr",
  cores = 4,
  seed = 1234
)

saveRDS(model_hierarchical, here::here("analysis", "<folder_name>", "artifacts", "model_hierarchical.rds"))