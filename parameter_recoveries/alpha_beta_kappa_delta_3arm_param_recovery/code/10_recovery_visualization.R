# reads: artifacts/simulation_config.rds, artifacts/stan_draws_sbj.rds, artifacts/stan_draws_pop.rds, artifacts/true_parameters.rds · writes: artifacts/recovery_table.rds, artifacts/posterior_sds.rds, output/parameter_recovery_scatter.pdf, output/parameter_recovery_scatter.png

#### LOAD CONFIGURATION ####

simulation_config <- readRDS(file.path(artifacts_dir, "simulation_config.rds"))
list2env(simulation_config, envir = environment())

true_params <- readRDS(file.path(artifacts_dir, "true_parameters.rds"))

#### LOAD POSTERIOR DRAWS ####

draws_df <- readRDS(file.path(artifacts_dir, "stan_draws_sbj.rds"))
draws_pop <- readRDS(file.path(artifacts_dir, "stan_draws_pop.rds"))

#### COMPUTE POSTERIOR SDS ####

posterior_sds <- draws_df |>
  pivot_longer(
    cols = starts_with(c("alpha_sbj", "beta_sbj", "kappa_sbj", "delta_sbj")),
    names_to = "var_name",
    values_to = "value"
  ) |>
  mutate(
    subject_id = as.numeric(str_extract(var_name, "\\d+")),
    param_type = case_when(
      str_detect(var_name, "kappa") ~ "kappa",
      str_detect(var_name, "delta") ~ "delta",
      str_detect(var_name, "alpha") ~ "alpha",
      str_detect(var_name, "beta") ~ "beta"
    )
  ) |>
  group_by(var_name, subject_id, param_type) |>
  summarize(posterior_sd = sd(value, na.rm = TRUE), .groups = "drop") |>
  select(subject_id, param_type, posterior_sd) |>
  rename(subject = subject_id)

#### COMPUTE POSTERIOR MEANS ####

recovered_params <- draws_df |>
  pivot_longer(
    cols = starts_with(c("alpha_sbj", "beta_sbj", "kappa_sbj", "delta_sbj")),
    names_to = "var_name",
    values_to = "value"
  ) |>
  mutate(
    subject_id = as.numeric(str_extract(var_name, "\\d+"))
  ) |>
  group_by(var_name, subject_id) |>
  summarize(mean_val = mean(value, na.rm = TRUE), .groups = "drop") |>
  mutate(
    param_type = case_when(
      str_detect(var_name, "kappa") ~ "kappa",
      str_detect(var_name, "delta") ~ "delta",
      str_detect(var_name, "alpha") ~ "alpha",
      str_detect(var_name, "beta") ~ "beta"
    )
  ) |>
  select(subject_id, param_type, mean_val) |>
  pivot_wider(
    names_from = param_type,
    values_from = mean_val
  ) |>
  rename(subject = subject_id) |>
  arrange(subject)

#### BUILD RECOVERY TABLE ####

recovery_table <- true_params |>
  rename(alpha_true = alpha, beta_true = beta, kappa_true = kappa, delta_true = delta) |>
  left_join(
    recovered_params |> rename(alpha_recovered = alpha, beta_recovered = beta,
                               kappa_recovered = kappa, delta_recovered = delta),
    by = "subject"
  ) |>
  left_join(
    posterior_sds |> pivot_wider(names_from = param_type, values_from = posterior_sd),
    by = "subject"
  ) |>
  select(subject,
         alpha_true, alpha_recovered,
         beta_true, beta_recovered,
         kappa_true, kappa_recovered,
         delta_true, delta_recovered,
         alpha, beta, kappa, delta) |>
  rename(alpha_sd = alpha, beta_sd = beta, kappa_sd = kappa, delta_sd = delta)

#### SAVE RECOVERY TABLE ####

saveRDS(recovery_table, file.path(artifacts_dir, "recovery_table.rds"))
saveRDS(posterior_sds, file.path(artifacts_dir, "posterior_sds.rds"))

#### CREATE SCATTERPLOT: ALPHA ####

plot_alpha <- recovery_table |>
  select(subject, alpha_true, alpha_recovered) |>
  na.omit()

stopifnot(nrow(plot_alpha) > 0)
stopifnot(length(plot_alpha$alpha_true) == length(plot_alpha$alpha_recovered))

alpha_limits <- c(0, 1)
alpha_breaks <- c(0, 0.25, 0.5, 0.75, 1)
alpha_r <- cor(plot_alpha$alpha_true, plot_alpha$alpha_recovered, method = "pearson")

p_alpha <- ggplot(plot_alpha, aes(x = alpha_true, y = alpha_recovered)) +
  geom_point(alpha = 0.6, size = 2, colour = "lightgray") +
  geom_smooth(method = "lm", se = FALSE, colour = "#EE6677", linewidth = 0.8) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60", linewidth = 0.6) +
  annotate(
    "text",
    x = Inf, y = Inf,
    label = sprintf("[Pearson r = %.2f]", alpha_r),
    hjust = 1.05, vjust = 1.4,
    size = 3.5, colour = "grey30"
  ) +
  scale_x_continuous(breaks = alpha_breaks) +
  scale_y_continuous(breaks = alpha_breaks) +
  coord_equal(xlim = alpha_limits, ylim = alpha_limits, clip = "off") +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "none"
  ) +
  labs(x = "True Alpha", y = "Recovered Alpha")

