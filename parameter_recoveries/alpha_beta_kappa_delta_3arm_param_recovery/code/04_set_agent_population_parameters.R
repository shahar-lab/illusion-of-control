# reads: artifacts/simulation_config.RData · writes: artifacts/simulation_config.rds

#### LOAD TASK CONFIGURATION ####

load(file.path(artifacts_dir, "simulation_config.RData"))

#### AGENT POPULATION PARAMETERS ####

n_subjects  <- 200
mu_alpha    <- 0
sigma_alpha <- 1.25
mu_beta     <- 3.5
sigma_beta  <- 1.25
mu_kappa    <- 0
sigma_kappa <- 1.25
mu_delta    <- 0
sigma_delta <- 1.2

#### SAVE CONFIGURATION ####

simulation_config <- list(
  n_subjects  = n_subjects,
  n_trials    = n_trials,
  n_blocks    = n_blocks,
  n_arms      = n_arms,
  n_raffle    = n_raffle,
  rw_step_sd  = rw_step_sd,
  mu_alpha    = mu_alpha,
  sigma_alpha = sigma_alpha,
  mu_beta     = mu_beta,
  sigma_beta  = sigma_beta,
  mu_kappa    = mu_kappa,
  sigma_kappa = sigma_kappa,
  mu_delta    = mu_delta,
  sigma_delta = sigma_delta
)

saveRDS(simulation_config, file.path(artifacts_dir, "simulation_config.rds"))

message("Agent population configuration saved")
