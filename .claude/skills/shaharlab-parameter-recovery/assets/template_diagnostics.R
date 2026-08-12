#### HMC CONVERGENCE DIAGNOSTICS ####

fit <- readRDS(file.path(artifacts_dir, "fit.rds"))

diag <- fit$diagnostic_summary()

cat("--- Chain-level diagnostics ---\n")
cat("Divergent transitions per chain:", diag$num_divergent, "\n")
cat("Max treedepth hits per chain:   ", diag$num_max_treedepth, "\n")
cat("Total divergences:", sum(diag$num_divergent), "\n\n")

group_vars <- c(
  "mu_alpha_rl", "mu_alpha_per", "mu_beta_rl", "mu_beta_per",
  "sigma_alpha_rl", "sigma_alpha_per", "sigma_beta_rl", "sigma_beta_per"
)

cat("--- Group-level parameter summary (Rhat, ESS) ---\n")
diag_summary <- fit$summary(
  variables = group_vars,
  "rhat", "ess_bulk", "ess_tail"
)
print(diag_summary)

n_bad_rhat <- sum(diag_summary$rhat > 1.01, na.rm = TRUE)
n_low_ess  <- sum(diag_summary$ess_bulk < 400, na.rm = TRUE)

cat("\nParameters with Rhat > 1.01:", n_bad_rhat, "\n")
cat("Parameters with ESS_bulk < 400:", n_low_ess, "\n")
# Targets (see RUN_CONVENTIONS.md): 0 divergences, both counts above should be 0.


#### DIAGNOSTICS PDF ####

group_draws <- fit$draws(variables = group_vars)

trace_plot <- mcmc_trace(group_draws, facet_args = list(ncol = 2)) +
  ggtitle("MCMC trace plots (group-level parameters)")

rank_plot <- mcmc_rank_overlay(group_draws, facet_args = list(ncol = 2)) +
  ggtitle("Trace rank plots (group-level parameters)")

pairs_plot <- mcmc_pairs(
  group_draws,
  np            = nuts_params(fit),
  off_diag_args = list(size = 0.6, alpha = 0.4)
)

# Rhat and ESS across the estimated parameters (group- and subject-level).
# Transformed quantities (per STAN_PITFALLS.md #1, this model shouldn't have any
# per-trial ones — log_lik/Q_trial/E_trial — but if it does, exclude them here: they're
# deterministic/constant across draws and give NA Rhat, which pollutes the histogram.
estimated_vars <- c(
  group_vars,
  "alpha_rl_sbj", "alpha_per_sbj", "beta_rl_sbj", "beta_per_sbj"
)

param_summary <- fit$summary(
  variables = estimated_vars,
  "rhat", "ess_bulk", "ess_tail"
)

hist_theme <- theme_minimal(base_size = 13) +
  theme(panel.grid.minor = element_blank())

p_ess <- ggplot(param_summary, aes(x = ess_bulk)) +
  geom_histogram(bins = 20, fill = "#4477AA", colour = "white") +
  geom_vline(xintercept = 400, linetype = "dashed",
             colour = "#EE6677", linewidth = 0.8) +
  hist_theme +
  labs(x = "Bulk effective sample size", y = "Number of parameters",
       title = "Effective sample size (dashed line = 400)")

p_rhat <- ggplot(param_summary, aes(x = rhat)) +
  geom_histogram(bins = 20, fill = "#4477AA", colour = "white") +
  geom_vline(xintercept = 1.01, linetype = "dashed",
             colour = "#EE6677", linewidth = 0.8) +
  hist_theme +
  labs(x = "Rhat", y = "Number of parameters",
       title = "Rhat (dashed line = 1.01)")

hist_fig <- (p_ess / p_rhat)

pdf(file.path(output_dir, "Diagnostics.pdf"), width = 10, height = 8, bg = "white")
print(trace_plot)
print(rank_plot)
print(pairs_plot)
print(hist_fig)
dev.off()

cat("Saved: Diagnostics.pdf\n")
