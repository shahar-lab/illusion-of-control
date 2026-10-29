# reads: artifacts/individual_params.csv, recovered_summary.csv, posterior_cor.csv, population_posteriors.rds, population_params.csv · writes: output/08_recovery_summary.csv, 08_population_recovery.csv

#### SUBJECT-LEVEL RECOVERY ####

individual_params <- read_csv(file.path(artifacts_dir, "individual_params.csv"), show_col_types = FALSE)
recovered_summary <- read_csv(file.path(artifacts_dir, "recovered_summary.csv"), show_col_types = FALSE)
posterior_cor     <- read_csv(file.path(artifacts_dir, "posterior_cor.csv"), show_col_types = FALSE)

recovery_df <- individual_params |>
  pivot_longer(c(alpha, beta), names_to = "param", values_to = "true_val") |>
  left_join(recovered_summary, by = c("subject", "param")) |>
  mutate(error = median - true_val)

recovery_summary <- recovery_df |>
  group_by(param) |>
  summarise(
    pearson_r       = cor(true_val, median),
    bias            = mean(error),
    ols_slope       = coef(lm(median ~ true_val))[2],
    coverage_90     = mean(true_val >= q5 & true_val <= q95),
    median_post_sd  = median(sd),
    spread_ratio_sd = sd(median) / sd(true_val),
    .groups         = "drop"
  )

errors_wide <- recovery_df |>
  select(subject, param, error) |>
  pivot_wider(names_from = param, values_from = error)

tradeoff <- tibble(
  alpha_beta_error_cor          = cor(errors_wide$alpha, errors_wide$beta),
  alpha_beta_posterior_cor_mean = mean(posterior_cor$alpha_beta_cor),
  alpha_beta_posterior_cor_med  = median(posterior_cor$alpha_beta_cor)
)

recovery_summary <- bind_cols(recovery_summary, tradeoff)


#### POPULATION-LEVEL RECOVERY ####

pop_draws         <- read_rds(file.path(artifacts_dir, "population_posteriors.rds"))
population_params <- read_csv(file.path(artifacts_dir, "population_params.csv"), show_col_types = FALSE)

population_recovery <- tibble(
  variable   = c("mu_alpha", "mu_beta", "sigma_alpha", "sigma_beta"),
  true_value = c(population_params$mu, population_params$sigma)
) |>
  rowwise() |>
  mutate(
    post_median = median(pop_draws[[variable]]),
    q5          = quantile(pop_draws[[variable]], 0.05),
    q95         = quantile(pop_draws[[variable]], 0.95),
    covered_90  = true_value >= q5 & true_value <= q95
  ) |>
  ungroup()

cat("--- Subject-level recovery ---\n")
print(recovery_summary, width = Inf)
cat("--- Population-level recovery ---\n")
print(population_recovery, width = Inf)

write_csv(recovery_summary,    file.path(output_dir, "08_recovery_summary.csv"))
write_csv(population_recovery, file.path(output_dir, "08_population_recovery.csv"))
