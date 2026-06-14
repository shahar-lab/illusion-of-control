rm(list = ls())

library(ggplot2)
library(dplyr)
library(readr)

DRAWS_DIR <- "bayesian_draws"
FIG_DIR   <- "figures"
dir.create(FIG_DIR, showWarnings = FALSE)

#### LOAD GROUP-LEVEL DRAWS ####
group_draws <- read_csv(
  file.path(DRAWS_DIR, "posterior_draws_group.csv"),
  show_col_types = FALSE
)

draws   <- group_draws$beta_mu
med_val <- median(draws)
pd_val  <- max(mean(draws > 0), mean(draws < 0)) * 100
ci80    <- quantile(draws, c(0.10, 0.90))
ci90    <- quantile(draws, c(0.05, 0.95))
max_abs <- max(abs(range(draws)))

cat(sprintf("beta_mu: median = %.3f, 80%% CI [%.3f, %.3f], 90%% CI [%.3f, %.3f], pd = %.1f%%\n",
            med_val, ci80[1], ci80[2], ci90[1], ci90[2], pd_val))

#### BUILD NORMALISED DENSITY ####
dens    <- density(draws, n = 512)
df_dens <- data.frame(x = dens$x, y = dens$y / max(dens$y))

CI_Y <- -0.04  # y-position for CI bars (just below x-axis)

#### PLOT POSTERIOR OF BETA_MU ####
p <- ggplot() +
  # Slab: normalised density in uniform gray
  geom_area(data = df_dens, aes(x = x, y = y), fill = "gray80", colour = NA) +
  # CI lines: 90 % thin, 80 % thick (follow skill — thickness only, no fill change)
  annotate("segment",
           x = ci90[1], xend = ci90[2], y = CI_Y, yend = CI_Y,
           linewidth = 1.0, colour = "black") +
  annotate("segment",
           x = ci80[1], xend = ci80[2], y = CI_Y, yend = CI_Y,
           linewidth = 2.0, colour = "black") +
  # Median point
  annotate("point", x = med_val, y = CI_Y, size = 3, colour = "black") +
  # Zero reference (effect posterior — include zero)
  geom_vline(xintercept = 0,       linetype = "dashed", colour = "grey40", linewidth = 0.7) +
  # Median reference (thin, light)
  geom_vline(xintercept = med_val, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  annotate(
    "text",
    x = med_val, y = Inf,
    label = sprintf("[median = %.2f, pd = %.1f%%]", med_val, pd_val),
    hjust = -0.05, vjust = 1.4,
    size  = 3.2, colour = "grey40"
  ) +
  # Symmetric x-axis centred on zero
  coord_cartesian(xlim = c(-max_abs, max_abs), ylim = c(CI_Y - 0.05, 1.3), clip = "off") +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid   = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y  = element_blank(),
    axis.line.x  = element_line(colour = "grey30")
  ) +
  labs(x = expression(beta[mu]~"(reward effect on log-odds of staying)"))

ggsave(file.path(FIG_DIR, "posterior_beta_mu.pdf"), p, width = 7, height = 3)
cat("Saved figures/posterior_beta_mu.pdf\n")
