rm(list = ls())

#### SETUP ####
library(dplyr)

source("models/alpha_beta/alpha_beta.r")

data_path <- "simulations/q_values/alpha_beta/data"

#### SIMULATE DATA ####
scarcity_values <- c(0.2, 0.5, 0.8)

agent_parameters <- c(
  alpha = 0.3,
  beta  = 4
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

  dfnew <- sim.block(
    subject    = 1,
    parameters = agent_parameters,
    cfg        = cfg
  )

  dfnew$scarcity <- scarcity
  df <- rbind(df, dfnew)
}

#### SAVE DATA ####
dir.create(data_path, recursive = TRUE, showWarnings = FALSE)
write.csv(df, file.path(data_path, "df.csv"), row.names = FALSE)
