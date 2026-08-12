#### PARAMETER RECOVERY SUMMARY TABLE ####

individual_params <- read_csv(file.path(artifacts_dir, "individual_params.csv"), show_col_types = FALSE)
recovered_medians <- read_csv(file.path(artifacts_dir, "recovered_medians.csv"), show_col_types = FALSE)

summary_tbl <- tibble(
  parameter = c("alpha_rl", "alpha_per", "beta_rl", "beta_per"),
  pearson_r = round(c(
    cor(individual_params$alpha_rl,  recovered_medians$alpha_rl),
    cor(individual_params$alpha_per, recovered_medians$alpha_per),
    cor(individual_params$beta_rl,   recovered_medians$beta_rl),
    cor(individual_params$beta_per,  recovered_medians$beta_per)
  ), 3)
)

cat("--- Parameter Recovery Summary (Pearson r: true vs. recovered) ---\n")
print(summary_tbl)

write_csv(summary_tbl, file.path(output_dir, "recovery_summary.csv"))
cat("Saved: recovery_summary.csv\n")
