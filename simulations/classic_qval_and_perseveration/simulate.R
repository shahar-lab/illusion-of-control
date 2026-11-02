rm(list = ls())

#### SETUP ####

library(dplyr)
library(tidyr)
library(tibble)
library(readr)
library(ggplot2)

source("models/classic_qval_and_perseveration/classic_qval_and_perseveration.R")

data_path <- "simulations/classic_qval_and_perseveration/data"
figs_path <- "simulations/classic_qval_and_perseveration/figs"
dir.create(data_path, showWarnings = FALSE, recursive = TRUE)
dir.create(figs_path, showWarnings = FALSE, recursive = TRUE)

Narms   <- 3
Ntrials <- 150
cfg     <- list(Narms = Narms, Ntrials = Ntrials, expvalues = matrix(0.5, Narms, Ntrials))


#### SOFTMAX BY HAND ####

# p(repeat the previous arm) for 3 arms, when the previous arm's Q is q_diff above the other two
softmax_table <- expand_grid(
  beta   = c(1, exp(1), 5),
  q_diff = c(-0.2, 0, 0.2),
  kappa  = c(-1, -0.5, -0.25, 0, 0.25, 0.5, 1)
) |>
  mutate(
    logit_prev = beta * q_diff + kappa,
    p_repeat   = exp(logit_prev) / (exp(logit_prev) + (Narms - 1))
  )

write_csv(softmax_table, file.path(data_path, "softmax_table.csv"))


#### TWO AGENTS ####

# Same alpha and beta, kappa at +1 and -1 SD of the proposed population N(0, 0.5)
two_agents <- tribble(
  ~subject, ~alpha, ~beta,  ~kappa,
  1,        0.5,    exp(1),  0.5,
  2,        0.5,    exp(1), -0.5
)

set.seed(3003)
df_two <- bind_rows(lapply(1:nrow(two_agents), function(i) {
  sim.block(subject = i, parameters = unlist(two_agents[i, c("alpha", "beta", "kappa")]), cfg = cfg)
}))

df_two_flat <- df_two |>
  mutate(
    Q1 = sapply(Q_cards, `[`, 1),    Q2 = sapply(Q_cards, `[`, 2),    Q3 = sapply(Q_cards, `[`, 3),
    p1 = sapply(prob_cards, `[`, 1), p2 = sapply(prob_cards, `[`, 2), p3 = sapply(prob_cards, `[`, 3)
  ) |>
  select(subject, alpha, beta, kappa, trial, prev_card, Q1, Q2, Q3, p1, p2, p3, ch_card, stay, reward, PE_rl)

write_csv(df_two_flat, file.path(data_path, "two_agents.csv"))


#### PROPOSED POPULATION ####

# 200 agents from the proposed generating population, stay rate against kappa
set.seed(1001)
population <- tibble(
  subject = 1:200,
  alpha   = plogis(rnorm(200, 0, 1.5)),
  beta    = exp(rnorm(200, 1, 0.5)),
  kappa   = rnorm(200, 0, 0.5)
)

set.seed(3003)
df_pop <- bind_rows(lapply(1:nrow(population), function(i) {
  sim.block(subject = i, parameters = unlist(population[i, c("alpha", "beta", "kappa")]), cfg = cfg)
}))

stay_by_agent <- df_pop |>
  filter(trial > 1) |>
  group_by(subject, alpha, beta, kappa) |>
  summarise(stay_rate = mean(stay), .groups = "drop")

write_csv(stay_by_agent, file.path(data_path, "stay_by_agent.csv"))

fig <- ggplot(stay_by_agent, aes(x = kappa, y = stay_rate, colour = beta)) +
  geom_hline(yintercept = 1 / Narms, linetype = "dashed", colour = "grey60") +
  geom_point(size = 2, alpha = 0.8) +
  scale_colour_viridis_c() +
  theme_minimal(base_size = 13) +
  theme(panel.grid.minor = element_blank()) +
  labs(x = "kappa", y = "Stay rate (repeat previous arm)", colour = "beta")

ggsave(file.path(figs_path, "stay_rate_by_kappa.png"), fig, width = 7, height = 5, dpi = 300, bg = "white")
