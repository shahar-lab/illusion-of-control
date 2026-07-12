#### SIMULATE BEHAVIORAL DATA ####

Nagents  <- 200
Narms    <- 3
Ntrials  <- 150

# Reward probability schedule: Narms x Ntrials matrix.
# All arms have a constant 0.5 win rate — unbiased 3-arm bandit.
expvalues <- matrix(rep(0.5, Narms * Ntrials), nrow = Narms)

# Sample true parameters from broad priors matching the Stan model's parameterization.
# alpha_rl, alpha_per: inv_logit-normal → bounded [0, 1]
# beta_rl:             log-normal        → bounded > 0
# beta_per:            normal            → unbounded
true_params <- tibble(
  subject   = 1:Nagents,
  alpha_rl  = plogis(rnorm(Nagents, 0, 1.5)),
  alpha_per = plogis(rnorm(Nagents, 0, 1.5)),
  beta_rl   = exp(rnorm(Nagents, 0, 1)),
  beta_per  = rnorm(Nagents, 0, 1.5)
)

cfg <- list(Narms = Narms, Ntrials = Ntrials, expvalues = expvalues)

sim_data <- lapply(1:Nagents, function(i) {
  params <- c(
    alpha_rl  = true_params$alpha_rl[i],
    alpha_per = true_params$alpha_per[i],
    beta_rl   = true_params$beta_rl[i],
    beta_per  = true_params$beta_per[i]
  )
  sim.block(subject = i, parameters = params, cfg = cfg)
}) |> bind_rows()

write_rds(sim_data,    file.path(artifacts_dir, "sim_data.rds"))
write_csv(true_params, file.path(artifacts_dir, "true_params.csv"))

cat("Simulated", Nagents, "agents —", nrow(sim_data), "total trials\n")
cat("Saved: sim_data.rds, true_params.csv\n")
