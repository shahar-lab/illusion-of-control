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
run_name      <- "n200_walk3021"  # n200 only
Nsubjects     <- 200
iter_warmup   <- 2000
iter_sampling <- 3000

# Seeds: identical across all classic_qval recovery folders
seed_params <- 1001
seed_env    <- 3021  # random walk chosen by the researcher (balanced, several switches); 2002 in runs without a _walk suffix
seed_sim    <- 3003
seed_stan   <- 4004

# Environment
environment_name <- "randomwalk"
Narms            <- 3
Ntrials          <- 150
walk_sd          <- 0.05
environment_description <- "all arms offered every trial; p(win) per arm follows a Gaussian random walk, SD 0.05, clamped to [0, 1], starting at U(0, 1)"

# Generating population (alpha = plogis(N(mu, sigma)), beta = N(mu, sigma) on the natural scale)
mu_alpha    <- 0
sigma_alpha <- 1.5
mu_beta     <- 3
sigma_beta  <- 1.5

project_root  <- here::here()
folder_dir    <- file.path(project_root, "parameter_recoveries", "classic_qval_unbounded_beta_randomwalk_param_recovery")
code_dir      <- file.path(folder_dir, "code")
artifacts_dir <- file.path(folder_dir, "artifacts", run_name)
output_dir    <- file.path(folder_dir, "output", run_name)
dir.create(artifacts_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(output_dir,    showWarnings = FALSE, recursive = TRUE)

model_name <- "classic_qval_unbounded_beta"
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
