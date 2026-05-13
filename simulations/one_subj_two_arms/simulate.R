rm(list = ls())

#### SETUP ####
library(dplyr)

source("models/alpha_beta_kappa_decay/alpha_beta_kappa_decay.r")

data_path <- "simulations/one_subj_two_arms/data"

#### SIMULATE DATA ####
agent_parameters <- c(
  alpha         = qlogis(0.3),
  beta          = 4,
  explore       = 0.2,
  decay_explore = qlogis(0.9)
)

cfg <- list(
  Nblocks   = 6,
  Ntrials   = 25,
  Narms     = 2,
  Nraffle   = 2,
  Ndims     = 2,
  expvalues = matrix(0.5, nrow = 2, ncol = 25)
)

df <- sim.block(
  subject    = 1,
  parameters = agent_parameters,
  cfg        = cfg
)

#### SAVE DATA ####
dir.create(data_path, recursive = TRUE, showWarnings = FALSE)
write.csv(df, file.path(data_path, "df.csv"), row.names = FALSE)
