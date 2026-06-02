rm(list = ls())

#### SETUP ####
library(ggplot2)
library(dplyr)
library(tidyr)
library(readr)

combined <- read_csv("bayesian_draws/rl_qvalues.csv", show_col_types = FALSE)

# Reshape to one row per participant × machine
df_long <- combined |>
  pivot_longer(
    cols = c(Q_blue, Q_green, Q_red, belief_blue, belief_green, belief_red),
    names_to  = c(".value", "machine"),
    names_pattern = "(.+)_(blue|green|red)"
  ) |>
  rename(Q = Q, belief = belief) |>
  mutate(
    machine   = factor(machine, levels = c("blue", "green", "red")),
    belief_01 = belief / 100
  )

# Pearson r
r_all <- cor(df_long$Q, df_long$belief_01, use = "complete.obs")

r_machine <- df_long |>
  group_by(machine) |>
  summarise(r = cor(Q, belief_01, use = "complete.obs"), .groups = "drop")

r_label <- sprintf(
  "r = %.2f (all 30 pts)\nblue: r = %.2f   green: r = %.2f   red: r = %.2f",
  r_all,
  r_machine$r[r_machine$machine == "blue"],
  r_machine$r[r_machine$machine == "green"],
  r_machine$r[r_machine$machine == "red"]
)

machine_cols <- c(blue = "#56B4E9", green = "#009E73", red = "#CC79A7")

ggplot(df_long, aes(x = Q, y = belief_01, color = machine, fill = machine)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed",
              color = "gray50", linewidth = 0.6) +
  geom_smooth(method = "loess", se = TRUE, linewidth = 0.8, alpha = 0.15,
              show.legend = FALSE) +
  geom_point(size = 2.8, alpha = 0.9) +
  scale_color_manual(values = machine_cols, name = "Machine") +
  scale_fill_manual(values  = machine_cols, guide = "none") +
  annotate("text", x = -Inf, y = Inf,
    label = r_label, hjust = -0.04, vjust = 1.25, size = 3, color = "gray30") +
  labs(
    x        = "Final modeled Q-value",
    y        = "Self-reported belief (rescaled 0–1)",
    subtitle = sprintf("Pilot 10 | n = 30 (10 participants × 3 machines) | Pearson r = %.2f", r_all)
  ) +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), clip = "off") +
  theme_classic(base_size = 13) +
  theme(legend.position = "right")

dir.create("figures", showWarnings = FALSE)
ggsave("figures/belief_vs_qvalue.png", width = 7, height = 6, dpi = 150, bg = "white")
message("Saved: figures/belief_vs_qvalue.png")
