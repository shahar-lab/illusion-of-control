rm(list = ls())

#### SETUP ####
library(dplyr)

source("models/alpha_beta_kappa_decay/alpha_beta_kappa_decay.r")

data_path <- "simulations/eff_of_scarcity_on_wsls/data"

#### SIMULATE DATA ####
scarcity_values <- seq(0, 1, by = 0.1)
Nsubjects_per_scarcity <- 10

agent_parameters <- c(
  alpha         = qlogis(0.3),
  beta          = 4,
  explore       = 0.05,
  decay_explore = qlogis(0.9)
)

cfg <- list(
  Nblocks   = 6,
  Ntrials   = 25,
  Narms     = 3,
  Nraffle   = 2,
  Ndims     = 2
)

df <- data.frame()

for (scarcity in scarcity_values) {
  cfg$expvalues <- matrix(scarcity, nrow = cfg$Narms, ncol = cfg$Ntrials)

  for (subject in 1:Nsubjects_per_scarcity) {
    dfnew <- sim.block(
      subject    = subject,
      parameters = agent_parameters,
      cfg        = cfg
    )

    dfnew$scarcity <- scarcity
    df <- rbind(df, dfnew)
  }
}

#### SAVE DATA ####
dir.create(data_path, recursive = TRUE, showWarnings = FALSE)
write.csv(df, file.path(data_path, "df.csv"), row.names = FALSE)
