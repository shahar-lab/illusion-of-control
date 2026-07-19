#### PLOT PARAMETER DISTRIBUTIONS ####

cfg <- readRDS(file.path(artifacts_dir, "cfg.rds"))
individual_params <- read_csv(
  file.path(artifacts_dir, "individual_params.csv"),
  show_col_types = FALSE
)

dist_theme <- theme_minimal(base_size = 13) +
  theme(
    panel.grid  = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank()
  )

# One dotplot panel per parameter. [0,1]-bounded params (inv_logit link): fixed
# binwidth and scale_x_continuous(limits = c(0, 1)). Unbounded/positive params: binwidth
# derived from the observed range.

# alpha_rl
bw_alpha_rl <- 1 / 30
p1 <- ggplot(individual_params, aes(x = alpha_rl)) +
  geom_dotplot(binwidth = bw_alpha_rl, fill = "#4477AA", colour = "white") +
  scale_x_continuous(limits = c(0, 1)) +
  dist_theme +
  labs(x = "alpha_rl", y = NULL)

# ... repeat for alpha_per (p2, same [0,1] pattern), beta_rl / beta_per (p3/p4, use
# bw_x <- diff(range(individual_params$x)) / 30 with no fixed x limits) ...

fig <- (p1 | p2) / (p3 | p4) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 14))

ggsave(
  file.path(output_dir, "param_distributions.pdf"),
  plot = fig, width = 10, height = 8, bg = "white"
)
ggsave(
  file.path(output_dir, "param_distributions.png"),
  plot = fig, width = 10, height = 8, dpi = 300, bg = "white"
)

cat("Saved: param_distributions.pdf / .png\n")
