rm(list = ls())

#### SETUP ####

library(here)
library(tidyverse)
library(cmdstanr)
library(posterior)
library(ggplot2)
library(patchwork)
library(ggdist)

project_root  <- here::here()
code_dir      <- file.path(project_root, "parameter_recoveries", "alpha_beta_raffle_50_50", "code")
artifacts_dir <- file.path(project_root, "parameter_recoveries", "alpha_beta_raffle_50_50", "artifacts")
output_dir    <- file.path(project_root, "parameter_recoveries", "alpha_beta_raffle_50_50", "output")

dir.create(artifacts_dir, showWarnings = FALSE)
dir.create(output_dir, showWarnings = FALSE)

#### SETTING THE TASK ####

# Step 1: Task parameters
source(file.path(code_dir, "01_set_task_parameters.R"))

# Step 2: Reward trajectories
source(file.path(code_dir, "02_generate_random_walk.R"))

# Step 3: Visualize rewards
source(file.path(code_dir, "03_visualize_random_walk.R"))


#### SETTING THE AGENTS POPULATION ####

# Step 4: Agent population parameters
source(file.path(code_dir, "04_set_agent_population_parameters.R"))

# Step 5: Agent parameters
source(file.path(code_dir, "05_generate_agents_parameters.R"))

# Step 6: Visualize agents
source(file.path(code_dir, "06_generate_parameters_visualization.R"))


#### GENERATE AND RECOVER ####

# Step 7: Model configuration
source(file.path(code_dir, "07_set_model.R"))

# Step 8: Simulate behavior
source(file.path(code_dir, "08_generate_behavior.R"))

# Step 9: Fit model
source(file.path(code_dir, "09_fit_model.R"))

# Step 10: Recovery plots
source(file.path(code_dir, "10_recovery_visualization.R"))
