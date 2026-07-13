#### PARAMETER RECOVERY SUMMARY TABLE ####

true_params     <- read_csv(file.path(artifacts_dir, "true_params.csv"),    show_col_types = FALSE)
recovered_means <- read_csv(file.path(artifacts_dir, "recovered_means.csv"), show_col_types = FALSE)

summary_tbl <- tibble(
  parameter = c("alpha_rl", "alpha_per", "beta_rl", "beta_per"),
  pearson_r = round(c(
    cor(true_params$alpha_rl,  recovered_means$alpha_rl),
    cor(true_params$alpha_per, recovered_means$alpha_per),
    cor(true_params$beta_rl,   recovered_means$beta_rl),
    cor(true_params$beta_per,  recovered_means$beta_per)
  ), 3)
)

cat("--- Parameter Recovery Summary (Pearson r: true vs. recovered) ---\n")
print(summary_tbl)

write_csv(summary_tbl, file.path(output_dir, "recovery_summary.csv"))
cat("Saved: recovery_summary.csv\n")
