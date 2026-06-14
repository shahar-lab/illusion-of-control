rm(list = ls())

library(dplyr)
library(readr)
library(ggplot2)

OMEGA_FILE <- "output/omega_trial_trajectory.csv"
FIG_DIR    <- "figures"
dir.create(FIG_DIR, showWarnings = FALSE)

#### LOAD ####
omega_all <- read_csv(OMEGA_FILE, show_col_types = FALSE) |>
  arrange(participant, block_number, trial_number)

# Short subject labels (S01–S16), ordered by mean omega descending
subj_order <- omega_all |>
  group_by(participant) |>
  summarise(mean_omega = mean(omega, na.rm = TRUE)) |>
  arrange(desc(mean_omega)) |>
  mutate(label = sprintf("S%02d", row_number()))

omega_all <- omega_all |>
  left_join(subj_order |> select(participant, label), by = "participant") |>
  mutate(label = factor(label, levels = subj_order$label))

# Block boundary positions (first global trial of each block after block 1)
block_starts <- omega_all |>
  group_by(participant, label, block_number) |>
  summarise(start_t = min(global_trial), .groups = "drop") |>
  filter(start_t > 1)

#### 4×4 PANEL PLOT ####
p <- ggplot(omega_all, aes(x = global_trial, y = omega)) +
  geom_vline(
    data     = block_starts,
    aes(xintercept = start_t),
    linetype = "dotted", colour = "grey75", linewidth = 0.4
  ) +
  geom_hline(yintercept = 0.5, linetype = "dashed", colour = "grey55", linewidth = 0.4) +
  geom_line(colour = "#4477AA", linewidth = 0.55, alpha = 0.85) +
  facet_wrap(~label, nrow = 4, ncol = 4) +
  scale_x_continuous(breaks = c(1, 75, 150)) +
  scale_y_continuous(limits = c(0, 1), breaks = c(0, 0.5, 1),
                     labels = c("0", ".5", "1")) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid       = element_blank(),
    panel.border     = element_rect(colour = "grey85", fill = NA, linewidth = 0.4),
    strip.text       = element_text(size = 9, margin = margin(b = 2)),
    axis.text        = element_text(size = 7, colour = "grey40"),
    axis.ticks       = element_line(colour = "grey70", linewidth = 0.3),
    axis.ticks.length = unit(2, "pt"),
    panel.spacing    = unit(4, "pt")
  ) +
  labs(x = "Trial", y = expression(omega))

ggsave(file.path(FIG_DIR, "omega_all_subjects_4x4.pdf"), p,
       width = 9, height = 7)
cat("Saved figures/omega_all_subjects_4x4.pdf\n")
