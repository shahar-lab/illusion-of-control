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
diag_summary <- fit$summary(variables = group_vars, rhat, ess_bulk, ess_tail)
print(diag_summary)

n_bad_rhat <- sum(diag_summary$rhat > 1.01, na.rm = TRUE)
n_low_ess  <- sum(diag_summary$ess_bulk < 400, na.rm = TRUE)

cat("\nParameters with Rhat > 1.01:", n_bad_rhat, "\n")
cat("Parameters with ESS_bulk < 400:", n_low_ess, "\n")