#### CREATE SCATTERPLOT: BETA ####

plot_beta <- recovery_table |>
  select(subject, beta_true, beta_recovered) |>
  na.omit()

stopifnot(nrow(plot_beta) > 0)
stopifnot(length(plot_beta$beta_true) == length(plot_beta$beta_recovered))

beta_limits <- c(0.5, 5.5)
beta_breaks <- c(1, 2, 3, 4, 5)
beta_r <- cor(plot_beta$beta_true, plot_beta$beta_recovered, method = "pearson")

p_beta <- ggplot(plot_beta, aes(x = beta_true, y = beta_recovered)) +
  geom_point(alpha = 0.6, size = 2, colour = "lightgray") +
  geom_smooth(method = "lm", se = FALSE, colour = "#EE6677", linewidth = 0.8) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60", linewidth = 0.6) +
  annotate(
    "text",
    x = Inf, y = Inf,
    label = sprintf("[Pearson r = %.2f]", beta_r),
    hjust = 1.05, vjust = 1.4,
    size = 3.5, colour = "grey30"
  ) +
  scale_x_continuous(breaks = beta_breaks) +
  scale_y_continuous(breaks = beta_breaks) +
  coord_equal(xlim = beta_limits, ylim = beta_limits, clip = "off") +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "none"
  ) +
  labs(x = "True Beta", y = "Recovered Beta")

#### CREATE SCATTERPLOT: KAPPA ####

plot_kappa <- recovery_table |>
  select(subject, kappa_true, kappa_recovered) |>
  na.omit()

stopifnot(nrow(plot_kappa) > 0)
stopifnot(length(plot_kappa$kappa_true) == length(plot_kappa$kappa_recovered))

kappa_limits <- c(0, 1)
kappa_breaks <- c(0, 0.25, 0.5, 0.75, 1)
kappa_r <- cor(plot_kappa$kappa_true, plot_kappa$kappa_recovered, method = "pearson")

p_kappa <- ggplot(plot_kappa, aes(x = kappa_true, y = kappa_recovered)) +
  geom_point(alpha = 0.6, size = 2, colour = "lightgray") +
  geom_smooth(method = "lm", se = FALSE, colour = "#EE6677", linewidth = 0.8) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60", linewidth = 0.6) +
  annotate(
    "text",
    x = Inf, y = Inf,
    label = sprintf("[Pearson r = %.2f]", kappa_r),
    hjust = 1.05, vjust = 1.4,
    size = 3.5, colour = "grey30"
  ) +
  scale_x_continuous(breaks = kappa_breaks) +
  scale_y_continuous(breaks = kappa_breaks) +
  coord_equal(xlim = kappa_limits, ylim = kappa_limits, clip = "off") +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "none"
  ) +
  labs(x = "True Kappa", y = "Recovered Kappa")

#### CREATE SCATTERPLOT: DELTA ####

plot_delta <- recovery_table |>
  select(subject, delta_true, delta_recovered) |>
  na.omit()

stopifnot(nrow(plot_delta) > 0)
stopifnot(length(plot_delta$delta_true) == length(plot_delta$delta_recovered))

delta_range <- range(c(plot_delta$delta_true, plot_delta$delta_recovered))
delta_pad   <- 0.1 * diff(delta_range)
delta_limits <- c(delta_range[1] - delta_pad, delta_range[2] + delta_pad)
delta_breaks <- round(seq(delta_limits[1], delta_limits[2], length.out = 5), 1)
delta_r <- cor(plot_delta$delta_true, plot_delta$delta_recovered, method = "pearson")

p_delta <- ggplot(plot_delta, aes(x = delta_true, y = delta_recovered)) +
  geom_point(alpha = 0.6, size = 2, colour = "lightgray") +
  geom_smooth(method = "lm", se = FALSE, colour = "#EE6677", linewidth = 0.8) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60", linewidth = 0.6) +
  annotate(
    "text",
    x = Inf, y = Inf,
    label = sprintf("[Pearson r = %.2f]", delta_r),
    hjust = 1.05, vjust = 1.4,
    size = 3.5, colour = "grey30"
  ) +
  scale_x_continuous(breaks = delta_breaks) +
  scale_y_continuous(breaks = delta_breaks) +
  coord_equal(xlim = delta_limits, ylim = delta_limits, clip = "off") +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "none"
  ) +
  labs(x = "True Delta", y = "Recovered Delta")

#### EXTRACT POPULATION-LEVEL POSTERIOR DISTRIBUTIONS ####

p_alpha_recovery <- p_alpha
p_beta_recovery <- p_beta
p_kappa_recovery <- p_kappa
p_delta_recovery <- p_delta

#### CREATE POSTERIOR: MU_ALPHA POPULATION POSTERIOR ####

