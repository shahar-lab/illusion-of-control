# reads: nothing · writes: artifacts/simulation_config.RData

#### TASK PARAMETERS ####

n_trials    <- 200
n_blocks    <- 1
n_arms      <- 3
n_raffle    <- n_arms  # no raffle: all arms offered every trial
rw_step_sd  <- 0.025

#### SAVE CONFIGURATION ####

save(
  n_trials, n_blocks, n_arms, n_raffle, rw_step_sd,
  file = file.path(artifacts_dir, "simulation_config.RData")
)

message("Task configuration saved")
