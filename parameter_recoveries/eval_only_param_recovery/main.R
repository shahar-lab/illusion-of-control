rm(list = ls())

#### SETUP ####

library(here)
library(dplyr)
library(readr)
library(tibble)
library(tidyr)
library(cmdstanr)
library(posterior)
library(ggplot2)
library(patchwork)
library(bayesplot)
library(ggdist)
library(officer)
library(flextable)

# Run settings
run_name      <- "n200_betaper_sd2"      # legacy_n100 (old pipeline) | n200_betaper_sd2
Nsubjects     <- 200
iter_warmup   <- 2000
iter_sampling <- 3000

# Seeds: the same as the other recoveries
seed_params <- 1001
seed_env    <- 2002
seed_sim    <- 3003
seed_stan   <- 4004

# Environment
environment_name <- "p50"
Narms            <- 3
Ntrials          <- 150
p_win            <- 0.5
environment_description <- "all arms offered every trial; p(win) = 0.5 for every arm on every trial"

# Generating population, drawn in this row order
population_params <- tribble(
  ~param,      ~mu, ~sigma, ~link,
  "alpha_per", 0,   1.5,    "inv_logit",
  "beta_per",  0,   2,      "identity"
)

# Error figure: error in `target` against the true value of `by` (|by| when by_abs)
error_pairs <- tribble(
  ~target,     ~by,        ~by_abs,
  "alpha_per", "beta_per", TRUE
)

project_root  <- here::here()
folder_dir    <- file.path(project_root, "parameter_recoveries", "eval_only_param_recovery")
code_dir      <- file.path(folder_dir, "code")
artifacts_dir <- file.path(folder_dir, "artifacts", run_name)
output_dir    <- file.path(folder_dir, "output", run_name)
dir.create(artifacts_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(output_dir,    showWarnings = FALSE, recursive = TRUE)

model_name <- "eval_only"
source(file.path(project_root, "models", model_name, paste0(model_name, ".R")))


#### EXECUTE PIPELINE ####

source(file.path(code_dir, "01_generate_data.R"))
source(file.path(code_dir, "02_plot_reward_schedule.R"))
source(file.path(code_dir, "03_plot_param_distributions.R"))
source(file.path(code_dir, "04_fit_stan.R"))
source(file.path(code_dir, "05_diagnostics.R"))
source(file.path(code_dir, "06_plot_recovery.R"))
source(file.path(code_dir, "07_plot_population_posteriors.R"))
source(file.path(code_dir, "08_summary_table.R"))
source(file.path(code_dir, "09_write_report.R"))
