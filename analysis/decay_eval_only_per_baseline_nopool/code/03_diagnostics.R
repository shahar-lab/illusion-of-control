# reads: artifacts/fit.rds · writes: output/03_diagnostic.pdf, artifacts/convergence.csv

#### LOAD FIT ####

fit <- readRDS(file.path(artifacts_dir, "fit.rds"))

# No population level in this model: the diagnostics run on every subject's parameters
subject_vars <- c(paste0("alpha_per_sbj[", 1:4, "]"), paste0("beta_per_sbj[", 1:4, "]"))
draws        <- fit$draws(variables = subject_vars, format = "draws_array")

#### SUMMARY TABLE ####

summary_table <- summarise_draws(draws, ess_bulk, ess_tail, rhat)
summary_table[-1] <- round(summary_table[-1], 2)

#### PLOTS ####

trank_plot <- mcmc_rank_overlay(draws)
pairs_plot <- mcmc_pairs(draws)

pdf(file.path(output_dir, "03_diagnostic.pdf"), width = 8, height = 6)
grid.arrange(tableGrob(summary_table))
print(trank_plot)
print(pairs_plot)
dev.off()

#### SAVE ####

write_csv(summary_table, file.path(artifacts_dir, "convergence.csv"))
