#### PLOT PARAMETER DISTRIBUTIONS ####

cfg <- readRDS(file.path(artifacts_dir, "cfg.rds"))
individual_params <- read_csv(
  file.path(artifacts_dir, "individual_params.csv"),
  show_col_types = FALSE
)

dist_theme <- theme_minimal(base_size = 13) +
  theme(
    panel.grid   = element_blank(),
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank()
  )

# decay_rl
bw_decay_rl <- 1 / 30
p1 <- ggplot(individual_params, aes(x = decay_rl)) +
  geom_dotplot(binwidth = bw_decay_rl, fill = "#4477AA", colour = "white") +
  scale_x_continuous(limits = c(0, 1)) +
  dist_theme +
  labs(x = "decay_rl", y = NULL)

# decay_h
bw_decay_h <- 1 / 30
p2 <- ggplot(individual_params, aes(x = decay_h)) +
  geom_dotplot(binwidth = bw_decay_h, fill = "#4477AA", colour = "white") +
  scale_x_continuous(limits = c(0, 1)) +
  dist_theme +
  labs(x = "decay_h", y = NULL)

# rho_rl
bw_rho_rl <- diff(range(individual_params$rho_rl)) / 30
p3 <- ggplot(individual_params, aes(x = rho_rl)) +
  geom_dotplot(binwidth = bw_rho_rl, fill = "#4477AA", colour = "white") +
  dist_theme +
  labs(x = "rho_rl", y = NULL)

# rho_h
bw_rho_h <- diff(range(individual_params$rho_h)) / 30
p4 <- ggplot(individual_params, aes(x = rho_h)) +
  geom_dotplot(binwidth = bw_rho_h, fill = "#4477AA", colour = "white") +
  dist_theme +
  labs(x = "rho_h", y = NULL)

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