alpha_post_df <- draws_pop |>
  select(mu_alpha) |>
  as_tibble()

xlim_posterior <- function(draws, pad = 0.20) {
  r <- range(draws, na.rm = TRUE)
  span <- diff(r)
  c(r[1] - pad * span, r[2] + pad * span)
}

alpha_draws <- alpha_post_df$mu_alpha
alpha_median <- median(alpha_draws, na.rm = TRUE)
alpha_true <- mu_alpha

p_alpha_posterior <- ggplot(alpha_post_df, aes(x = mu_alpha, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(
    .width = c(0.80, 0.90),
    point_size = 3,
    linewidth = c(2, 1)
  ) +
  geom_vline(xintercept = alpha_true, linetype = "dashed", colour = "grey50", linewidth = 0.6) +
  geom_vline(xintercept = alpha_median, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  scale_x_continuous(limits = c(-3, 3)) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y = element_blank(),
    axis.line.x = element_line(colour = "grey30")
  ) +
  labs(x = expression(paste("Population Alpha (", mu[alpha], ")"))) +
  coord_cartesian(ylim = c(0, 1.3), clip = "off")

#### CREATE POSTERIOR: MU_BETA POPULATION POSTERIOR ####

beta_post_df <- draws_pop |>
  select(mu_beta) |>
  as_tibble()

beta_draws <- beta_post_df$mu_beta
beta_median <- median(beta_draws, na.rm = TRUE)
beta_true <- mu_beta

p_beta_posterior <- ggplot(beta_post_df, aes(x = mu_beta, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(
    .width = c(0.80, 0.90),
    point_size = 3,
    linewidth = c(2, 1)
  ) +
  geom_vline(xintercept = beta_true, linetype = "dashed", colour = "grey50", linewidth = 0.6) +
  geom_vline(xintercept = beta_median, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  scale_x_continuous(limits = c(0, 6)) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y = element_blank(),
    axis.line.x = element_line(colour = "grey30")
  ) +
  labs(x = expression(paste("Population Beta (", mu[beta], ")"))) +
  coord_cartesian(ylim = c(0, 1.3), clip = "off")

#### CREATE POSTERIOR: MU_KAPPA POPULATION POSTERIOR ####

kappa_post_df <- draws_pop |>
  select(mu_kappa) |>
  as_tibble()

kappa_draws <- kappa_post_df$mu_kappa
kappa_median <- median(kappa_draws, na.rm = TRUE)
kappa_true <- mu_kappa

p_kappa_posterior <- ggplot(kappa_post_df, aes(x = mu_kappa, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(
    .width = c(0.80, 0.90),
    point_size = 3,
    linewidth = c(2, 1)
  ) +
  geom_vline(xintercept = kappa_true, linetype = "dashed", colour = "grey50", linewidth = 0.6) +
  geom_vline(xintercept = kappa_median, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  scale_x_continuous(limits = c(-3, 3)) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y = element_blank(),
    axis.line.x = element_line(colour = "grey30")
  ) +
  labs(x = expression(paste("Population Kappa (", mu[kappa], ")"))) +
  coord_cartesian(ylim = c(0, 1.3), clip = "off")

#### CREATE POSTERIOR: MU_DELTA POPULATION POSTERIOR ####

delta_post_df <- draws_pop |>
  select(mu_delta) |>
  as_tibble()

delta_draws <- delta_post_df$mu_delta
delta_median <- median(delta_draws, na.rm = TRUE)
delta_true <- mu_delta

p_delta_posterior <- ggplot(delta_post_df, aes(x = mu_delta, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(
    .width = c(0.80, 0.90),
    point_size = 3,
    linewidth = c(2, 1)
  ) +
  geom_vline(xintercept = delta_true, linetype = "dashed", colour = "grey50", linewidth = 0.6) +
  geom_vline(xintercept = delta_median, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y = element_blank(),
    axis.line.x = element_line(colour = "grey30")
  ) +
  labs(x = expression(paste("Population Delta (", mu[delta], ")"))) +
  coord_cartesian(ylim = c(0, 1.3), clip = "off")

#### COMBINE PANELS ####

p_final <- (p_alpha_posterior | p_beta_posterior) / (p_kappa_posterior | p_delta_posterior) / (p_alpha_recovery | p_beta_recovery) / (p_kappa_recovery | p_delta_recovery) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 14))

#### EXPORT ####

plot_name <- "parameter_recovery_scatter"

ggsave(
  file.path(output_dir, paste0(plot_name, ".pdf")),
  plot = p_final,
  width = 12, height = 18, bg = "white"
)

ggsave(
  file.path(output_dir, paste0(plot_name, ".png")),
  plot = p_final,
  width = 12, height = 18, dpi = 300, bg = "white"
)

message("Parameter recovery analysis complete")
message("  Alpha Pearson r = ", round(alpha_r, 2))
message("  Beta Pearson r = ", round(beta_r, 2))
message("  Kappa Pearson r = ", round(kappa_r, 2))
message("  Delta Pearson r = ", round(delta_r, 2))
