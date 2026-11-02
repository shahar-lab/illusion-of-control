# reads: artifacts/diagnostics.csv, runtime_min.rds, output/08_*.csv, output/0[367]_*.png, artifacts/0[367]_*_plot.rds · writes: output/09_recovery_report.docx, 09_recovery_figures.pdf

#### LOAD RESULTS ####

diagnostics         <- read_csv(file.path(artifacts_dir, "diagnostics.csv"), show_col_types = FALSE)
runtime_min         <- read_rds(file.path(artifacts_dir, "runtime_min.rds"))
recovery_summary    <- read_csv(file.path(output_dir, "08_recovery_summary.csv"), show_col_types = FALSE)
tradeoffs           <- read_csv(file.path(output_dir, "08_tradeoffs.csv"), show_col_types = FALSE)
population_recovery <- read_csv(file.path(output_dir, "08_population_recovery.csv"), show_col_types = FALSE)

round_table <- function(df) {
  df |>
    mutate(across(where(is.numeric), \(x) round(x, 2))) |>
    flextable() |>
    autofit()
}

subject_table    <- round_table(recovery_summary)
tradeoff_table   <- round_table(tradeoffs)
population_table <- round_table(population_recovery)

link_text <- c(inv_logit = "inv_logit(N(%.2f, %.2f))", exp = "exp(N(%.2f, %.2f))", identity = "N(%.2f, %.2f)")
population_text <- paste(
  mapply(\(param, mu, sigma, link) sprintf(paste(param, "=", link_text[[link]]), mu, sigma),
         population_params$param, population_params$mu, population_params$sigma, population_params$link),
  collapse = ", "
)

design_text <- sprintf(
  paste(
    "We simulated %d agents performing %d trials of a %d-armed bandit (%s).",
    "Agent-level parameters were drawn from %s.",
    "The hierarchical %s model was fitted with 4 chains of %d warmup and %d sampling iterations (%.1f min)."
  ),
  Nsubjects, Ntrials, Narms, environment_description,
  population_text, model_name, iter_warmup, iter_sampling, runtime_min
)

convergence_text <- sprintf(
  "Divergent transitions: %d. Group-level max Rhat = %.3f, min bulk ESS = %.0f. Subject-level max Rhat = %.3f, min bulk ESS = %.0f.",
  diagnostics$divergences, diagnostics$group_max_rhat, diagnostics$group_min_ess_bulk,
  diagnostics$sbj_max_rhat, diagnostics$sbj_min_ess_bulk
)

tradeoff_text <- paste(
  "For every pair of parameters: the correlation of recovery errors across agents (error_cor)",
  "and the within-agent correlation across posterior draws (mean and median over agents)."
)

error_caption <- paste(
  paste(sprintf("%s recovery error (posterior median minus true value) against the true %s%s",
                error_pairs$target, ifelse(error_pairs$by_abs, "absolute ", ""), error_pairs$by),
        collapse = "; "),
  "(log scale for exp-linked parameters). The red line is a loess smoother and the dashed grey line marks zero error."
)


#### WRITE WORD REPORT ####

caption <- function(doc, number, text) {
  body_add_fpar(doc, fpar(ftext(paste0("Figure ", number, ". "), fp_text(italic = TRUE)), ftext(text)))
}

n_params <- nrow(population_params)

doc <- read_docx() |>
  body_add_par(paste0("Parameter recovery: ", model_name, ", ", environment_name, " environment, ", run_name), style = "heading 1") |>
  body_add_par("Design", style = "heading 2") |>
  body_add_par(design_text) |>
  body_add_par("Convergence", style = "heading 2") |>
  body_add_par(convergence_text) |>
  body_add_par("Agent-level recovery", style = "heading 2") |>
  body_add_flextable(subject_table) |>
  body_add_par(tradeoff_text) |>
  body_add_flextable(tradeoff_table) |>
  body_add_par("Population-level recovery", style = "heading 2") |>
  body_add_flextable(population_table) |>
  body_add_img(file.path(output_dir, "03_param_distributions.png"), width = 6.5, height = 6.5 / n_params) |>
  caption(1, "True agent-level parameters drawn from the generating population (one dot per agent).") |>
  body_add_img(file.path(output_dir, "07_population_posteriors.png"), width = 6.5, height = 6.5 * 0.3 * n_params) |>
  caption(2, "Posterior densities of the population-level parameters (link(mu)) on the natural scale, with median and 80% / 90% credible intervals; the dashed red line marks the true generating value.") |>
  body_add_img(file.path(output_dir, "06_param_recovery.png"), width = 6.5,
               height = if (n_params == 4) 6.5 else 6.5 / n_params) |>
  caption(3, "True versus recovered (posterior median) agent-level parameters. The red line is the OLS fit, the dashed grey line is the identity line, and r is Pearson's correlation.") |>
  body_add_img(file.path(output_dir, "06_alpha_error_vs_beta.png"), width = 6.5, height = 6.5 * 5 / (7 * nrow(error_pairs))) |>
  caption(4, error_caption)

print(doc, target = file.path(output_dir, "09_recovery_report.docx"))


#### WRITE MULTI-PAGE PDF ####

figure_files <- c("03_param_distributions_plot.rds", "07_population_posteriors_plot.rds", "06_param_recovery_plot.rds", "06_alpha_error_vs_beta_plot.rds")

pdf(file.path(output_dir, "09_recovery_figures.pdf"), width = 10, height = 8, onefile = TRUE)
for (f in figure_files) {
  print(read_rds(file.path(artifacts_dir, f)))
}
dev.off()
