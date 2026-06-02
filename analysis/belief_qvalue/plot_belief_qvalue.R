rm(list = ls())

#### SETUP ####
library(ggplot2)
library(dplyr)
library(readr)
library(patchwork)
library(rstan)

rstan_options(auto_write = TRUE)
options(mc.cores = 4)

combined <- read_csv("bayesian_draws/rl_qvalues.csv", show_col_types = FALSE)

#### PER-SUBJECT RMSE (Euclidean distance between Q-vector and belief-vector) ####
subj_dist <- combined |>
  mutate(
    rmse = sqrt(((Q_blue  - belief_blue  / 100)^2 +
                 (Q_green - belief_green / 100)^2 +
                 (Q_red   - belief_red   / 100)^2) / 3)
  ) |>
  mutate(subj_label = paste0("S", seq_len(n()))) |>
  select(participant, subj_label, rmse)

#### PER-SUBJECT VECTOR CORRELATION ####
subj_r <- combined |>
  rowwise() |>
  mutate(
    r = tryCatch(
      cor(c(Q_blue, Q_green, Q_red), c(belief_blue, belief_green, belief_red) / 100),
      error = function(e) NA_real_
    ),
    uniform_belief = (belief_blue == belief_green & belief_green == belief_red)
  ) |>
  ungroup() |>
  select(participant, r, uniform_belief) |>
  mutate(subj_label = paste0("S", seq_len(n())))

cat("Per-subject r:\n")
print(subj_r[, c("subj_label", "r", "uniform_belief")])

#### HIERARCHICAL MODEL ON FISHER-Z OF VALID r ####
valid <- subj_r |> filter(!is.na(r))
cat("\nFitting hierarchical model on", nrow(valid), "subjects\n")

stan_code <- "
data {
  int<lower=1> N;
  vector[N] z;
}
parameters {
  real mu_z;
  real<lower=0> sigma_z;
}
model {
  mu_z    ~ normal(0, 1.5);
  sigma_z ~ normal(0, 1);
  z ~ normal(mu_z, sigma_z);
}
generated quantities {
  real mu_r = tanh(mu_z);
}
"

fit_hier <- stan(
  model_code = stan_code,
  data = list(N = nrow(valid), z = atanh(valid$r)),
  chains = 4, iter = 2000, warmup = 1000, refresh = 0
)

mu_r_draws <- as.data.frame(fit_hier)$mu_r
med_r  <- median(mu_r_draws)
ci_lo  <- quantile(mu_r_draws, 0.025)
ci_hi  <- quantile(mu_r_draws, 0.975)
pd_pos <- mean(mu_r_draws > 0) * 100

cat(sprintf("Group mean r: %.2f [%.2f, %.2f], pd = %.0f%%\n", med_r, ci_lo, ci_hi, pd_pos))

#### PANEL A — per-participant RMSE (Q-vector vs belief-vector) ####
# Dot-and-segment lollipop ordered from smallest to largest distance
pA <- ggplot(subj_dist, aes(x = rmse, y = reorder(subj_label, -rmse))) +
  geom_segment(aes(xend = 0, yend = reorder(subj_label, -rmse)),
               colour = "grey70", linewidth = 0.6) +
  geom_point(size = 3.5, colour = "#0072B2") +
  scale_x_continuous(limits = c(0, 1),
                     labels = scales::number_format(accuracy = 0.1)) +
  labs(
    x     = "RMSE  (Q-vector vs belief-vector,  range 0–1)",
    y     = NULL,
    title = "Per-participant alignment of RL Q-values and self-reported beliefs"
  ) +
  theme_classic(base_size = 13) +
  theme(axis.line.y = element_blank(), axis.ticks.y = element_blank())

#### PANEL B — per-subject r + group-level posterior ####
post_df  <- data.frame(mu_r = mu_r_draws)
xlim_r   <- c(-1, 1)
ann_text <- sprintf("Group mean r = %.2f\n95%% CI [%.2f, %.2f]  pd = %.0f%%",
                    med_r, ci_lo, ci_hi, pd_pos)

# Top: individual dots ordered by r (NA subjects shown as hollow at 0)
subj_plot <- subj_r |>
  mutate(
    r_plot  = if_else(is.na(r), 0, r),
    is_na   = is.na(r),
    y_order = rank(r_plot, ties.method = "first")
  )

pB_dots <- ggplot(subj_plot, aes(x = r_plot, y = y_order)) +
  geom_vline(xintercept = 0,     linetype = "dashed",  colour = "grey40", linewidth = 0.6) +
  geom_vline(xintercept = med_r, linetype = "dotted",  colour = "#0072B2", linewidth = 0.7) +
  geom_point(data = filter(subj_plot, !is_na),
             size = 3, colour = "grey20") +
  geom_point(data = filter(subj_plot, is_na),
             size = 3, shape = 1, colour = "grey60") +
  annotate("text", x = 1.0, y = 9.5,
    label = sprintf("%d subjects\nwith uniform\nbeliefs (NA)",
                    sum(subj_plot$is_na)),
    hjust = 1, vjust = 1, size = 2.8, colour = "grey55") +
  scale_x_continuous(limits = xlim_r) +
  scale_y_continuous(breaks = NULL) +
  labs(x = NULL, y = NULL,
       title = "Per-subject correlation: Q-vector vs belief-vector") +
  theme_classic(base_size = 12) +
  theme(axis.line.y = element_blank())

# Bottom: posterior density of group mean r
pB_post <- ggplot(post_df, aes(x = mu_r)) +
  geom_density(fill = "#0072B2", colour = NA, alpha = 0.50) +
  geom_vline(xintercept = 0,     linetype = "dashed", colour = "grey40", linewidth = 0.6) +
  geom_vline(xintercept = med_r, linetype = "dotted", colour = "#0072B2", linewidth = 0.7) +
  annotate("text", x = med_r, y = Inf,
    label = ann_text,
    hjust = -0.05, vjust = 1.3, size = 3.0, colour = "grey30") +
  scale_x_continuous(limits = xlim_r) +
  labs(x = "Group-level mean correlation (r)", y = NULL) +
  theme_classic(base_size = 12) +
  theme(
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y  = element_blank()
  )

#### COMBINE ####
combined_plot <- pA / pB_dots / pB_post +
  plot_layout(heights = c(1.8, 1.5, 1)) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold"))

dir.create("figures", showWarnings = FALSE)
ggsave("figures/belief_vs_qvalue.png", combined_plot,
       width = 7, height = 11, dpi = 150, bg = "white")
message("Saved: figures/belief_vs_qvalue.png")
