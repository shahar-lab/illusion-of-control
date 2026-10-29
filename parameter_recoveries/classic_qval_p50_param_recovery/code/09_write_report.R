# reads: artifacts/diagnostics.csv, runtime_min.rds, output/08_*.csv, output/0[367]_*.png, artifacts/0[367]_*_plot.rds · writes: output/09_recovery_report.docx, 09_recovery_figures.pdf

#### LOAD RESULTS ####

diagnostics         <- read_csv(file.path(artifacts_dir, "diagnostics.csv"), show_col_types = FALSE)
runtime_min         <- read_rds(file.path(artifacts_dir, "runtime_min.rds"))
recovery_summary    <- read_csv(file.path(output_dir, "08_recovery_summary.csv"), show_col_types = FALSE)
population_recovery <- read_csv(file.path(output_dir, "08_population_recovery.csv"), show_col_types = FALSE)

subject_table <- recovery_summary |>
  select(param, pearson_r, bias, ols_slope, coverage_90, median_post_sd, spread_ratio_sd) |>
  mutate(across(where(is.numeric), \(x) round(x, 2))) |>
  flextable() |>
  autofit()

population_table <- population_recovery |>
  mutate(across(where(is.numeric), \(x) round(x, 2))) |>
  flextable() |>
  autofit()

design_text <- sprintf(
  paste(
    "We simulated %d agents performing %d trials of a %d-armed bandit (%s).",
    "Agent-level parameters were drawn from alpha = inv_logit(N(%.2f, %.2f)) and beta = exp(N(%.2f, %.2f));",
    "alpha was logistically transformed onto the unit interval and beta exponentiated to stay positive.",
    "The hierarchical classic_qval model was fitted with 4 chains of %d warmup and %d sampling iterations (%.1f min)."
  ),
  Nsubjects, Ntrials, Narms, environment_description,
  mu_alpha, sigma_alpha, mu_beta, sigma_beta, iter_warmup, iter_sampling, runtime_min
)

convergence_text <- sprintf(
  "Divergent transitions: %d. Group-level max Rhat = %.3f, min bulk ESS = %.0f. Subject-level max Rhat = %.3f, min bulk ESS = %.0f.",
  diagnostics$divergences, diagnostics$group_max_rhat, diagnostics$group_min_ess_bulk,
  diagnostics$sbj_max_rhat, diagnostics$sbj_min_ess_bulk
)

tradeoff_text <- sprintf(
  "Correlation of alpha and beta recovery errors across agents: r = %.2f. Mean within-agent posterior correlation of alpha and beta: %.2f.",
  recovery_summary$alpha_beta_error_cor[1], recovery_summary$alpha_beta_posterior_cor_mean[1]
)


#### WRITE WORD REPORT ####

caption <- function(doc, number, text) {
  body_add_fpar(doc, fpar(ftext(paste0("Figure ", number, ". "), fp_text(italic = TRUE)), ftext(text)))
}

doc <- read_docx() |>
  body_add_par(paste("Parameter recovery: classic_qval,", environment_name, "environment,", run_name), style = "heading 1") |>
  body_add_par("Design", style = "heading 2") |>
  body_add_par(design_text) |>
  body_add_par("Convergence", style = "heading 2") |>
  body_add_par(convergence_text) |>
  body_add_par("Agent-level recovery", style = "heading 2") |>
  body_add_flextable(subject_table) |>
  body_add_par(tradeoff_text) |>
  body_add_par("Population-level recovery", style = "heading 2") |>
  body_add_flextable(population_table) |>
  body_add_img(file.path(output_dir, "03_param_distributions.png"), width = 6.5, height = 3.25) |>
  caption(1, "True agent-level alpha and beta drawn from the generating population (dots), with the generating density overlaid (blue line).") |>
  body_add_img(file.path(output_dir, "07_population_posteriors.png"), width = 6.5, height = 3.9) |>
  caption(2, "Posterior densities of the population location (mu) and scale (sigma) parameters on the unconstrained scale, with median and 90% credible interval; the dotted blue line marks the true generating value.") |>
  body_add_img(file.path(output_dir, "06_param_recovery.png"), width = 6.5, height = 3.25) |>
  caption(3, "True versus recovered (posterior median) agent-level parameters. The red line is the OLS fit, the dashed grey line is the identity line, and r is Pearson's correlation.")

print(doc, target = file.path(output_dir, "09_recovery_report.docx"))


#### WRITE MULTI-PAGE PDF ####

figure_files <- c("03_param_distributions_plot.rds", "07_population_posteriors_plot.rds", "06_param_recovery_plot.rds")

pdf(file.path(output_dir, "09_recovery_figures.pdf"), width = 10, height = 8, onefile = TRUE)
for (f in figure_files) {
  print(read_rds(file.path(artifacts_dir, f)))
}
dev.off()
