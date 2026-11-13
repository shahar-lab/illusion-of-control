# reads: artifacts/fit.rds, artifacts/df.rds · writes: artifacts/subject_draws.rds, output/04_subject_estimates.csv

#### LOAD ####

fit <- readRDS(file.path(artifacts_dir, "fit.rds"))
df  <- readRDS(file.path(artifacts_dir, "df.rds"))

labels <- df |> distinct(subject, label)

#### SUBJECT DRAWS ####

subject_draws <- fit$draws(variables = c("alpha_per_sbj", "beta_per_sbj"), format = "draws_df") |>
  as_tibble() |>
  select(-.chain, -.iteration) |>
  pivot_longer(-.draw, names_to = c("param", "subject"),
               names_pattern = "(.*)_sbj\\[(\\d+)\\]") |>
  mutate(subject = as.integer(subject)) |>
  pivot_wider(names_from = param, values_from = value) |>
  mutate(push = abs(beta_per * alpha_per)) |>
  left_join(labels, by = "subject")

#### ESTIMATES TABLE ####

stay_rates <- df |>
  group_by(label) |>
  summarise(n_trials = n(), p_stay = mean(stay_ch, na.rm = TRUE))

subject_estimates <- subject_draws |>
  pivot_longer(c(alpha_per, beta_per, push), names_to = "param") |>
  group_by(label, param) |>
  summarise(median = median(value),
            q5     = quantile(value, 0.05),
            q95    = quantile(value, 0.95),
            .groups = "drop") |>
  pivot_wider(names_from = param, values_from = c(median, q5, q95), names_glue = "{param}_{.value}") |>
  left_join(stay_rates, by = "label") |>
  select(label, n_trials, p_stay, starts_with("alpha_per"), starts_with("beta_per"), starts_with("push")) |>
  mutate(across(where(is.double), \(x) round(x, 3)))

print(subject_estimates, width = Inf)

#### SAVE ####

saveRDS(subject_draws, file.path(artifacts_dir, "subject_draws.rds"))
write_csv(subject_estimates, file.path(output_dir, "04_subject_estimates.csv"))
