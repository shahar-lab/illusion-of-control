#### PLOT PARAMETER DISTRIBUTIONS ####

cfg <- readRDS(file.path(artifacts_dir, "cfg.rds"))
individual_params <- read_csv(
  file.path(artifacts_dir, "individual_params.csv"),
  show_col_types = FALSE
)

dist_theme <- theme_minimal(base_size = 13) +
  theme(
    panel.grid = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank()
  )

# alpha_rl
bw_alpha_rl <- 1 / 30
p1 <- ggplot(individual_params, aes(x = alpha_rl)) +
  geom_dotplot(binwidth = bw_alpha_rl, fill = "#4477AA", colour = "white") +
  scale_x_continuous(limits = c(0, 1)) +
  dist_theme +
  labs(x = "alpha_rl", y = NULL)

# alpha_per
bw_alpha_per <- 1 / 30
p2 <- ggplot(individual_params, aes(x = alpha_per)) +
  geom_dotplot(binwidth = bw_alpha_per, fill = "#4477AA", colour = "white") +
  scale_x_continuous(limits = c(0, 1)) +
  dist_theme +
  labs(x = "alpha_per", y = NULL)

# beta_rl
bw_beta_rl <- diff(range(individual_params$beta_rl)) / 30
p3 <- ggplot(individual_params, aes(x = beta_rl)) +
  geom_dotplot(binwidth = bw_beta_rl, fill = "#4477AA", colour = "white") +
  dist_theme +
  labs(x = "beta_rl", y = NULL)

# beta_per
bw_beta_per <- diff(range(individual_params$beta_per)) / 30
p4 <- ggplot(individual_params, aes(x = beta_per)) +
  geom_dotplot(binwidth = bw_beta_per, fill = "#4477AA", colour = "white") +
  dist_theme +
  labs(x = "beta_per", y = NULL)

fig <- (p1 | p2) / (p3 | p4) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 14))

ggsave(
  file.path(output_dir, "param_distributions.pdf"),
  plot = fig,
  width = 10, height = 8, bg = "white"
)
ggsave(
  file.path(output_dir, "param_distributions.png"),
  plot = fig,
  width = 10, height = 8, dpi = 300, bg = "white"
)

cat("Saved: param_distributions.pdf / .png\n")
