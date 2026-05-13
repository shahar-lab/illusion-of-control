rm(list = ls())

#### SETUP ####
library(dplyr)
library(ggplot2)
library(readr)

data_path <- "simulations/prob_both_machines/alpha_beta/data"
figs_path <- "simulations/prob_both_machines/alpha_beta/figs"

machine_colors <- c("1" = "#5599ff", "2" = "#55cc55", "3" = "#ff5555")

#### LOAD DATA ####
df <- read_csv(file.path(data_path, "df.csv"), show_col_types = FALSE)

#### COMPUTE PROBABILITIES AND IDENTIFY UNAVAILABLE MACHINE ####
df <- df |>
  mutate(
    trial_continuous    = (block - 1) * max(trial) + trial,
    p_left              = exp(beta * Q_left_card) / (exp(beta * Q_left_card) + exp(beta * Q_right_card)),
    p_right             = 1 - p_left,
    machine_unavailable = 6L - card_left - card_right,
    scarcity_label      = paste0("scarcity = ", scarcity * 100, "%")
  )

# One row per offered machine per trial
df_offered <- bind_rows(
  df |> transmute(trial_continuous, scarcity_label,
                  machine = factor(card_left),  p = p_left,
                  chosen  = ch_card == card_left),
  df |> transmute(trial_continuous, scarcity_label,
                  machine = factor(card_right), p = p_right,
                  chosen  = ch_card == card_right)
)

# One row per unavailable machine per trial
df_unavailable <- df |>
  transmute(trial_continuous, scarcity_label,
            machine = factor(machine_unavailable))

#### PLOT ####
figure <- ggplot() +
  # Line connecting each machine's probability across trials
  geom_line(
    data    = df_offered,
    mapping = aes(x = trial_continuous, y = p, colour = machine, group = machine),
    linewidth = 0.5,
    alpha     = 0.4
  ) +
  # Unchosen offered machine: open circle
  geom_point(
    data    = df_offered |> filter(!chosen),
    mapping = aes(x = trial_continuous, y = p, colour = machine),
    shape   = 1,
    size    = 1.8,
    alpha   = 0.7
  ) +
  # Chosen offered machine: filled circle, larger
  geom_point(
    data    = df_offered |> filter(chosen),
    mapping = aes(x = trial_continuous, y = p, colour = machine),
    shape   = 16,
    size    = 2.8,
    alpha   = 0.9
  ) +
  # Unavailable machine: × mark at bottom
  geom_point(
    data    = df_unavailable,
    mapping = aes(x = trial_continuous, colour = machine),
    y       = -0.05,
    shape   = 4,
    size    = 1.5,
    alpha   = 0.7
  ) +
  geom_hline(yintercept = 0.5, linetype = "dashed", colour = "grey60") +
  facet_wrap(~ scarcity_label, ncol = 3) +
  scale_colour_manual(values = machine_colors, name = "Machine") +
  scale_x_continuous(breaks = seq(0, 150, by = 25)) +
  scale_y_continuous(breaks = seq(0, 1, by = 0.25)) +
  coord_cartesian(ylim = c(-0.1, 1)) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position  = "bottom"
  ) +
  labs(
    title    = "Choice probabilities of both offered machines (alpha-beta model)",
    subtitle = "Filled = chosen  |  Open = unchosen  |  × = unavailable this trial",
    x        = "Trial",
    y        = "P(machine)"
  )

print(figure)

#### SAVE ####
dir.create(figs_path, recursive = TRUE, showWarnings = FALSE)
ggsave(file.path(figs_path, "prob_both_machines.pdf"), figure, width = 12, height = 4.5)
