#### PLOT RANDOM WALK OF ARM EXPECTED VALUES ####

cfg <- readRDS(file.path(artifacts_dir, "cfg.rds"))

walk_df <- as_tibble(t(cfg$expvalues), .name_repair = "unique") |>
  setNames(paste0("arm_", seq_len(cfg$Narms))) |>
  mutate(trial = row_number()) |>
  pivot_longer(-trial, names_to = "arm", values_to = "expvalue")

fig <- ggplot(walk_df, aes(x = trial, y = expvalue, colour = arm)) +
  geom_line(linewidth = 0.8) +
  scale_y_continuous(limits = c(0, 1)) +
  scale_colour_manual(values = c("#4477AA", "#EE6677", "#228833", "#CCBB44")) +
  theme_minimal(base_size = 13) +
  theme(panel.grid.minor = element_blank()) +
  labs(x = "Trial", y = "Expected value", colour = "Arm")

ggsave(
  file.path(output_dir, "random_walk.pdf"),
  plot = fig,
  width = 10, height = 5, bg = "white"
)
ggsave(
  file.path(output_dir, "random_walk.png"),
  plot = fig,
  width = 10, height = 5, dpi = 300, bg = "white"
)

cat("Saved: random_walk.pdf / .png\n")
