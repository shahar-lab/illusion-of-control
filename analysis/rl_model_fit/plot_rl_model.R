rm(list = ls())

#### SETUP ####
library(ggplot2)
library(ggdist)
library(dplyr)
library(tidyr)
library(readr)
library(patchwork)

DRAWS_DIR <- "bayesian_draws"

draws_group <- read_csv(file.path(DRAWS_DIR, "posterior_draws_group.csv"), show_col_types = FALSE)
draws_sbj   <- read_csv(file.path(DRAWS_DIR, "posterior_draws_subject.csv"), show_col_types = FALSE)
pmap        <- read_csv(file.path(DRAWS_DIR, "participant_map.csv"),         show_col_types = FALSE)

dir.create("figures", showWarnings = FALSE)

# Transform group-level means to natural parameter scales
draws_group <- draws_group |>
  mutate(
    alpha_group = plogis(mu_alpha),
    beta_group  = exp(mu_beta),
    kappa_group = mu_kappa,
    decay_group = plogis(mu_decay)
  )

posterior_theme <- theme_minimal(base_size = 13) +
  theme(
    panel.grid   = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y  = element_blank(),
    axis.line.x  = element_line(colour = "grey30")
  )

#### GROUP-LEVEL POSTERIORS ####

# Panel A: alpha (learning rate)
med_alpha <- median(draws_group$alpha_group)

pA <- ggplot(draws_group, aes(x = alpha_group, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = med_alpha, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  annotate("text", x = med_alpha, y = Inf,
    label = sprintf("[median = %.2f]", med_alpha),
    hjust = -0.07, vjust = 1.4, size = 3.2, colour = "grey40") +
  labs(x = "\u03b1 (learning rate)") +
  coord_cartesian(ylim = c(0, 1.3), clip = "off") +
  posterior_theme

# Panel B: beta (inverse temperature)
med_beta <- median(draws_group$beta_group)

pB <- ggplot(draws_group, aes(x = beta_group, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = med_beta, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  annotate("text", x = med_beta, y = Inf,
    label = sprintf("[median = %.2f]", med_beta),
    hjust = -0.07, vjust = 1.4, size = 3.2, colour = "grey40") +
  labs(x = "\u03b2 (inverse temperature)") +
  coord_cartesian(ylim = c(0, 1.3), clip = "off") +
  posterior_theme

# Panel C: kappa (perseveration — effect, include zero)
med_kappa    <- median(draws_group$kappa_group)
pd_kappa     <- max(mean(draws_group$kappa_group > 0), mean(draws_group$kappa_group < 0)) * 100
max_abs_kappa <- max(abs(range(draws_group$kappa_group)))

pC <- ggplot(draws_group, aes(x = kappa_group, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = 0,         linetype = "dashed", colour = "grey40", linewidth = 0.7) +
  geom_vline(xintercept = med_kappa, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  annotate("text", x = med_kappa, y = Inf,
    label = sprintf("[median = %.2f, pd = %.1f%%]", med_kappa, pd_kappa),
    hjust = -0.07, vjust = 1.4, size = 3.2, colour = "grey40") +
  labs(x = "\u03ba (perseveration)") +
  coord_cartesian(xlim = c(-max_abs_kappa, max_abs_kappa), ylim = c(0, 1.3), clip = "off") +
  posterior_theme

# Panel D: decay
med_decay <- median(draws_group$decay_group)

pD <- ggplot(draws_group, aes(x = decay_group, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = med_decay, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  annotate("text", x = med_decay, y = Inf,
    label = sprintf("[median = %.2f]", med_decay),
    hjust = -0.07, vjust = 1.4, size = 3.2, colour = "grey40") +
  labs(x = "decay") +
  coord_cartesian(ylim = c(0, 1.3), clip = "off") +
  posterior_theme

group_fig <- (pA | pB | pC | pD) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold"))

ggsave("figures/group_posteriors.png", group_fig,
       width = 14, height = 4, dpi = 150, bg = "white")
message("Saved: figures/group_posteriors.png")

#### SUBJECT-LEVEL PARAMETER ESTIMATES ####
Nsubjects <- nrow(pmap)

sbj_summary <- draws_sbj |>
  pivot_longer(everything(), names_to = "var", values_to = "value") |>
  mutate(
    param   = sub("_sbj\\[\\d+\\]", "", var),
    sbj_idx = as.integer(sub(".*\\[(\\d+)\\]", "\\1", var))
  ) |>
  group_by(param, sbj_idx) |>
  summarise(
    med  = median(value),
    lo95 = quantile(value, 0.025),
    hi95 = quantile(value, 0.975),
    .groups = "drop"
  ) |>
  left_join(pmap, by = c("sbj_idx" = "participant_idx"))

sbj_theme <- theme_minimal(base_size = 12) +
  theme(
    panel.grid   = element_blank(),
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y  = element_blank(),
    axis.line.x  = element_line(colour = "grey30")
  )

# Panel A: alpha
df_alpha <- sbj_summary |> filter(param == "alpha") |> arrange(med) |> mutate(rank = row_number())

sA <- ggplot(df_alpha, aes(x = med, y = rank)) +
  geom_errorbar(aes(xmin = lo95, xmax = hi95), width = 0, orientation = "y", linewidth = 0.4, colour = "gray60") +
  geom_point(size = 2.5, colour = "gray20") +
  labs(x = "\u03b1 (learning rate)", y = NULL) +
  sbj_theme

# Panel B: beta
df_beta <- sbj_summary |> filter(param == "beta") |> arrange(med) |> mutate(rank = row_number())

sB <- ggplot(df_beta, aes(x = med, y = rank)) +
  geom_errorbar(aes(xmin = lo95, xmax = hi95), width = 0, orientation = "y", linewidth = 0.4, colour = "gray60") +
  geom_point(size = 2.5, colour = "gray20") +
  scale_x_log10() +
  labs(x = "\u03b2 (inverse temperature, log scale)", y = NULL) +
  sbj_theme

# Panel C: kappa
df_kappa <- sbj_summary |> filter(param == "kappa") |> arrange(med) |> mutate(rank = row_number())

sC <- ggplot(df_kappa, aes(x = med, y = rank)) +
  geom_errorbar(aes(xmin = lo95, xmax = hi95), width = 0, orientation = "y", linewidth = 0.4, colour = "gray60") +
  geom_point(size = 2.5, colour = "gray20") +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey40", linewidth = 0.6) +
  labs(x = "\u03ba (perseveration)", y = NULL) +
  sbj_theme

# Panel D: decay
df_decay <- sbj_summary |> filter(param == "decay") |> arrange(med) |> mutate(rank = row_number())

sD <- ggplot(df_decay, aes(x = med, y = rank)) +
  geom_errorbar(aes(xmin = lo95, xmax = hi95), width = 0, orientation = "y", linewidth = 0.4, colour = "gray60") +
  geom_point(size = 2.5, colour = "gray20") +
  labs(x = "decay", y = NULL) +
  sbj_theme

sbj_fig <- (sA | sB | sC | sD) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold"))

ggsave("figures/subject_posteriors.png", sbj_fig,
       width = 14, height = 5, dpi = 150, bg = "white")
message("Saved: figures/subject_posteriors.png")
