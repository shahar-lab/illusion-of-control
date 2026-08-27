# reads: artifacts/simulation_config.rds, artifacts/model_config.rds, artifacts/cfg.rds, artifacts/true_parameters.rds · writes: artifacts/simulated_data.rds

#### LOAD CONFIGURATION ####

simulation_config <- readRDS(file.path(artifacts_dir, "simulation_config.rds"))
list2env(simulation_config, envir = environment())

model_config <- readRDS(file.path(artifacts_dir, "model_config.rds"))
list2env(model_config, envir = environment())

#### SETUP ####

source(file.path(project_root, "models", generative_model, paste0(generative_model, ".R")))

#### LOAD ARTIFACTS ####

cfg             <- readRDS(file.path(artifacts_dir, "cfg.rds"))
true_parameters <- readRDS(file.path(artifacts_dir, "true_parameters.rds"))

#### SIMULATE DATA FOR ALL SUBJECTS ####

simulated_data <- map_df(1:n_subjects, function(subj) {
  params <- list(
    alpha = true_parameters$alpha[subj],
    beta  = true_parameters$beta[subj],
    kappa = true_parameters$kappa[subj],
    delta = true_parameters$delta[subj]
  )
  sim_block(subject = subj, parameters = params, cfg = cfg)
})

#### SAVE OUTPUTS ####

saveRDS(simulated_data, file.path(artifacts_dir, "simulated_data.rds"))

message("Generated behavioral data for ", n_subjects, " subjects")
