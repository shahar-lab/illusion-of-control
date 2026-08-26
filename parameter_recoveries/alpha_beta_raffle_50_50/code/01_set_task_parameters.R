# reads: nothing · writes: artifacts/simulation_config.RData

#### TASK PARAMETERS ####

n_trials    <- 200
n_blocks    <- 1
n_arms      <- 4
n_raffle    <- 2
rw_step_sd  <- 0.025

#### SAVE CONFIGURATION ####

save(
  n_trials, n_blocks, n_arms, n_raffle, rw_step_sd,
  file = file.path(artifacts_dir, "simulation_config.RData")
)

message("Task configuration saved")
