rm(list = ls())

#### SETUP ####
library(ggplot2)
library(dplyr)
library(tidyr)
library(readr)
library(patchwork)
library(rstan)

rstan_options(auto_write = TRUE)
options(mc.cores = 4)

combined <- read_csv("bayesian_draws/rl_qvalues.csv", show_col_types = FALSE)

#### RESHAPE ####
df_long <- combined |>
  pivot_longer(
    cols = c(Q_blue, Q_green, Q_red, belief_blue, belief_green, belief_red),
    names_to  = c(".value", "machine"),
    names_pattern = "(.+)_(blue|green|red)"
  ) |>
  mutate(belief_01 = belief / 100)

r_all <- cor(df_long$Q, df_long$belief_01, use = "complete.obs")

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

#### PANEL A — simple scatter (all 30 pts, no machine coloring) ####
pA <- ggplot(df_long, aes(x = Q, y = belief_01)) +
  geom_abline(slope = 1, intercept = 0,
              linetype = "dashed", colour = "grey60", linewidth = 0.5) +
  geom_smooth(method = "lm", se = TRUE,
              colour = "#0072B2", fill = "#56B4E9", alpha = 0.20, linewidth = 0.9) +
  geom_point(size = 2.5, colour = "grey25", alpha = 0.75) +
  annotate("text", x = -Inf, y = Inf,
    label = sprintf("Pearson r = %.2f  (n = 30: 10 subjects × 3 machines)", r_all),
    hjust = -0.04, vjust = 1.4, size = 3.2, colour = "grey30") +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1)) +
  labs(
    x = "Final modeled Q-value",
    y = "Self-reported belief (rescaled 0–1)"
  ) +
  theme_classic(base_size = 13)

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
  plot_layout(heights = c(2.5, 1.5, 1)) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold"))

dir.create("figures", showWarnings = FALSE)
ggsave("figures/belief_vs_qvalue.png", combined_plot,
       width = 7, height = 11, dpi = 150, bg = "white")
message("Saved: figures/belief_vs_qvalue.png")
