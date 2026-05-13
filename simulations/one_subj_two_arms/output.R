rm(list = ls())

#### SETUP ####
library(dplyr)
library(ggplot2)
library(patchwork)
library(readr)
library(tidyr)

data_path <- "simulations/one_subj_two_arms/data"
figs_path <- "simulations/one_subj_two_arms/figs"

machine_colors <- c("1" = "#4477AA", "2" = "#EE6677")

#### LOAD DATA ####
df <- read_csv(file.path(data_path, "df.csv"), show_col_types = FALSE) |>
  mutate(trial_continuous = (block - 1) * max(trial) + trial)

#### COMPUTE VALUES AND CHOICE PROBABILITIES ####
df_values <- bind_rows(
  df |>
    transmute(
      trial_continuous,
      machine = factor(card_left),
      Q       = Q_left_card,
      E       = if_else(ch_key == 1, E_ch_card, E_unch_card),
      beta
    ),
  df |>
    transmute(
      trial_continuous,
      machine = factor(card_right),
      Q       = Q_right_card,
      E       = if_else(ch_key == 2, E_ch_card, E_unch_card),
      beta
    )
) |>
  group_by(trial_continuous) |>
  mutate(choice_prob = exp(beta * Q + E) / sum(exp(beta * Q + E))) |>
  ungroup()

df_diff <- df_values |>
  select(trial_continuous, machine, Q, choice_prob) |>
  pivot_wider(
    names_from  = machine,
    values_from = c(Q, choice_prob),
    names_prefix = "arm_"
  ) |>
  mutate(
    deltaQ           = Q_arm_1 - Q_arm_2,
    diff_choice_prob = choice_prob_arm_1 - choice_prob_arm_2
  )

#### PLOT ####
q_values_plot <- ggplot(df_values, aes(x = trial_continuous, y = Q, colour = machine)) +
  geom_line(linewidth = 0.8) +
  scale_colour_manual(values = machine_colors, name = "Arm") +
  scale_y_continuous(breaks = seq(0, 1, by = 0.25)) +
  coord_cartesian(ylim = c(0, 1)) +
  theme_minimal(base_size = 13) +
  theme(panel.grid.minor = element_blank()) +
  labs(
    title = "Q-values",
    x     = "Trial",
    y     = "Q"
  )

choice_prob_plot <- ggplot(df_values, aes(x = trial_continuous, y = choice_prob, colour = machine)) +
  geom_line(linewidth = 0.8) +
  geom_hline(yintercept = 0.5, linetype = "dashed", colour = "grey60") +
  scale_colour_manual(values = machine_colors, name = "Arm") +
  scale_y_continuous(breaks = seq(0, 1, by = 0.25)) +
  coord_cartesian(ylim = c(0, 1)) +
  theme_minimal(base_size = 13) +
  theme(panel.grid.minor = element_blank()) +
  labs(
    title = "Choice probability",
    x     = "Trial",
    y     = "P(choose arm)"
  )

delta_q_plot <- ggplot(df_diff, aes(x = trial_continuous, y = deltaQ)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey60") +
  geom_line(colour = "#4477AA", linewidth = 0.8) +
  theme_minimal(base_size = 13) +
  theme(panel.grid.minor = element_blank()) +
  labs(
    title = "Delta Q",
    x     = "Trial",
    y     = "Q arm 1 - Q arm 2"
  )

diff_choice_prob_plot <- ggplot(df_diff, aes(x = trial_continuous, y = diff_choice_prob)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey60") +
  geom_line(colour = "#4477AA", linewidth = 0.8) +
  scale_y_continuous(breaks = seq(-1, 1, by = 0.5)) +
  coord_cartesian(ylim = c(-1, 1)) +
  theme_minimal(base_size = 13) +
  theme(panel.grid.minor = element_blank()) +
  labs(
    title = "Choice probability difference",
    x     = "Trial",
    y     = "P arm 1 - P arm 2"
  )

figure <- (q_values_plot + choice_prob_plot) / (delta_q_plot + diff_choice_prob_plot) +
  plot_annotation(title = "One subject, two arms")

print(figure)

#### SAVE FIGURE ####
dir.create(figs_path, recursive = TRUE, showWarnings = FALSE)
ggsave(file.path(figs_path, "one_subj_two_arms.pdf"), figure, width = 10, height = 7)
