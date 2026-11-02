# reads: artifacts/individual_params.csv · writes: output/03_param_distributions.{pdf,png}

#### PLOT TRUE PARAMETER DISTRIBUTIONS ####

individual_params <- read_csv(file.path(artifacts_dir, "individual_params.csv"), show_col_types = FALSE)

dist_theme <- theme_minimal(base_size = 13) +
  theme(
    panel.grid = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank()
  )

# alpha
bw_alpha <- 1 / 30
p_alpha <- ggplot(individual_params, aes(x = alpha)) +
  geom_dotplot(binwidth = bw_alpha, fill = "#4477AA", colour = "white") +
  scale_x_continuous(limits = c(0, 1)) +
  dist_theme +
  labs(x = "alpha", y = NULL)

# beta
bw_beta <- diff(range(individual_params$beta)) / 30
p_beta <- ggplot(individual_params, aes(x = beta)) +
  geom_dotplot(binwidth = bw_beta, fill = "#4477AA", colour = "white") +
  dist_theme +
  labs(x = "beta", y = NULL)

fig <- (p_alpha | p_beta) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 14))

plot_name <- "03_param_distributions"

ggsave(file.path(output_dir, paste0(plot_name, ".pdf")), plot = fig, width = 10, height = 5, bg = "white")
ggsave(file.path(output_dir, paste0(plot_name, ".png")), plot = fig, width = 10, height = 5, dpi = 300, bg = "white")
write_rds(fig, file.path(artifacts_dir, "03_param_distributions_plot.rds"))
