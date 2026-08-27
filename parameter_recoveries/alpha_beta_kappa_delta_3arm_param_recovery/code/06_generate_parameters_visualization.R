# reads: artifacts/simulation_config.rds, artifacts/true_parameters.rds · writes: output/true_parameters.pdf/png

#### LOAD CONFIGURATION ####

simulation_config <- readRDS(file.path(artifacts_dir, "simulation_config.rds"))
list2env(simulation_config, envir = environment())

#### LOAD ARTIFACTS ####

true_parameters <- readRDS(file.path(artifacts_dir, "true_parameters.rds"))

#### CREATE VISUALIZATIONS ####

# Alpha dotplot with theoretical density overlay
alpha_range <- seq(0.01, 0.99, length.out = 100)
alpha_theoretical <- tibble(
  alpha = alpha_range,
  density = dnorm(log(alpha / (1 - alpha)), mean = mu_alpha,
                  sd = sigma_alpha) / (alpha * (1 - alpha))
)

p_alpha <- true_parameters |>
  ggplot(aes(x = alpha)) +
  geom_dotplot(binwidth = 0.03, alpha = 0.6, fill = "#E69F00",
               color = "black", stackdir = "up", stackratio = 0.7) +
  geom_line(data = alpha_theoretical, aes(y = density), color = "#E69F00",
            linewidth = 1, linetype = "dashed") +
  labs(title = "Alpha Distribution (Learning Rate)",
       x = "Alpha", y = NULL) +
  theme_minimal() +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank())

# Beta dotplot with theoretical density overlay
beta_range <- seq(min(true_parameters$beta) - 1,
                  max(true_parameters$beta) + 1, length.out = 100)
beta_theoretical <- tibble(
  beta = beta_range,
  density = dnorm(beta, mean = mu_beta, sd = sigma_beta)
)

p_beta <- true_parameters |>
  ggplot(aes(x = beta)) +
  geom_dotplot(binwidth = 0.1, alpha = 0.6, fill = "#56B4E9",
               color = "black", stackdir = "up", stackratio = 0.7) +
  geom_line(data = beta_theoretical, aes(y = density), color = "#56B4E9",
            linewidth = 1, linetype = "dashed") +
  labs(title = "Beta Distribution (Inverse Temperature)",
       x = "Beta", y = NULL) +
  theme_minimal() +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank())

# Kappa dotplot with theoretical density overlay
kappa_range <- seq(0.01, 0.99, length.out = 100)
kappa_theoretical <- tibble(
  kappa = kappa_range,
  density = dnorm(log(kappa / (1 - kappa)), mean = mu_kappa,
                  sd = sigma_kappa) / (kappa * (1 - kappa))
)

p_kappa <- true_parameters |>
  ggplot(aes(x = kappa)) +
  geom_dotplot(binwidth = 0.03, alpha = 0.6, fill = "#009E73",
               color = "black", stackdir = "up", stackratio = 0.7) +
  geom_line(data = kappa_theoretical, aes(y = density), color = "#009E73",
            linewidth = 1, linetype = "dashed") +
  labs(title = "Kappa Distribution (Perseveration Rate)",
       x = "Kappa", y = NULL) +
  theme_minimal() +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank())

# Delta dotplot with theoretical density overlay
delta_range <- seq(min(true_parameters$delta) - 1,
                   max(true_parameters$delta) + 1, length.out = 100)
delta_theoretical <- tibble(
  delta = delta_range,
  density = dnorm(delta, mean = mu_delta, sd = sigma_delta)
)

p_delta <- true_parameters |>
  ggplot(aes(x = delta)) +
  geom_dotplot(binwidth = 0.1, alpha = 0.6, fill = "#CC79A7",
               color = "black", stackdir = "up", stackratio = 0.7) +
  geom_line(data = delta_theoretical, aes(y = density), color = "#CC79A7",
            linewidth = 1, linetype = "dashed") +
  labs(title = "Delta Distribution (Perseveration Weight)",
       x = "Delta", y = NULL) +
  theme_minimal() +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank())

# Combine plots
true_parameters_plot <- (p_alpha | p_beta) / (p_kappa | p_delta) +
  plot_annotation(title = "True Parameters",
                  theme = theme(plot.title = element_text(size = 14, face = "bold")))

#### EXPORT VISUALIZATION ####

ggsave(file.path(output_dir, "true_parameters.pdf"), true_parameters_plot,
       width = 10, height = 8)
ggsave(file.path(output_dir, "true_parameters.png"), true_parameters_plot,
       width = 10, height = 8, dpi = 300)

message("Parameter visualization saved to output/")
