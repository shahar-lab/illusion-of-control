rm(list = ls())

#### SETUP ####
library(dplyr)
library(ggplot2)
library(patchwork)
library(readr)

data_path <- "simulations/eff_of_scarcity_on_wsls/data"
figs_path <- "simulations/eff_of_scarcity_on_wsls/figs"

#### LOAD DATA ####
df <- read_csv(file.path(data_path, "df_uniform.csv"), show_col_types = FALSE)

subject_counts <- df |>
  group_by(scarcity) |>
  summarise(
    Nsubjects = n_distinct(subject),
    .groups   = "drop"
  )

scarcity_values <- sort(unique(df$scarcity))

#### CODE STAY BEHAVIOR ####
df <- df |>
  arrange(subject, scarcity, block, trial) |>
  group_by(subject, scarcity, block) |>
  mutate(
    previous_selected_arm = lag(ch_card),
    reward_oneback        = lag(reward),
    previous_reoffered    = previous_selected_arm == card_left | previous_selected_arm == card_right,
    stay_ch               = ch_card == previous_selected_arm
  ) |>
  ungroup()

df_reoffered <- df |>
  filter(previous_reoffered)

#### SUMMARISE PSTAY ####
subject_means <- df_reoffered |>
  filter(!is.na(reward_oneback)) |>
  group_by(subject, scarcity, reward_oneback) |>
  summarise(
    p_stay = mean(stay_ch),
    .groups = "drop"
  ) |>
  mutate(
    reward_oneback = factor(
      reward_oneback,
      levels = c(0, 1),
      labels = c("unrewarded", "rewarded")
    ),
    scarcity_label = factor(scarcity, levels = scarcity_values)
  )

scarcity_means <- subject_means |>
  group_by(scarcity_label, reward_oneback) |>
  summarise(
    mean_p_stay = mean(p_stay),
    sd_p_stay   = sd(p_stay),
    .groups     = "drop"
  )

subject_reward_effects <- subject_means |>
  group_by(subject, scarcity, scarcity_label) |>
  summarise(
    reward_effect = mean(p_stay[reward_oneback == "rewarded"], na.rm = TRUE) -
      mean(p_stay[reward_oneback == "unrewarded"], na.rm = TRUE),
    .groups = "drop"
  ) |>
  filter(!is.na(reward_effect))

scarcity_reward_effects <- subject_reward_effects |>
  group_by(scarcity, scarcity_label) |>
  summarise(
    mean_reward_effect = mean(reward_effect),
    se_reward_effect   = sd(reward_effect) / sqrt(n()),
    .groups            = "drop"
  )

#### PLOT ####
plots <- list()

for (i in seq_along(scarcity_values)) {
  scarcity_level <- scarcity_values[i]

  scarcity_subject_means <- subject_means |>
    filter(scarcity_label == scarcity_level)

  subject_line_data <- scarcity_subject_means |>
    group_by(subject) |>
    filter(n() > 1) |>
    ungroup()

  scarcity_group_means <- scarcity_means |>
    filter(scarcity_label == scarcity_level)

  Nsubjects <- subject_counts |>
    filter(scarcity == as.numeric(scarcity_level)) |>
    pull(Nsubjects)

  plots[[i]] <- ggplot(
    scarcity_subject_means,
    aes(x = reward_oneback, y = p_stay, group = subject)
  ) +
    geom_line(data = subject_line_data, colour = "grey70", alpha = 0.6) +
    geom_point(
      colour = "#4477AA",
      alpha = 0.65,
      size = 2,
      position = position_jitter(width = 0.04, height = 0)
    ) +
    geom_pointrange(
      data = scarcity_group_means,
      aes(
        x = reward_oneback,
        y = mean_p_stay,
        ymin = mean_p_stay - sd_p_stay,
        ymax = mean_p_stay + sd_p_stay
      ),
      inherit.aes = FALSE,
      colour = "#E69F00",
      linewidth = 0.8,
      size = 0.7
    ) +
    scale_x_discrete(drop = FALSE) +
    scale_y_continuous(breaks = seq(0, 1, by = 0.25)) +
    coord_cartesian(ylim = c(0, 1)) +
    theme_minimal(base_size = 13) +
    theme(panel.grid.minor = element_blank()) +
    labs(
      title = paste("scarcity =", scarcity_level, ", n =", Nsubjects),
      x     = "reward_oneback",
      y     = "p_stay"
    )
}

figure_1 <- wrap_plots(plots, ncol = 4) +
  plot_annotation(title = "Figure 1 — uniform parameters")

print(figure_1)

#### SAVE FIGURE ####
dir.create(figs_path, recursive = TRUE, showWarnings = FALSE)
ggsave(file.path(figs_path, "figure_1_uniform.pdf"), figure_1, width = 12, height = 9)

#### FIGURE 2 ####
figure_2 <- ggplot(
  subject_reward_effects,
  aes(x = scarcity, y = reward_effect)
) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey60") +
  geom_point(
    colour = "#4477AA",
    alpha = 0.65,
    size = 2,
    position = position_jitter(width = 0.01, height = 0)
  ) +
  geom_pointrange(
    data = scarcity_reward_effects,
    aes(
      x = scarcity,
      y = mean_reward_effect,
      ymin = mean_reward_effect - se_reward_effect,
      ymax = mean_reward_effect + se_reward_effect
    ),
    inherit.aes = FALSE,
    colour = "#E69F00",
    linewidth = 0.8,
    size = 0.7
  ) +
  scale_x_continuous(breaks = scarcity_values) +
  scale_y_continuous(breaks = seq(-1, 1, by = 0.25)) +
  coord_cartesian(ylim = c(-1, 1)) +
  theme_minimal(base_size = 13) +
  theme(panel.grid.minor = element_blank()) +
  labs(
    title = "Figure 2 — uniform parameters",
    x     = "scarcity",
    y     = "reward effect on p_stay"
  )

print(figure_2)

ggsave(file.path(figs_path, "figure_2_uniform.pdf"), figure_2, width = 8, height = 5)
