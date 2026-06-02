rm(list = ls())

library(dplyr)
library(readr)
library(ggplot2)
library(patchwork)

DATA_FILE <- "../../data/ioc-task/all-10/ioc-all_69947fa1a4c3da138296e3c4_SESSION_2026-06-02_13h40.25.893.csv"
FIGURES   <- "figures"
dir.create(FIGURES, showWarnings = FALSE)

#### LOAD & PREP ####
df <- read_csv(DATA_FILE, show_col_types = FALSE)

task_df <- df |>
  filter(task == "gambling_choice", block_number != "training") |>
  mutate(
    reward       = as.integer(reward),
    trial_number = as.integer(trial_number),
    block_number = factor(block_number, levels = as.character(1:6),
                          labels = paste("Block", 1:6)),
    machine = case_when(
      choice_key == "arrowleft"  ~ "Left",
      choice_key == "arrowright" ~ "Right",
      choice_key == "arrowup"    ~ "Top",
      TRUE                       ~ NA_character_
    ),
    machine = factor(machine, levels = c("Left", "Top", "Right")),
    outcome = factor(reward, levels = c(0, 1), labels = c("Loss", "Win"))
  ) |>
  filter(!is.na(machine))

# Machine colors: colorblind-safe (orange / sky-blue / bluish-green)
machine_colors <- c(Left = "#E69F00", Top = "#56B4E9", Right = "#009E73")

#### PLOT A: Tile heatmap — choice sequence ####
p_tiles <- ggplot(task_df, aes(x = trial_number, y = block_number)) +
  geom_tile(aes(fill = machine), color = "white", linewidth = 0.5, height = 0.85) +
  geom_point(
    data = task_df |> filter(outcome == "Win"),
    shape = 21, size = 2.2, stroke = 0.6,
    fill = "white", color = "gray20"
  ) +
  scale_fill_manual(values = machine_colors, name = "Machine") +
  scale_x_continuous(breaks = c(1, 5, 10, 15, 20, 25)) +
  labs(
    x = "Trial within block",
    y = NULL,
    title = "Choice sequence",
    subtitle = "Tile color = machine chosen  |  white dot = win"
  ) +
  theme_classic(base_size = 12) +
  theme(
    legend.position = "right",
    axis.line.y     = element_blank(),
    axis.ticks.y    = element_blank(),
    panel.grid.major.x = element_line(color = "gray92", linewidth = 0.3)
  )

#### PLOT B: Choice proportion per block ####
block_counts <- task_df |>
  group_by(block_number, machine) |>
  summarise(n = n(), .groups = "drop") |>
  group_by(block_number) |>
  mutate(prop = n / sum(n))

p_props <- ggplot(block_counts, aes(x = block_number, y = prop, fill = machine)) +
  geom_col(width = 0.7, color = "white", linewidth = 0.4) +
  geom_hline(yintercept = 1/3, linetype = "dashed", color = "gray40", linewidth = 0.5) +
  scale_fill_manual(values = machine_colors, name = "Machine") +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                     breaks = seq(0, 1, 0.25)) +
  labs(
    x = NULL, y = "Proportion of choices",
    title = "Machine preference by block",
    subtitle = "Dashed line = equal 1/3"
  ) +
  theme_classic(base_size = 12) +
  theme(
    legend.position = "none",
    axis.text.x = element_text(angle = 30, hjust = 1)
  )

#### PLOT C: Run length (consecutive stays) ####
task_df_runs <- task_df |>
  arrange(block_number, trial_number) |>
  group_by(block_number) |>
  mutate(
    run_id  = cumsum(machine != lag(machine, default = first(machine))),
    stay    = as.integer(machine == lag(machine))
  ) |>
  ungroup()

run_lengths <- task_df_runs |>
  group_by(block_number, run_id, machine) |>
  summarise(length = n(), .groups = "drop")

p_runs <- ggplot(run_lengths, aes(x = length, fill = machine)) +
  geom_bar(color = "white", linewidth = 0.3) +
  scale_fill_manual(values = machine_colors, name = "Machine") +
  scale_x_continuous(breaks = 1:max(run_lengths$length)) +
  labs(
    x = "Consecutive choices on same machine",
    y = "Count",
    title = "Run lengths (streaks)"
  ) +
  theme_classic(base_size = 12) +
  theme(legend.position = "none")

#### COMBINE ####
combined <- p_tiles / (p_props | p_runs) +
  plot_annotation(
    title    = "Trial-by-Trial Choices — Luck Game",
    subtitle = paste0("Participant: 69947fa1a4c3da138296e3c4  |  ",
                      nrow(task_df), " valid trials across 6 blocks"),
    tag_levels = "A"
  ) &
  theme(plot.tag = element_text(face = "bold"))

ggsave(file.path(FIGURES, "choices_per_trial.png"), combined,
       width = 12, height = 10, dpi = 150, bg = "white")

message("Saved: figures/choices_per_trial.png")
