#### SIMULATE BEHAVIORAL DATA ####

Nsubjects <- 20
Narms     <- 3
Ntrials   <- 150

expvalues <- matrix(rep(0.5, Narms * Ntrials), nrow = Narms)

cfg <- list(
  Nsubjects = Nsubjects,
  Narms     = Narms,
  Ntrials   = Ntrials,
  expvalues = expvalues
)

# decay_rl, decay_h: inv_logit-normal -> bounded [0, 1]
# rho_rl, rho_h:     normal           -> unbounded
population_params_list <- list(
  decay_rl = list(mu = 0,    sigma = 0.75, link = "inv_logit"),
  decay_h  = list(mu = 0,    sigma = 0.75, link = "inv_logit"),
  rho_rl   = list(mu = 0.5,  sigma = 0.75, link = "identity"),
  rho_h    = list(mu = 0.5,  sigma = 0.75, link = "identity")
)
population_params <- bind_rows(population_params_list, .id = "param")

individual_params <- tibble(
  subject  = 1:cfg$Nsubjects,
  decay_rl = plogis(rnorm(cfg$Nsubjects, population_params_list$decay_rl$mu, population_params_list$decay_rl$sigma)),
  decay_h  = plogis(rnorm(cfg$Nsubjects, population_params_list$decay_h$mu,  population_params_list$decay_h$sigma)),
  rho_rl   = rnorm(cfg$Nsubjects,        population_params_list$rho_rl$mu,   population_params_list$rho_rl$sigma),
  rho_h    = rnorm(cfg$Nsubjects,        population_params_list$rho_h$mu,    population_params_list$rho_h$sigma)
)

df <- vector("list", cfg$Nsubjects)
for (i in 1:cfg$Nsubjects) {
  params <- c(
    decay_rl = individual_params$decay_rl[i],
    decay_h  = individual_params$decay_h[i],
    rho_rl   = individual_params$rho_rl[i],
    rho_h    = individual_params$rho_h[i]
  )
  df[[i]] <- sim.block(subject = i, parameters = params, cfg = cfg)
}
df <- bind_rows(df)

write_rds(cfg,               file.path(artifacts_dir, "cfg.rds"))
write_rds(df,                file.path(artifacts_dir, "df.rds"))
write_csv(population_params, file.path(artifacts_dir, "population_params.csv"))
write_csv(individual_params, file.path(artifacts_dir, "individual_params.csv"))

cat("Simulated", cfg$Nsubjects, "agents -", nrow(df), "total trials\n")
cat("Saved: cfg.rds, df.rds, population_params.csv, individual_params.csv\n")
