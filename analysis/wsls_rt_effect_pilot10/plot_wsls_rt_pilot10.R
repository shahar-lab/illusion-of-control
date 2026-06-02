rm(list = ls())

#### SETUP ####
library(ggplot2)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(patchwork)

DATA_DIR  <- "../../data/ioc-all-pilot10"
DRAWS_DIR <- "bayesian_draws"

#### COMPUTE MEAN RT PER SUBJECT ####
all_files <- list.files(DATA_DIR, pattern = "\\.csv$", full.names = TRUE)
df_list   <- list()

for (f in all_files) {
  pid <- str_extract(basename(f), "[a-f0-9]{24}")
  if (is.na(pid)) next
  df_list[[pid]] <- read_csv(f, show_col_types = FALSE) |> mutate(participant = pid)
}

df_rt <- bind_rows(df_list) |>
  filter(task == "gambling_choice", block_number != "training", is_choice_valid == TRUE) |>
  group_by(participant) |>
  summarise(mean_rt = mean(as.numeric(rt), na.rm = TRUE), .groups = "drop")

grand_mean_rt <- mean(df_rt$mean_rt)

#### LOAD POSTERIOR DRAWS ####
draws_1 <- read_csv(file.path(DRAWS_DIR, "posterior_draws_hier_1back.csv"), show_col_types = FALSE) |>
  left_join(df_rt, by = "participant") |> mutate(lag = "1-back")

draws_2 <- read_csv(file.path(DRAWS_DIR, "posterior_draws_hier_2back.csv"), show_col_types = FALSE) |>
  left_join(df_rt, by = "participant") |> mutate(lag = "2-back")

draws_3 <- read_csv(file.path(DRAWS_DIR, "posterior_draws_hier_3back.csv"), show_col_types = FALSE) |>
  left_join(df_rt, by = "participant") |> mutate(lag = "3-back")

#### PLOT HELPERS ####
sym_ylim <- function(draws_df) {
  max_abs <- max(abs(quantile(draws_df$beta, c(0.025, 0.975))))
  c(-max_abs, max_abs) * 1.15
}

theme_posterior <- theme_minimal(base_size = 13) +
  theme(
    panel.grid   = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y  = element_blank(),
    axis.line.x  = element_line(colour = "grey30")
  )

make_panel <- function(draws_df, lag_label, show_x_label = FALSE) {
  ylim <- sym_ylim(draws_df)

  # Summarise per participant: median + 80% + 90% CI (replicating stat_pointinterval)
  summ <- draws_df |>
    group_by(participant, mean_rt) |>
    summarise(
      med    = median(beta),
      lo90   = quantile(beta, 0.05),
      hi90   = quantile(beta, 0.95),
      lo80   = quantile(beta, 0.10),
      hi80   = quantile(beta, 0.90),
      .groups = "drop"
    )

  ggplot(summ, aes(x = mean_rt, y = med)) +
    geom_hline(yintercept = 0,             linetype = "dashed", colour = "grey40", linewidth = 0.6) +
    geom_vline(xintercept = grand_mean_rt, linetype = "dashed", colour = "grey60", linewidth = 0.5) +
    geom_linerange(aes(ymin = lo90, ymax = hi90), linewidth = 0.6, colour = "grey50") +
    geom_linerange(aes(ymin = lo80, ymax = hi80), linewidth = 1.2, colour = "grey30") +
    geom_point(size = 2, colour = "grey20") +
    annotate(
      "text", x = grand_mean_rt, y = ylim[2],
      label = sprintf("Mean RT\n%.0f ms", grand_mean_rt),
      hjust = -0.08, vjust = 1, size = 3, colour = "grey50"
    ) +
    coord_cartesian(ylim = ylim, clip = "off") +
    labs(
      x     = if (show_x_label) "Mean response time (ms)" else NULL,
      y     = NULL,
      title = lag_label
    ) +
    theme_posterior +
    theme(axis.title.x = element_text(size = 11))
}

#### BUILD PANELS ####
p1 <- make_panel(draws_1, "1-back",  show_x_label = FALSE)
p2 <- make_panel(draws_2, "2-back",  show_x_label = FALSE)
p3 <- make_panel(draws_3, "3-back",  show_x_label = TRUE)

combined <- p1 / p2 / p3 +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold"))

dir.create("figures", showWarnings = FALSE)
ggsave("figures/wsls_beta_by_rt.png", combined, width = 7, height = 10, dpi = 150, bg = "white")
message("Saved: figures/wsls_beta_by_rt.png")
