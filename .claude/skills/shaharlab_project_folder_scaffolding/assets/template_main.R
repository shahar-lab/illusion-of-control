rm(list = ls())

#### SETUP ####

library(here)
library(tidyverse)
library(brms)
library(bayesplot)
library(posterior)
library(ggdist)

# here::here() anchors to the .Rproj root regardless of the working directory,
# so paths resolve identically on any machine without setwd() gymnastics.
project_root  <- here::here()
code_dir      <- file.path(project_root, "analysis", "<folder_name>", "code")
artifacts_dir <- file.path(project_root, "analysis", "<folder_name>", "artifacts")
output_dir    <- file.path(project_root, "analysis", "<folder_name>", "output")



#### EXECUTE PIPELINE ####

# 1. Data Preparation
# Read clean data from the top-level data dir. Per the Artifacts Rule, never
# copy data into this analysis folder.
# df <- readr::read_csv(file.path(project_root, "data", "data_filtered", "your_file.csv"))
# source(file.path(code_dir, "prep_data.R"))

# 2. Model Fitting (Saves to artifacts/)
# source(file.path(code_dir, "fit_model.R"))

# 3. Diagnostics & Posterior Predictive Checks
# source(file.path(code_dir, "check_ppc.R"))

# 4. Plotting (Saves to output/)
# Posterior plots must use the /plot-posterior skill (shaharlab_plotting), not raw ggplot.
# source(file.path(code_dir, "plot_posteriors.R"))
