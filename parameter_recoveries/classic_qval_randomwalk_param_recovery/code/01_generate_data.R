# reads: nothing · writes: artifacts/cfg.rds, df.rds, population_params.csv, individual_params.csv

#### REWARD SCHEDULE ####

# Gaussian random walk per arm, clamped to [0, 1]; one walk shared by all subjects
set.seed(seed_env)
expvalues      <- matrix(NA_real_, nrow = Narms, ncol = Ntrials)
expvalues[, 1] <- runif(Narms, 0, 1)

for (t in 2:Ntrials) {
  step           <- expvalues[, t - 1] + rnorm(Narms, 0, walk_sd)
  expvalues[, t] <- pmin(pmax(step, 0), 1)
}

cfg <- list(
  environment = environment_name,
  Nsubjects   = Nsubjects,
  Narms       = Narms,
  Ntrials     = Ntrials,
  expvalues   = expvalues
)


#### TRUE PARAMETERS ####

population_params <- tibble(
  param = c("alpha", "beta"),
  mu    = c(mu_alpha, mu_beta),
  sigma = c(sigma_alpha, sigma_beta),
  link  = c("inv_logit", "exp")
)

# 200 draws per parameter, first Nsubjects kept, so smaller runs are nested in larger ones
set.seed(seed_params)
alpha_draws <- plogis(rnorm(200, mu_alpha, sigma_alpha))
beta_draws  <- exp(rnorm(200, mu_beta, sigma_beta))

individual_params <- tibble(
  subject = 1:Nsubjects,
  alpha   = alpha_draws[1:Nsubjects],
  beta    = beta_draws[1:Nsubjects]
)


#### SIMULATE BEHAVIOR ####

set.seed(seed_sim)
df <- vector("list", Nsubjects)
for (i in 1:Nsubjects) {
  params  <- c(alpha = individual_params$alpha[i], beta = individual_params$beta[i])
  df[[i]] <- sim.block(subject = i, parameters = params, cfg = cfg)
}
df <- bind_rows(df)

stopifnot(nrow(df) == Nsubjects * Ntrials, length(df$Q_cards[[1]]) == Narms)

write_rds(cfg,               file.path(artifacts_dir, "cfg.rds"))
write_rds(df,                file.path(artifacts_dir, "df.rds"))
write_csv(population_params, file.path(artifacts_dir, "population_params.csv"))
write_csv(individual_params, file.path(artifacts_dir, "individual_params.csv"))

cat("Simulated", Nsubjects, "agents —", nrow(df), "total trials\n")
