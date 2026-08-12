#### PARAMETER RECOVERY SUMMARY TABLE ####

individual_params <- read_csv(file.path(artifacts_dir, "individual_params.csv"), show_col_types = FALSE)
recovered_medians <- read_csv(file.path(artifacts_dir, "recovered_medians.csv"), show_col_types = FALSE)

summary_tbl <- tibble(
  parameter = c("decay_rl", "decay_h", "rho_rl", "rho_h"),
  pearson_r = round(c(
    cor(individual_params$decay_rl, recovered_medians$decay_rl),
    cor(individual_params$decay_h,  recovered_medians$decay_h),
    cor(individual_params$rho_rl,   recovered_medians$rho_rl),
    cor(individual_params$rho_h,    recovered_medians$rho_h)
  ), 3)
)

cat("--- Parameter Recovery Summary (Pearson r: true vs. recovered) ---\n")
print(summary_tbl)

write_csv(summary_tbl, file.path(output_dir, "recovery_summary.csv"))
cat("Saved: recovery_summary.csv\n")
