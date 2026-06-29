rm(list = ls())

#### SETUP ####
library(ggplot2)
library(ggdist)
library(dplyr)
library(tidyr)
library(readr)
library(patchwork)

DRAWS_DIR <- "bayesian_draws_r"

draws_group <- read_csv(file.path(DRAWS_DIR, "posterior_draws_group_m1.csv"), show_col_types = FALSE)

dir.create("figures", showWarnings = FALSE)

posterior_theme <- theme_minimal(base_size = 13) +
  theme(
    panel.grid   = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y  = element_blank(),
    axis.line.x  = element_line(colour = "grey30")
  )

#### POPULATION POSTERIORS ####

# alpha (learning rate) — natural scale via alpha_pop = inv_logit(mu_alpha)
med_alpha <- median(draws_group$alpha_pop)

pA <- ggplot(draws_group, aes(x = alpha_pop, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = med_alpha, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  annotate("text", x = med_alpha, y = Inf,
    label = sprintf("[median = %.2f]", med_alpha),
    hjust = -0.07, vjust = 1.4, size = 3.2, colour = "grey40") +
  scale_x_continuous(limits = c(0, 1)) +
  labs(x = "α (learning rate)") +
  coord_cartesian(ylim = c(0, 1.3), clip = "off") +
  posterior_theme

# beta (inverse temperature)
med_beta <- median(draws_group$beta_pop)
pd_beta  <- max(mean(draws_group$beta_pop > 0), mean(draws_group$beta_pop < 0)) * 100

pB <- ggplot(draws_group, aes(x = beta_pop, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = med_beta, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  annotate("text", x = med_beta, y = Inf,
    label = sprintf("[median = %.2f, pd = %.1f%%]", med_beta, pd_beta),
    hjust = -0.07, vjust = 1.4, size = 3.2, colour = "grey40") +
  labs(x = "β (inverse temperature)") +
  coord_cartesian(ylim = c(0, 1.3), clip = "off") +
  posterior_theme

# kappa (perseveration) — zero is meaningful
med_kappa     <- median(draws_group$kappa_pop)
pd_kappa      <- max(mean(draws_group$kappa_pop > 0), mean(draws_group$kappa_pop < 0)) * 100
max_abs_kappa <- max(abs(range(draws_group$kappa_pop)))

pC <- ggplot(draws_group, aes(x = kappa_pop, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = 0,         linetype = "dashed", colour = "grey40", linewidth = 0.7) +
  geom_vline(xintercept = med_kappa, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  annotate("text", x = med_kappa, y = Inf,
    label = sprintf("[median = %.2f, pd = %.1f%%]", med_kappa, pd_kappa),
    hjust = -0.07, vjust = 1.4, size = 3.2, colour = "grey40") +
  labs(x = "κ (perseveration)") +
  coord_cartesian(xlim = c(-max_abs_kappa, max_abs_kappa), ylim = c(0, 1.3), clip = "off") +
  posterior_theme

# delta (decay rate) — natural scale via delta_pop = inv_logit(mu_delta)
med_delta <- median(draws_group$delta_pop)

pD <- ggplot(draws_group, aes(x = delta_pop, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = med_delta, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  annotate("text", x = med_delta, y = Inf,
    label = sprintf("[median = %.2f]", med_delta),
    hjust = -0.07, vjust = 1.4, size = 3.2, colour = "grey40") +
  scale_x_continuous(limits = c(0, 1)) +
  labs(x = "δ (decay rate)") +
  coord_cartesian(ylim = c(0, 1.3), clip = "off") +
  posterior_theme

group_fig <- (pA | pB | pC | pD) +
  plot_annotation(
    title     = "M1 population posteriors — ioc-all-fixed-pilot (N=18)",
    tag_levels = "A"
  ) &
  theme(plot.tag = element_text(face = "bold"))

ggsave("figures/param_estimation_m1_population.png", group_fig,
       width = 14, height = 4, dpi = 150, bg = "white")

message("Saved: figures/param_estimation_m1_population.png")
