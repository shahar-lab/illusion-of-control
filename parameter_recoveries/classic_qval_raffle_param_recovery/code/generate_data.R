#### SIMULATE BEHAVIORAL DATA ####
# reads: nothing · writes: artifacts/cfg.rds, df.rds, population_params.csv, individual_params.csv

Nsubjects <- 100
Narms     <- 8
Nraffle   <- 4
Ntrials   <- 200

expvalues <- matrix(rep(0.5, Narms * Ntrials), nrow = Narms)
cfg <- list(
  Nsubjects = Nsubjects,
  Narms     = Narms,
  Nraffle   = Nraffle,
  Ntrials   = Ntrials,
  expvalues = expvalues
)

population_params_list <- list(
  alpha_rl = list(mu = 0,     sigma = 0.75, link = "inv_logit"),
  beta_rl  = list(mu = -0.25, sigma = 0.75, link = "exp")
)
population_params <- bind_rows(population_params_list, .id = "param")

individual_params <- tibble(
  subject  = 1:cfg$Nsubjects,
  alpha_rl = plogis(rnorm(cfg$Nsubjects, population_params_list$alpha_rl$mu, population_params_list$alpha_rl$sigma)),
  beta_rl  = exp(rnorm(cfg$Nsubjects,    population_params_list$beta_rl$mu,  population_params_list$beta_rl$sigma))
)

df <- vector("list", cfg$Nsubjects)
for (i in 1:cfg$Nsubjects) {
  params <- c(
    alpha_rl = individual_params$alpha_rl[i],
    beta_rl  = individual_params$beta_rl[i]
  )
  df[[i]] <- sim.block(subject = i, parameters = params, cfg = cfg)
}
df <- bind_rows(df)

write_rds(cfg,               file.path(artifacts_dir, "cfg.rds"))
write_rds(df,                file.path(artifacts_dir, "df.rds"))
write_csv(population_params, file.path(artifacts_dir, "population_params.csv"))
write_csv(individual_params, file.path(artifacts_dir, "individual_params.csv"))

cat("Simulated", cfg$Nsubjects, "agents —", nrow(df), "total trials\n")
cat("Saved: cfg.rds, df.rds, population_params.csv, individual_params.csv\n")
