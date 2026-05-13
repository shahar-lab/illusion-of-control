rm(list = ls())

#### SETUP ####
library(dplyr)
library(ggplot2)
library(readr)
library(tidyr)

data_path <- "simulations/choice_prob_over_trials/alpha_beta/data"
figs_path <- "simulations/choice_prob_over_trials/alpha_beta/figs"

#### LOAD DATA ####
df <- read_csv(file.path(data_path, "df.csv"), show_col_types = FALSE)

#### COMPUTE P(CHOSEN), EMPIRICAL REWARD RATE, CONTINUOUS TRIAL ####
df <- df |>
  mutate(
    trial_continuous = (block - 1) * max(trial) + trial,
    p_chosen         = exp(beta * Q_ch_card) / (exp(beta * Q_ch_card) + exp(beta * Q_unch_card)),
    scarcity_label   = paste0("scarcity = ", scarcity * 100, "%")
  ) |>
  arrange(subject, scarcity, trial_continuous) |>
  group_by(subject, scarcity, ch_card) |>
  mutate(
    empirical_rate = lag(cumsum(reward), default = 0) / (row_number() - 1)
  ) |>
  ungroup()

df_long <- df |>
  select(trial_continuous, scarcity_label, p_chosen, empirical_rate) |>
  pivot_longer(
    cols      = c(p_chosen, empirical_rate),
    names_to  = "measure",
    values_to = "value"
  ) |>
  mutate(measure = factor(
    measure,
    levels = c("p_chosen", "empirical_rate"),
    labels = c("P(chosen)", "Empirical reward rate")
  ))

#### PLOT ####
figure <- ggplot(df_long, aes(x = trial_continuous, y = value, colour = measure)) +
  geom_line(linewidth = 0.7) +
  geom_hline(yintercept = 0.5, linetype = "dashed", colour = "grey60") +
  facet_wrap(~ scarcity_label, ncol = 3) +
  scale_colour_manual(values = c("P(chosen)" = "#4477AA", "Empirical reward rate" = "#E69F00")) +
  scale_x_continuous(breaks = seq(0, 150, by = 25)) +
  scale_y_continuous(breaks = seq(0, 1, by = 0.25)) +
  coord_cartesian(ylim = c(0, 1)) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid.minor = element_blank(),
    legend.title     = element_blank(),
    legend.position  = "bottom"
  ) +
  labs(
    title = "Choice probability over trials (alpha-beta model)",
    x     = "Trial",
    y     = "Value"
  )

print(figure)

#### SAVE ####
dir.create(figs_path, recursive = TRUE, showWarnings = FALSE)
ggsave(file.path(figs_path, "choice_prob_over_trials.pdf"), figure, width = 12, height = 4)
