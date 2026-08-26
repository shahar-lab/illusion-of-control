# reads: artifacts/simulation_config.rds, artifacts/expvalues.rds · writes: artifacts/cfg.rds, artifacts/true_parameters.rds

#### LOAD SIMULATION CONFIGURATION ####

simulation_config <- readRDS(file.path(artifacts_dir, "simulation_config.rds"))
list2env(simulation_config, envir = environment())

#### LOAD RANDOM WALK ####

expvalues <- readRDS(file.path(artifacts_dir, "expvalues.rds"))

#### GENERATE TRUE PARAMETERS ####

true_parameters <- tibble(
  subject = 1:n_subjects,
  alpha   = plogis(rnorm(n_subjects, mu_alpha, sigma_alpha)),
  beta    = rnorm(n_subjects, mu_beta, sigma_beta)
)

#### BUILD CONFIGURATION FOR SIMULATION ####

cfg <- list(
  Narms     = n_arms,
  Ntrials   = n_trials,
  Nraffle   = n_raffle,
  Nblocks   = n_blocks,
  expvalues = expvalues
)

#### SAVE ARTIFACTS ####

saveRDS(cfg, file.path(artifacts_dir, "cfg.rds"))
saveRDS(true_parameters, file.path(artifacts_dir, "true_parameters.rds"))

message("Sample parameters generated")
