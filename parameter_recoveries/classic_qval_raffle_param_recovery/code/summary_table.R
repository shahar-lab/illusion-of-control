#### PARAMETER RECOVERY SUMMARY TABLE ####
# reads: artifacts/individual_params.csv, recovered_medians.csv · writes: output/recovery_summary.csv

individual_params <- read_csv(file.path(artifacts_dir, "individual_params.csv"), show_col_types = FALSE)
recovered_medians <- read_csv(file.path(artifacts_dir, "recovered_medians.csv"), show_col_types = FALSE)

summary_tbl <- tibble(
  parameter = c("alpha_rl", "beta_rl"),
  pearson_r = round(c(
    cor(individual_params$alpha_rl, recovered_medians$alpha_rl),
    cor(individual_params$beta_rl,  recovered_medians$beta_rl)
  ), 3)
)

cat("--- Parameter Recovery Summary (Pearson r: true vs. recovered) ---\n")
print(summary_tbl)

write_csv(summary_tbl, file.path(output_dir, "recovery_summary.csv"))
cat("Saved: recovery_summary.csv\n")
