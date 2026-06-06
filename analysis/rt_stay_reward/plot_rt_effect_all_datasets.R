rm(list = ls())

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(ggplot2)
library(patchwork)
library(rstanarm)

FIGURES <- "figures"
dir.create(FIGURES, showWarnings = FALSE)

#### HELPER: load, filter to stay trials, return model-ready df ####
load_stay <- function(data_dir, included_ids, filter_unavailable = FALSE) {
  all_files <- list.files(data_dir, full.names = TRUE)
  df_list   <- list()
  for (f in all_files) {
    pid <- str_extract(f, "[a-f0-9]{24}")
    if (is.na(pid) || !(pid %in% included_ids)) next
    df_list[[pid]] <- read_csv(f, show_col_types = FALSE) |> mutate(participant = pid)
  }
  df <- bind_rows(df_list) |>
    filter(task == "gambling_choice") |>
    mutate(
      rt              = suppressWarnings(as.numeric(rt)),
      reward          = as.integer(reward),
      is_choice_valid = as.logical(is_choice_valid),
      block_number    = as.character(block_number),
      trial_number    = as.integer(trial_number)
    ) |>
    filter(block_number != "training", is_choice_valid == TRUE, !is.na(rt)) |>
    group_by(participant, block_number) |>
    arrange(trial_number, .by_group = TRUE) |>
    mutate(
      choice_key_nback = lag(choice_key, n = 1),
      reward_nback     = lag(reward,     n = 1),
      valid_nback      = lag(is_choice_valid, n = 1)
    ) |>
    ungroup()

  base_filter <- quote(!is.na(choice_key_nback) & !is.na(reward_nback) &
                          valid_nback == TRUE & rt > 100 & rt < 5000)
  df <- df |> filter(eval(base_filter))

  if (filter_unavailable) {
    df <- df |> filter(choice_key_nback != unavailable_key)
  }

  df |>
    filter(choice_key == choice_key_nback) |>  # stay trials only
    mutate(
      log_rt       = log(rt),
      reward_label = factor(as.integer(reward_nback), levels = c(0, 1),
                            labels = c("Unrewarded", "Rewarded"))
    )
}

#### DATASET SPECS ####
datasets <- list(
  list(
    label    = "pilot20",
    dir      = "../../data/ioc-task/pilot20",
    ids      = c(
      "6980990e5c9007100eb282b6", "69808775dc84b90f4adafb2f", "61563a4b0def9000ccc976ec",
      "60f19a691466276fe085b461", "69dac2125e535db5a698ea18", "6980792fded33a62e27ce7cc",
      "6981150699107501d80e74b6", "667bd577710d52a05ac09036", "6981e6c2e26c88d954f297eb",
      "69d555ce85e30d6215e559d9", "69829236d776a93cf3afa632", "69d5525ec7afcfce08d8608b",
      "6980d9a70a7862a47c69046d", "6984a9246122d3bd4ca0833e", "69728435c9476fe76dd2ab2f",
      "69e913482ae5864d44e6387c", "697a645e36e6f14eea2b396b", "698341d57fe7b870bddf91b8",
      "697caeea2ec1c2604535f8aa", "62ebe597372fdef388b734b3"
    ),
    filter_unavailable = TRUE
  ),
  list(
    label    = "ioc-all-pilot10",
    dir      = "../../data/ioc-all-pilot10",
    ids      = c(
      "5d1a8d1531978f00019c42bd", "605b838b80f022835fc293fb", "67d0094243dae460e5682b51",
      "6928a6394052fbe76783ed32", "6985a1a2a9b075341a3e65b0", "69947fa1a4c3da138296e3c4",
      "69a1086e0fba8ea789c2ee15", "69a14f0c9cb4d84e02cab2ea", "69ef69fa85d57cec3354845f",
      "6a02cd6171c4d3dcce16c504"
    ),
    filter_unavailable = FALSE
  ),
  list(
    label    = "ioc-one-pilot10",
    dir      = "../../data/ioc-one-piot10",
    ids      = c(
      "57f2da5c6c19420001438d19", "60415858380a051122571d55", "698dff1a795a3ac8f1680ed5",
      "699f4039ddf914372870c431", "69bbe13bdb78ed30b67655e6", "69f1386d8f8e9af4ec5759a7",
      "69ff8f6c58779f2e9509c9ea", "6a0e22d4600e541a0b7459cc", "6a1549dbf86c7917392dbd46",
      "6a20bb2045e8d03e12f71732"
    ),
    filter_unavailable = FALSE
  )
)

#### FIT MODEL FOR EACH DATASET, EXTRACT DIFF POSTERIOR ####
newdata_cond <- data.frame(
  reward_label = factor(c("Unrewarded", "Rewarded"), levels = c("Unrewarded", "Rewarded"))
)

diff_list <- list()

