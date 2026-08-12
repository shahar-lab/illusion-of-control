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

project_root  <- here::here()
code_dir      <- file.path(project_root, "analysis", "qval_and_decay_eval_raffle_param_recovery", "code")
artifacts_dir <- file.path(project_root, "analysis", "qval_and_decay_eval_raffle_param_recovery", "artifacts")
output_dir    <- file.path(project_root, "analysis", "qval_and_decay_eval_raffle_param_recovery", "output")
source(file.path(project_root, "models", "qval_and_decay_eval_raffle", "qval_and_decay_eval_raffle.R"))


#### EXECUTE PIPELINE ####

source(file.path(code_dir, "generate_data.R"))
source(file.path(code_dir, "plot_random_walk.R"))
source(file.path(code_dir, "plot_param_distributions.R"))
source(file.path(code_dir, "fit_stan.R"))
source(file.path(code_dir, "diagnostics.R"))
source(file.path(code_dir, "plot_recovery.R"))
source(file.path(code_dir, "plot_population_posteriors.R"))
source(file.path(code_dir, "summary_table.R"))
