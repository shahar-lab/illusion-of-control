rm(list = ls())

#### SETUP ####
library(ggplot2)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(patchwork)

DATA_DIR  <- "../../data/ioc-task/pilot20"
DRAWS_DIR <- "bayesian_draws"

INCLUDED_IDS <- c(
  "6980990e5c9007100eb282b6", "69808775dc84b90f4adafb2f", "61563a4b0def9000ccc976ec",
  "60f19a691466276fe085b461", "69dac2125e535db5a698ea18", "6980792fded33a62e27ce7cc",
  "6981150699107501d80e74b6", "667bd577710d52a05ac09036", "6981e6c2e26c88d954f297eb",
  "69d555ce85e30d6215e559d9", "69829236d776a93cf3afa632", "69d5525ec7afcfce08d8608b",
  "6980d9a70a7862a47c69046d", "6984a9246122d3bd4ca0833e", "69728435c9476fe76dd2ab2f",
  "69e913482ae5864d44e6387c", "697a645e36e6f14eea2b396b", "698341d57fe7b870bddf91b8",
  "697caeea2ec1c2604535f8aa", "62ebe597372fdef388b734b3"
)

#### COMPUTE MEAN RT PER SUBJECT ####
all_files <- list.files(DATA_DIR, full.names = TRUE)
df_list   <- list()

for (f in all_files) {
  pid <- str_extract(f, "[a-f0-9]{24}")
  if (is.na(pid) || !(pid %in% INCLUDED_IDS)) next
  df_list[[pid]] <- read_csv(f, show_col_types = FALSE) |> mutate(participant = pid)
}

df_rt <- bind_rows(df_list) |>
  filter(task == "gambling_choice", block_number != "training", is_choice_valid == TRUE) |>
  group_by(participant) |>
  summarise(mean_rt = mean(as.numeric(rt), na.rm = TRUE), .groups = "drop")

grand_mean_rt <- mean(df_rt$mean_rt)

#### LOAD POSTERIOR DRAWS ####
draws_1 <- read_csv(file.path(DRAWS_DIR, "posterior_draws_hier_1back.csv"), show_col_types = FALSE) |>
  left_join(df_rt, by = "participant") |>
  mutate(lag = "1-back")

draws_2 <- read_csv(file.path(DRAWS_DIR, "posterior_draws_hier_2back.csv"), show_col_types = FALSE) |>
  left_join(df_rt, by = "participant") |>
  mutate(lag = "2-back")

draws_3 <- read_csv(file.path(DRAWS_DIR, "posterior_draws_hier_3back.csv"), show_col_types = FALSE) |>
  left_join(df_rt, by = "participant") |>
  mutate(lag = "3-back")

#### PLOT HELPERS ####
# Symmetric y-axis limits around 0 for each lag
sym_ylim <- function(draws_df) {
  max_abs <- max(abs(quantile(draws_df$beta, c(0.025, 0.975))))
  c(-max_abs, max_abs) * 1.15
}

theme_posterior <- theme_minimal(base_size = 13) +
  theme(
    panel.grid           = element_blank(),
    axis.line.x          = element_line(colour = "grey30"),
    axis.line.y          = element_line(colour = "grey30")
  )

summarise_draws <- function(draws_df) {
  draws_df |>
    group_by(participant, mean_rt) |>
    summarise(
      median  = median(beta),
      lo90    = quantile(beta, 0.05),
      hi90    = quantile(beta, 0.95),
      lo80    = quantile(beta, 0.10),
      hi80    = quantile(beta, 0.90),
      .groups = "drop"
    )
}

make_panel <- function(draws_df, lag_label, show_x_label = FALSE, show_y_label = FALSE) {
  ylim  <- sym_ylim(draws_df)
  sumdf <- summarise_draws(draws_df)

  p <- ggplot(sumdf, aes(x = mean_rt)) +
    # Reference lines
    geom_hline(yintercept  = 0,             linetype = "dashed", colour = "grey40", linewidth = 0.6) +
    geom_vline(xintercept  = grand_mean_rt, linetype = "dashed", colour = "grey60", linewidth = 0.5) +
    # 90% CI (thin) then 80% CI (thick) then median point
    geom_linerange(aes(ymin = lo90, ymax = hi90), linewidth = 0.5, colour = "grey50") +
    geom_linerange(aes(ymin = lo80, ymax = hi80), linewidth = 1.2, colour = "grey30") +
    geom_point(aes(y = median), size = 2, colour = "grey20") +
    annotate(
      "text", x = grand_mean_rt, y = ylim[2],
      label  = sprintf("Mean RT\n%.0f ms", grand_mean_rt),
      hjust  = -0.08, vjust = 1, size = 3, colour = "grey50"
    ) +
    coord_cartesian(ylim = ylim, clip = "off") +
    labs(
      x = if (show_x_label) "Mean response time (ms)" else NULL,
      y = if (show_y_label) "β: effect of prior reward on stay probability (log-odds)" else NULL,
      title = lag_label
    ) +
    theme_posterior +
    theme(axis.title.x = element_text(size = 11))

  p
}

#### BUILD PANELS ####
p1 <- make_panel(draws_1, "1-back",  show_x_label = FALSE, show_y_label = FALSE)
p2 <- make_panel(draws_2, "2-back",  show_x_label = FALSE, show_y_label = TRUE)
p3 <- make_panel(draws_3, "3-back",  show_x_label = TRUE,  show_y_label = FALSE)

combined <- p1 / p2 / p3 +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold"))

dir.create("figures", showWarnings = FALSE)
ggsave("figures/wsls_beta_by_rt.png", combined, width = 7, height = 10, dpi = 150, bg = "white")
message("Saved: figures/wsls_beta_by_rt.png")
