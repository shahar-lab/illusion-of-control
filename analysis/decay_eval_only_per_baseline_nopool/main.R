rm(list = ls())

#### SETUP ####

library(here)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(tibble)
library(cmdstanr)
library(posterior)
library(bayesplot)
library(ggplot2)
library(ggdist)
library(patchwork)
library(gridExtra)

project_root  <- here::here()
folder_dir    <- file.path(project_root, "analysis", "decay_eval_only_per_baseline_nopool")
code_dir      <- file.path(folder_dir, "code")
artifacts_dir <- file.path(folder_dir, "artifacts")
output_dir    <- file.path(folder_dir, "output")
data_path     <- file.path(project_root, "data", "collected", "ioc-per-baseline")
model_dir     <- file.path(project_root, "models", "decay_eval_only_nopool")
model_name    <- "decay_eval_only_nopool"

# Sampling: the same as the n200_betaper_sd2 recovery
chains        <- 4
iter_warmup   <- 2000
iter_sampling <- 3000
seed_stan     <- 4004

key_to_card <- c(arrowleft = 1L, arrowup = 2L, arrowright = 3L)


#### EXECUTE PIPELINE ####

source(file.path(code_dir, "01_prep_data.R"))
source(file.path(code_dir, "02_fit_model.R"))
source(file.path(code_dir, "03_diagnostics.R"))
source(file.path(code_dir, "04_subject_estimates.R"))
source(file.path(code_dir, "05_plot_subject_posteriors.R"))
