# reads: artifacts/cfg.rds · writes: output/02_reward_schedule.{pdf,png}

#### PLOT REWARD SCHEDULE ####

cfg <- read_rds(file.path(artifacts_dir, "cfg.rds"))

schedule <- as_tibble(t(cfg$expvalues), .name_repair = ~ paste0("arm_", seq_along(.x))) |>
  mutate(trial = row_number()) |>
  pivot_longer(starts_with("arm_"), names_to = "arm", values_to = "p_win")

p <- ggplot(schedule, aes(x = trial, y = p_win, colour = arm)) +
  geom_line(linewidth = 0.8) +
  scale_colour_manual(values = c("#E69F00", "#56B4E9", "#009E73")) +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.25)) +
  theme_minimal(base_size = 13) +
  theme(panel.grid.minor = element_blank()) +
  labs(x = "Trial", y = "p(win)", colour = "Arm")

plot_name <- "02_reward_schedule"

ggsave(file.path(output_dir, paste0(plot_name, ".pdf")), plot = p, width = 10, height = 4, bg = "white")
ggsave(file.path(output_dir, paste0(plot_name, ".png")), plot = p, width = 10, height = 4, dpi = 300, bg = "white")
