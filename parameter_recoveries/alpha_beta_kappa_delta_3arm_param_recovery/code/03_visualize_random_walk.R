# reads: artifacts/simulation_config.RData, artifacts/expvalues.rds · writes: output/random_walk.pdf, output/random_walk.png

#### LOAD SIMULATION PARAMETERS ####

load(file.path(artifacts_dir, "simulation_config.RData"))

#### LOAD RANDOM WALK ####

expvalues <- readRDS(file.path(artifacts_dir, "expvalues.rds"))

#### PREPARE DATA FOR VISUALIZATION ####

colnames(expvalues) <- 1:ncol(expvalues)
expvalues_tidy <- as.data.frame(expvalues) |>
  rownames_to_column("arm") |>
  as_tibble() |>
  pivot_longer(-arm, names_to = "trial", values_to = "reward_prob") |>
  mutate(arm = as.integer(arm), trial = as.integer(trial))

#### CREATE VISUALIZATION ####

p_random_walk <- expvalues_tidy |>
  ggplot(aes(x = trial, y = reward_prob, color = factor(arm))) +
  geom_line(linewidth = 0.8, alpha = 0.8) +
  scale_color_manual(
    values = c("#E69F00", "#56B4E9", "#009E73", "#F0E442"),
    name = "Arm"
  ) +
  labs(
    title = "Reward Probability Trajectories (Random Walk)",
    x = "Trial",
    y = "P(Reward)"
  ) +
  theme_minimal() +
  theme(
    legend.position = "top",
    plot.title = element_text(size = 14, face = "bold")
  )

#### EXPORT VISUALIZATION ####

ggsave(file.path(output_dir, "random_walk.pdf"), p_random_walk,
       width = 10, height = 6)
ggsave(file.path(output_dir, "random_walk.png"), p_random_walk,
       width = 10, height = 6, dpi = 300)

message("Random walk visualization saved to output/")
