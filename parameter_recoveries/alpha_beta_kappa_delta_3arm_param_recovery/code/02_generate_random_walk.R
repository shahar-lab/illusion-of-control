# reads: artifacts/simulation_config.RData · writes: artifacts/expvalues.rds

#### LOAD SIMULATION CONFIGURATION ####

load(file.path(artifacts_dir, "simulation_config.RData"))

#### GENERATE REWARD TRAJECTORIES (FIXED 50/50) ####

expvalues <- matrix(0.5, nrow = n_arms, ncol = n_trials)

#### SAVE ARTIFACTS ####

saveRDS(expvalues, file.path(artifacts_dir, "expvalues.rds"))

message("Fixed 50/50 reward probabilities generated")
