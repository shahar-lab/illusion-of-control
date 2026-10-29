# reads: artifacts/fit.rds · writes: artifacts/diagnostics.csv, output/05_diagnostics.pdf

#### HMC CONVERGENCE DIAGNOSTICS ####

fit  <- read_rds(file.path(artifacts_dir, "fit.rds"))
diag <- fit$diagnostic_summary()

group_vars   <- c("mu_alpha", "mu_beta", "sigma_alpha", "sigma_beta")
group_summ   <- fit$summary(variables = group_vars, "rhat", "ess_bulk", "ess_tail")
subject_summ <- fit$summary(variables = c("alpha_sbj", "beta_sbj"), "rhat", "ess_bulk", "ess_tail")

cat("Divergent transitions per chain:", diag$num_divergent, "\n")
cat("Max treedepth hits per chain:   ", diag$num_max_treedepth, "\n")
print(group_summ)

diagnostics <- tibble(
  divergences          = sum(diag$num_divergent),
  max_treedepth_hits   = sum(diag$num_max_treedepth),
  group_max_rhat       = max(group_summ$rhat),
  group_min_ess_bulk   = min(group_summ$ess_bulk),
  group_n_rhat_gt_1.01 = sum(group_summ$rhat > 1.01),
  group_n_ess_lt_400   = sum(group_summ$ess_bulk < 400),
  sbj_max_rhat         = max(subject_summ$rhat),
  sbj_min_ess_bulk     = min(subject_summ$ess_bulk),
  sbj_n_rhat_gt_1.01   = sum(subject_summ$rhat > 1.01),
  sbj_n_ess_lt_400     = sum(subject_summ$ess_bulk < 400)
)
print(t(diagnostics))

write_csv(group_summ,  file.path(artifacts_dir, "group_convergence.csv"))
write_csv(diagnostics, file.path(artifacts_dir, "diagnostics.csv"))


#### DIAGNOSTICS PDF ####

group_draws <- fit$draws(variables = group_vars)

trace_plot <- mcmc_trace(group_draws, facet_args = list(ncol = 2)) +
  ggtitle("MCMC trace plots (group-level parameters)")

rank_plot <- mcmc_rank_overlay(group_draws, facet_args = list(ncol = 2)) +
  ggtitle("Trace rank plots (group-level parameters)")

pairs_plot <- mcmc_pairs(group_draws, np = nuts_params(fit), off_diag_args = list(size = 0.6, alpha = 0.4))

param_summary <- bind_rows(group_summ, subject_summ)
hist_theme    <- theme_minimal(base_size = 13) + theme(panel.grid.minor = element_blank())

p_ess <- ggplot(param_summary, aes(x = ess_bulk)) +
  geom_histogram(bins = 20, fill = "#4477AA", colour = "white") +
  geom_vline(xintercept = 400, linetype = "dashed", colour = "#EE6677", linewidth = 0.8) +
  hist_theme +
  labs(x = "Bulk effective sample size", y = "Number of parameters", title = "ESS (dashed line = 400)")

p_rhat <- ggplot(param_summary, aes(x = rhat)) +
  geom_histogram(bins = 20, fill = "#4477AA", colour = "white") +
  geom_vline(xintercept = 1.01, linetype = "dashed", colour = "#EE6677", linewidth = 0.8) +
  hist_theme +
  labs(x = "Rhat", y = "Number of parameters", title = "Rhat (dashed line = 1.01)")

pdf(file.path(output_dir, "05_diagnostics.pdf"), width = 10, height = 8, bg = "white")
print(trace_plot)
print(rank_plot)
print(pairs_plot)
print(p_ess / p_rhat)
dev.off()