for (ds in datasets) {
  cat("\n===", ds$label, "===\n")
  stay_df <- load_stay(ds$dir, ds$ids, ds$filter_unavailable)
  cat("Stay trials:", nrow(stay_df), "| N subjects:", n_distinct(stay_df$participant), "\n")

  fit <- stan_lmer(
    formula          = log_rt ~ reward_label + (1 + reward_label | participant),
    data             = stay_df,
    prior            = normal(0, 0.5),
    prior_intercept  = normal(7, 1),
    prior_covariance = decov(regularization = 2),
    chains           = 4,
    cores            = 4,
    iter             = 2000,
    warmup           = 1000,
    refresh          = 0,
    seed             = 42
  )

  post_log  <- posterior_linpred(fit, newdata = newdata_cond, re.form = NA)
  diff_draws <- exp(post_log[, 2]) - exp(post_log[, 1])  # Rewarded - Unrewarded

  cat(sprintf("Difference: %.1f ms [90%% CI: %.1f, %.1f] | P(diff<0): %.3f\n",
      median(diff_draws), quantile(diff_draws, 0.05), quantile(diff_draws, 0.95),
      mean(diff_draws < 0)))

  diff_list[[ds$label]] <- data.frame(diff_ms = diff_draws, dataset = ds$label)
}

diff_df <- bind_rows(diff_list) |>
  mutate(dataset = factor(dataset, levels = sapply(datasets, `[[`, "label")))

#### PLOT ####
# Okabe-Ito palette
pal <- c(
  "pilot20"         = "#E69F00",
  "ioc-all-pilot10" = "#56B4E9",
  "ioc-one-pilot10" = "#009E73"
)

# Shared symmetric x-axis across all panels
max_abs <- max(abs(range(diff_df$diff_ms)))
xlims   <- c(-max_abs, max_abs)

# Helper: build one panel for a single dataset
make_panel <- function(ds_label) {
  vals    <- diff_df$diff_ms[diff_df$dataset == ds_label]
  d       <- density(vals, n = 512)
  dens    <- data.frame(x = d$x, y = d$y / max(d$y))
  med_val <- median(vals)
  lo90    <- quantile(vals, 0.05)
  hi90    <- quantile(vals, 0.95)
  pd      <- max(mean(vals > 0), mean(vals < 0)) * 100
  col     <- pal[[ds_label]]

  ggplot(dens, aes(x = x, y = y)) +
    geom_area(fill = col, alpha = 0.50, colour = col, linewidth = 0.3) +
    geom_vline(xintercept = 0,       linetype = "dashed", colour = "grey40", linewidth = 0.7) +
    geom_vline(xintercept = med_val, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
    annotate("text", x = med_val, y = Inf,
             label  = sprintf("[median = %.1f ms, pd = %.1f%%]", med_val, pd),
             hjust  = -0.05, vjust = 1.4, size = 3.0, colour = "grey40") +
    geom_segment(aes(x = lo90, xend = hi90, y = -0.04, yend = -0.04),
                 colour = col, linewidth = 1.5) +
    geom_point(aes(x = med_val, y = -0.04),
               colour = col, size = 3) +
    scale_x_continuous(labels = function(x) paste0(x, " ms")) +
    theme_minimal(base_size = 13) +
    theme(
      panel.grid   = element_blank(),
      axis.title.y = element_blank(),
      axis.text.y  = element_blank(),
      axis.ticks.y = element_blank(),
      axis.line.y  = element_blank(),
      axis.line.x  = element_line(colour = "grey30")
    ) +
    labs(x = ds_label) +
    coord_cartesian(xlim = xlims, ylim = c(-0.15, 1.15), clip = "off")
}

panels <- lapply(levels(diff_df$dataset), make_panel)

combined <- wrap_plots(panels, nrow = 1) +
  plot_annotation(
    tag_levels = "A",
    caption    = paste(
      "Model: log(RT) ~ reward_label + (1 + reward_label | participant), fit on stay trials (choice_keyᵢ = choice_keyᵢ₋₁).",
      "Plotted: posterior of the group-level RT difference (ms) between previous-rewarded and previous-unrewarded stay trials.",
      "Effect = exp(μ_rewarded) − exp(μ_unrewarded), where μ is the population-level linear predictor on the log scale.",
      sep = "\n"
    )
  ) &
  theme(
    plot.tag     = element_text(face = "bold"),
    plot.caption = element_text(size = 8, colour = "grey40", hjust = 0, margin = margin(t = 8))
  )

ggsave(
  file.path(FIGURES, "rt_effect_all_datasets.png"),
  combined,
  width  = 12,
  height = 3.5,
  dpi    = 150,
  bg     = "white"
)
cat("\nSaved:", file.path(FIGURES, "rt_effect_all_datasets.png"), "\n")
