# reads: artifacts/fit.rds · writes: output/03_diagnostic.pdf, artifacts/population_convergence.csv

#### LOAD FIT ####

fit <- readRDS(file.path(artifacts_dir, "fit.rds"))

# Population-level parameters only; the per-subject raw and _sbj draws are dropped
population_vars <- c("mu_alpha_per", "mu_beta_per", "sigma_alpha_per", "sigma_beta_per")
draws           <- fit$draws(variables = population_vars, format = "draws_array")

#### SUMMARY TABLE ####

summary_table <- summarise_draws(draws, ess_bulk, ess_tail, rhat)
summary_table[-1] <- round(summary_table[-1], 2)

subject_convergence <- fit$draws(variables = c("alpha_per_sbj", "beta_per_sbj")) |>
  summarise_draws(ess_bulk, ess_tail, rhat)

#### PLOTS ####

trank_plot <- mcmc_rank_overlay(draws)
pairs_plot <- mcmc_pairs(draws)

pdf(file.path(output_dir, "03_diagnostic.pdf"), width = 8, height = 6)
grid.arrange(tableGrob(summary_table))
print(trank_plot)
print(pairs_plot)
dev.off()

#### SAVE ####

write_csv(bind_rows(summary_table, subject_convergence),
          file.path(artifacts_dir, "population_convergence.csv"))
