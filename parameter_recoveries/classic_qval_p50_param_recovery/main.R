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
library(officer)
library(flextable)

# Run settings
run_name      <- "n35"          # sanity_n20 | n35 | n200
Nsubjects     <- 35
iter_warmup   <- 2000
iter_sampling <- 2000

# Seeds: identical across classic_qval_randomwalk and classic_qval_p50
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

# Generating population (alpha = plogis(N(mu, sigma)), beta = exp(N(mu, sigma)))
mu_alpha    <- 0
sigma_alpha <- 0.85
mu_beta     <- -0.25
sigma_beta  <- 0.75

project_root  <- here::here()
folder_dir    <- file.path(project_root, "parameter_recoveries", "classic_qval_p50_param_recovery")
code_dir      <- file.path(folder_dir, "code")
artifacts_dir <- file.path(folder_dir, "artifacts", run_name)
output_dir    <- file.path(folder_dir, "output", run_name)
dir.create(artifacts_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(output_dir,    showWarnings = FALSE, recursive = TRUE)

model_name <- "classic_qval"
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
