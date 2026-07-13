#### SIMULATE BEHAVIORAL DATA ####

Nagents  <- 200
Narms    <- 3
Ntrials  <- 150

# Population-level distribution parameters (the rnorm mu/sigma used to generate individuals).
# alpha_rl, alpha_per: inv_logit-normal → bounded [0, 1]
# beta_rl:             log-normal        → bounded > 0
# beta_per:            normal            → unbounded
population_params <- tibble(
  param = c("alpha_rl", "alpha_per", "beta_rl", "beta_per"),
  mu    = c(0, 0, 0, 0),
  sigma = c(1.5, 1.5, 1, 1.5),
  link  = c("inv_logit", "inv_logit", "exp", "identity")
)

# Individual-level samples drawn from population_params distributions.
individual_params <- tibble(
  subject   = 1:Nagents,
  alpha_rl  = plogis(rnorm(Nagents, 0, 1.5)),
  alpha_per = plogis(rnorm(Nagents, 0, 1.5)),
  beta_rl   = exp(rnorm(Nagents, 0, 1)),
  beta_per  = rnorm(Nagents, 0, 1.5)
)

# Reward probability schedule: Narms x Ntrials matrix.
# All arms have a constant 0.5 win rate — unbiased 3-arm bandit.
expvalues <- matrix(rep(0.5, Narms * Ntrials), nrow = Narms)
cfg <- list(Narms = Narms, Ntrials = Ntrials, expvalues = expvalues)

df <- vector("list", Nagents)
for (i in 1:Nagents) {
  params <- c(
    alpha_rl  = individual_params$alpha_rl[i],
    alpha_per = individual_params$alpha_per[i],
    beta_rl   = individual_params$beta_rl[i],
    beta_per  = individual_params$beta_per[i]
  )
  df[[i]] <- sim.block(subject = i, parameters = params, cfg = cfg)
}
df <- bind_rows(df)

write_rds(df,               file.path(artifacts_dir, "sim_data.rds"))
write_csv(population_params, file.path(artifacts_dir, "population_params.csv"))
write_csv(individual_params, file.path(artifacts_dir, "true_params.csv"))

cat("Simulated", Nagents, "agents —", nrow(df), "total trials\n")
cat("Saved: sim_data.rds, population_params.csv, true_params.csv\n")
