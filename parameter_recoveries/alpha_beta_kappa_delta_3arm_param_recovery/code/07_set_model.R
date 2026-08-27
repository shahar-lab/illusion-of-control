# reads: nothing · writes: artifacts/model_config.rds

#### MODEL CONFIGURATION ####

generative_model <- "alpha_beta_kappa_delta_3arm"
fitted_model <- "alpha_beta_kappa_delta_3arm"

#### SAVE CONFIGURATION ####

model_config <- list(
  generative_model = generative_model,
  fitted_model = fitted_model
)

saveRDS(model_config, file.path(artifacts_dir, "model_config.rds"))

message("Model configuration saved")
