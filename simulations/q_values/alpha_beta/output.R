rm(list = ls())

#### SETUP ####
library(dplyr)
library(ggplot2)
library(tidyr)
library(readr)

data_path <- "simulations/q_values/alpha_beta/data"
figs_path <- "simulations/q_values/alpha_beta/figs"

machine_colors <- c("1" = "#5599ff", "2" = "#55cc55", "3" = "#ff5555")

#### LOAD DATA ####
df <- read_csv(file.path(data_path, "df.csv"), show_col_types = FALSE)

#### RECONSTRUCT ALL 3 Q-VALUES OVER TRIALS ####
# Each trial records Q of the two offered machines (card_left, card_right).
# For the unavailable machine, Q stays the same as the last time it was offered —
# so we fill forward from the last known value.
df <- df |>
  mutate(
    trial_continuous = (block - 1) * max(trial) + trial,
    scarcity_label   = paste0("scarcity = ", scarcity * 100, "%")
  )

Ntrials_total <- max(df$trial_continuous)

df_q <- bind_rows(
  df |> transmute(trial_continuous, scarcity_label, machine = factor(card_left),  Q = Q_left_card),
  df |> transmute(trial_continuous, scarcity_label, machine = factor(card_right), Q = Q_right_card)
) |>
  arrange(scarcity_label, machine, trial_continuous) |>
  group_by(scarcity_label, machine) |>
  complete(trial_continuous = 1:Ntrials_total) |>
  fill(Q, .direction = "down") |>
  mutate(Q = replace_na(Q, 0.5)) |>
  ungroup()

#### CHOICE/REWARD SEGMENTS FOR BOTTOM LINE ####
df_choices <- df |>
  transmute(
    trial_continuous,
    scarcity_label,
    machine    = factor(ch_card),
    linewidth  = if_else(reward == 1, 2.0, 0.5)
  )

#### PLOT ####
figure <- ggplot(df_q, aes(x = trial_continuous, y = Q, colour = machine)) +
  geom_segment(
    data    = df_choices,
    mapping = aes(x = trial_continuous - 0.5, xend = trial_continuous + 0.5,
                  y = -0.03, yend = -0.03,
                  colour = machine, linewidth = linewidth),
    show.legend = FALSE
  ) +
  geom_line(linewidth = 0.7) +
  facet_wrap(~ scarcity_label, ncol = 3) +
  scale_colour_manual(values = machine_colors, name = "Machine") +
  scale_linewidth_identity() +
  scale_x_continuous(breaks = seq(0, 150, by = 25)) +
  scale_y_continuous(breaks = seq(0, 1, by = 0.25)) +
  coord_cartesian(ylim = c(-0.06, 1)) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position  = "bottom"
  ) +
  labs(
    title    = "Q-values over trials (alpha-beta model)",
    subtitle = "Bottom line: chosen machine colour  |  thick = rewarded, thin = unrewarded",
    x        = "Trial",
    y        = "Q-value"
  )

print(figure)

#### SAVE ####
dir.create(figs_path, recursive = TRUE, showWarnings = FALSE)
ggsave(file.path(figs_path, "q_values.pdf"), figure, width = 12, height = 4)
