# reads: nothing · writes: artifacts/cfg.rds, df.rds, population_params.csv, individual_params.csv

#### REWARD SCHEDULE ####

# Constant p(win) for every arm; seed_env kept for parity with the random-walk folders
set.seed(seed_env)
expvalues <- matrix(p_win, nrow = Narms, ncol = Ntrials)

cfg <- list(
  environment = environment_name,
  Nsubjects   = Nsubjects,
  Narms       = Narms,
  Ntrials     = Ntrials,
  expvalues   = expvalues
)


#### TRUE PARAMETERS ####

link_fun <- list(inv_logit = plogis, exp = exp, identity = identity)

# 200 draws per parameter in population_params row order, first Nsubjects kept,
# so smaller runs are nested in larger ones
set.seed(seed_params)
param_draws <- lapply(seq_len(nrow(population_params)), function(k) {
  link_fun[[population_params$link[k]]](rnorm(200, population_params$mu[k], population_params$sigma[k]))
})
names(param_draws) <- population_params$param

individual_params <- bind_cols(
  tibble(subject = 1:Nsubjects),
  as_tibble(lapply(param_draws, \(x) x[1:Nsubjects]))
)


#### SIMULATE BEHAVIOR ####

set.seed(seed_sim)
df <- vector("list", Nsubjects)
for (i in 1:Nsubjects) {
  params  <- unlist(individual_params[i, population_params$param])
  df[[i]] <- sim.block(subject = i, parameters = params, cfg = cfg)
}
df <- bind_rows(df)

stopifnot(nrow(df) == Nsubjects * Ntrials, length(df$Q_cards[[1]]) == Narms)

write_rds(cfg,               file.path(artifacts_dir, "cfg.rds"))
write_rds(df,                file.path(artifacts_dir, "df.rds"))
write_csv(population_params, file.path(artifacts_dir, "population_params.csv"))
write_csv(individual_params, file.path(artifacts_dir, "individual_params.csv"))

cat("Simulated", Nsubjects, "agents —", nrow(df), "total trials\n")
