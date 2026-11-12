# reads: artifacts/individual_params.csv, recovered_summary.csv, posterior_cor.csv, population_posteriors.rds, population_params.csv · writes: output/08_recovery_summary.csv, 08_tradeoffs.csv, 08_population_recovery.csv

#### SUBJECT-LEVEL RECOVERY ####

individual_params <- read_csv(file.path(artifacts_dir, "individual_params.csv"), show_col_types = FALSE)
recovered_summary <- read_csv(file.path(artifacts_dir, "recovered_summary.csv"), show_col_types = FALSE)
posterior_cor     <- read_csv(file.path(artifacts_dir, "posterior_cor.csv"), show_col_types = FALSE)

recovery_df <- individual_params |>
  pivot_longer(all_of(population_params$param), names_to = "param", values_to = "true_val") |>
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
  ) |>
  arrange(match(param, population_params$param))


#### PARAMETER TRADE-OFFS ####

errors_wide <- recovery_df |>
  select(subject, param, error) |>
  pivot_wider(names_from = param, values_from = error)

tradeoffs <- bind_rows(lapply(combn(population_params$param, 2, simplify = FALSE), function(params) {
  pair_name <- paste(params, collapse = "_")
  pair_cor  <- posterior_cor$cor[posterior_cor$pair == pair_name]
  tibble(
    pair                 = pair_name,
    error_cor            = cor(errors_wide[[params[1]]], errors_wide[[params[2]]]),
    posterior_cor_mean   = mean(pair_cor),
    posterior_cor_median = median(pair_cor)
  )
}))


#### POPULATION-LEVEL RECOVERY ####

pop_draws         <- read_rds(file.path(artifacts_dir, "population_posteriors.rds"))
population_params <- read_csv(file.path(artifacts_dir, "population_params.csv"), show_col_types = FALSE)

link_fun <- list(inv_logit = plogis, exp = exp, identity = identity)

population_recovery <- tibble(
  variable   = paste0(population_params$param, "_pop"),
  true_value = mapply(\(mu, link) link_fun[[link]](mu), population_params$mu, population_params$link)
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
cat("--- Trade-offs ---\n")
print(tradeoffs, width = Inf)
cat("--- Population-level recovery ---\n")
print(population_recovery, width = Inf)

write_csv(recovery_summary,    file.path(output_dir, "08_recovery_summary.csv"))
write_csv(tradeoffs,           file.path(output_dir, "08_tradeoffs.csv"))
write_csv(population_recovery, file.path(output_dir, "08_population_recovery.csv"))
