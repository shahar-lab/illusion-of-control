rm(list = ls())

#### SETUP ####
library(ggplot2)
library(dplyr)
library(tidyr)
library(readr)
library(ggdist)
library(patchwork)

draws_1 <- read_csv("bayesian_draws/posterior_draws_stay_switch_1back.csv", show_col_types = FALSE)
draws_2 <- read_csv("bayesian_draws/posterior_draws_stay_switch_2back.csv", show_col_types = FALSE)
draws_3 <- read_csv("bayesian_draws/posterior_draws_stay_switch_3back.csv", show_col_types = FALSE)

beta_lims   <- c(-0.4, 1.1)
p_stay_lims <- c(0.35, 0.75)

ann_1 <- sprintf("[median = %.2f, pd = %.1f%%]", median(draws_1$beta), mean(draws_1$beta > 0) * 100)
ann_2 <- sprintf("[median = %.2f, pd = %.1f%%]", median(draws_2$beta), mean(draws_2$beta > 0) * 100)
ann_3 <- sprintf("[median = %.2f, pd = %.1f%%]", median(draws_3$beta), mean(draws_3$beta > 0) * 100)

# ── 1-back ───────────────────────────────────────────────────────────────────
pA1 <- ggplot(draws_1, aes(x = beta, y = 0)) +
  stat_halfeye(fill = "gray75", color = NA, .width = 0.95,
    point_color = "black", point_fill = "black", point_size = 1.5,
    interval_color = "black", linewidth = 0.8) +
  geom_vline(xintercept = 0,                   linetype = "dashed", color = "gray40", linewidth = 0.5) +
  geom_vline(xintercept = median(draws_1$beta), linetype = "dotted", color = "gray50", linewidth = 0.5) +
  scale_x_continuous(limits = beta_lims, breaks = c(-0.5, 0, 0.5, 1.0)) +
  labs(x = NULL, y = NULL, title = "1-back") +
  theme_classic(base_size = 12) +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(), axis.line.y = element_blank())

draws_long_1 <- draws_1 |>
  select(p_stay_noreward, p_stay_reward) |>
  pivot_longer(everything(), names_to = "condition", values_to = "p_stay") |>
  mutate(condition = factor(condition,
    levels = c("p_stay_noreward", "p_stay_reward"),
    labels = c("Not rewarded", "Rewarded")
  ))

pB1 <- ggplot(draws_long_1, aes(x = p_stay, y = 0, fill = condition, color = condition)) +
  stat_halfeye(.width = 0.95, alpha = 0.85, point_size = 1.5, linewidth = 0.8) +
  scale_fill_manual(values  = c("Not rewarded" = "#E69F00", "Rewarded" = "#56B4E9")) +
  scale_color_manual(values = c("Not rewarded" = "#9A6B00", "Rewarded" = "#1A6FA8")) +
  scale_x_continuous(limits = p_stay_lims) +
  labs(x = NULL, y = NULL, fill = NULL, color = NULL, subtitle = ann_1) +
  theme_classic(base_size = 12) +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(), axis.line.y = element_blank(),
        legend.position = "right", plot.subtitle = element_text(size = 9, color = "gray40"))

# ── 2-back ───────────────────────────────────────────────────────────────────
pA2 <- ggplot(draws_2, aes(x = beta, y = 0)) +
  stat_halfeye(fill = "gray75", color = NA, .width = 0.95,
    point_color = "black", point_fill = "black", point_size = 1.5,
    interval_color = "black", linewidth = 0.8) +
  geom_vline(xintercept = 0,                   linetype = "dashed", color = "gray40", linewidth = 0.5) +
  geom_vline(xintercept = median(draws_2$beta), linetype = "dotted", color = "gray50", linewidth = 0.5) +
  scale_x_continuous(limits = beta_lims, breaks = c(-0.5, 0, 0.5, 1.0)) +
  labs(x = NULL, y = NULL, title = "2-back") +
  theme_classic(base_size = 12) +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(), axis.line.y = element_blank())

draws_long_2 <- draws_2 |>
  select(p_stay_noreward, p_stay_reward) |>
  pivot_longer(everything(), names_to = "condition", values_to = "p_stay") |>
  mutate(condition = factor(condition,
    levels = c("p_stay_noreward", "p_stay_reward"),
    labels = c("Not rewarded", "Rewarded")
  ))

pB2 <- ggplot(draws_long_2, aes(x = p_stay, y = 0, fill = condition, color = condition)) +
  stat_halfeye(.width = 0.95, alpha = 0.85, point_size = 1.5, linewidth = 0.8) +
  scale_fill_manual(values  = c("Not rewarded" = "#E69F00", "Rewarded" = "#56B4E9")) +
  scale_color_manual(values = c("Not rewarded" = "#9A6B00", "Rewarded" = "#1A6FA8")) +
  scale_x_continuous(limits = p_stay_lims) +
  labs(x = NULL, y = NULL, fill = NULL, color = NULL, subtitle = ann_2) +
  theme_classic(base_size = 12) +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(), axis.line.y = element_blank(),
        legend.position = "right", plot.subtitle = element_text(size = 9, color = "gray40"))

# ── 3-back ───────────────────────────────────────────────────────────────────
pA3 <- ggplot(draws_3, aes(x = beta, y = 0)) +
  stat_halfeye(fill = "gray75", color = NA, .width = 0.95,
    point_color = "black", point_fill = "black", point_size = 1.5,
    interval_color = "black", linewidth = 0.8) +
  geom_vline(xintercept = 0,                   linetype = "dashed", color = "gray40", linewidth = 0.5) +
  geom_vline(xintercept = median(draws_3$beta), linetype = "dotted", color = "gray50", linewidth = 0.5) +
  scale_x_continuous(limits = beta_lims, breaks = c(-0.5, 0, 0.5, 1.0)) +
  labs(x = "\u03b2 (reward effect on log-odds of staying)", y = NULL, title = "3-back") +
  theme_classic(base_size = 12) +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(), axis.line.y = element_blank())

draws_long_3 <- draws_3 |>
  select(p_stay_noreward, p_stay_reward) |>
  pivot_longer(everything(), names_to = "condition", values_to = "p_stay") |>
  mutate(condition = factor(condition,
    levels = c("p_stay_noreward", "p_stay_reward"),
    labels = c("Not rewarded", "Rewarded")
  ))

pB3 <- ggplot(draws_long_3, aes(x = p_stay, y = 0, fill = condition, color = condition)) +
  stat_halfeye(.width = 0.95, alpha = 0.85, point_size = 1.5, linewidth = 0.8) +
  scale_fill_manual(values  = c("Not rewarded" = "#E69F00", "Rewarded" = "#56B4E9")) +
  scale_color_manual(values = c("Not rewarded" = "#9A6B00", "Rewarded" = "#1A6FA8")) +
  scale_x_continuous(limits = p_stay_lims) +
  labs(x = "P(stay)", y = NULL, fill = NULL, color = NULL, subtitle = ann_3) +
  theme_classic(base_size = 12) +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(), axis.line.y = element_blank(),
        legend.position = "right", plot.subtitle = element_text(size = 9, color = "gray40"))

# ── Combine and save ──────────────────────────────────────────────────────────
combined <- (pA1 | pB1) / (pA2 | pB2) / (pA3 | pB3) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold"))

dir.create("figures", showWarnings = FALSE)
ggsave("figures/posterior_stay_switch_all_lags.png", combined,
       width = 10, height = 10, dpi = 150, bg = "white")

message("Saved: figures/posterior_stay_switch_all_lags.png")
