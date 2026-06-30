rm(list = ls())

#### SETUP ####
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(stringr)

args        <- commandArgs(trailingOnly = TRUE)
DATA_DIR    <- if (length(args) >= 1) args[1] else "../../data/ioc-all-fixed-pilot/task"
N_QUANTILES <- 10
OUT_DIR     <- "figures"
dir.create(OUT_DIR, showWarnings = FALSE)

GREY30  <- "#4d4d4d"
GREY40  <- "#666666"
OI_BLUE <- "#0072B2"

# ── load data ─────────────────────────────────────────────────────────────────
files <- list.files(DATA_DIR, pattern = "[a-f0-9]{24}.*\\.csv$", full.names = TRUE)
df_raw <- files |>
  lapply(\(f) {
    pid <- regmatches(f, regexpr("[a-f0-9]{24}", f))
    read_csv(f, show_col_types = FALSE, col_types = cols(.default = col_character())) |>
      mutate(participant = pid)
  }) |>
  bind_rows()

cat(sprintf("Loaded %d subjects\n", n_distinct(df_raw$participant)))

# ── build lag-1 stay/switch dataset ──────────────────────────────────────────
gb <- df_raw |>
  filter(task == "gambling_choice", as.character(block_number) != "training") |>
  mutate(
    block_number   = as.character(block_number),
    trial_number   = as.numeric(trial_number),
    reward         = as.numeric(reward),
    rt             = as.numeric(rt)
  ) |>
  arrange(participant, block_number, trial_number)

records <- list()
for (key in unique(paste(gb$participant, gb$block_number, sep = "__"))) {
  parts <- strsplit(key, "__")[[1]]
  pid   <- parts[1]; blk <- parts[2]
  grp   <- gb |> filter(participant == pid, block_number == blk)
  n     <- nrow(grp)
  if (n <= 1) next
  for (i in 2:n) {
    row   <- grp[i, ]
    nback <- grp[i - 1, ]
    if (!isTRUE(as.logical(row$is_choice_valid))) next
    if (!isTRUE(as.logical(nback$is_choice_valid))) next
    if (is.na(nback$choice_key) || is.na(nback$reward)) next
    if (is.na(row$rt) || as.numeric(row$rt) <= 0) next
    records[[length(records) + 1]] <- data.frame(
      participant  = pid,
      stay         = as.integer(row$choice_key == nback$choice_key),
      reward_nback = as.integer(as.numeric(nback$reward)),
      rt           = as.numeric(row$rt)
    )
  }
}
df <- bind_rows(records)
cat(sprintf("Total trials: %d  |  Subjects: %d\n", nrow(df), n_distinct(df$participant)))

# ── vincentizing ──────────────────────────────────────────────────────────────
bin_labels <- 1:N_QUANTILES
probs      <- seq(0, 1, length.out = N_QUANTILES + 1)

subject_effects <- list()
subject_rt_mids <- list()

for (pid in unique(df$participant)) {
  grp <- df |> filter(participant == pid)
  boundaries <- quantile(grp$rt, probs)
  grp$rt_bin <- cut(grp$rt, breaks = boundaries, labels = bin_labels, include.lowest = TRUE)

  effects <- numeric(N_QUANTILES)
  rt_mids <- numeric(N_QUANTILES)
  for (b in bin_labels) {
    trials <- grp |> filter(rt_bin == b)
    if (nrow(trials) < 5) { effects[b] <- NA; rt_mids[b] <- NA; next }
    rew   <- trials |> filter(reward_nback == 1)
    norew <- trials |> filter(reward_nback == 0)
    p_r  <- if (nrow(rew)   > 0) mean(rew$stay)   else NA
    p_nr <- if (nrow(norew) > 0) mean(norew$stay) else NA
    effects[b] <- if (!is.na(p_r) && !is.na(p_nr)) p_r - p_nr else NA
    rt_mids[b] <- median(trials$rt)
  }
  subject_effects[[pid]] <- effects
  subject_rt_mids[[pid]] <- rt_mids
}

effects_mat <- do.call(rbind, subject_effects)
rt_mids_mat <- do.call(rbind, subject_rt_mids)

n_valid     <- colSums(!is.na(effects_mat))
mean_effect <- colMeans(effects_mat, na.rm = TRUE)
se_effect   <- apply(effects_mat, 2, \(x) sd(x, na.rm = TRUE) / sqrt(sum(!is.na(x))))
mean_rt     <- colMeans(rt_mids_mat, na.rm = TRUE)

cat("\nVincentized WSLS effect by RT quantile:\n")
for (i in seq_along(mean_rt))
  cat(sprintf("  Q%02d: RT=%.0f ms  effect=%.3f ± %.3f\n", i, mean_rt[i], mean_effect[i], se_effect[i]))

# ── plot ──────────────────────────────────────────────────────────────────────
df_plot <- data.frame(
  rt     = mean_rt,
  effect = mean_effect,
  se     = se_effect,
  bin    = bin_labels
)

p <- ggplot(df_plot, aes(x = rt, y = effect)) +
  geom_ribbon(aes(ymin = effect - se, ymax = effect + se), fill = OI_BLUE, alpha = 0.18) +
  geom_line(colour = OI_BLUE, linewidth = 2.0) +
  geom_point(colour = OI_BLUE, size = 2.5, fill = "white",
             shape = 21, stroke = 0.6) +
  geom_hline(yintercept = 0, colour = GREY40, linetype = "dashed", linewidth = 0.9) +
  scale_x_continuous(
    limits = range(mean_rt) + c(-30, 30),
    sec.axis = sec_axis(
      ~ .,
      breaks = mean_rt,
      labels = sprintf("Q%d", bin_labels),
      name   = NULL,
      guide  = guide_axis(angle = 0)
    )
  ) +
  labs(
    x = "RT (ms) — quantile midpoint",
    y = "WSLS effect\np(stay|reward) - p(stay|no reward)"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid        = element_blank(),
    axis.line.x.bottom = element_line(colour = GREY30),
    axis.line.x.top   = element_line(colour = GREY30),
    axis.line.y       = element_line(colour = GREY30),
    axis.text         = element_text(size = 9),
    axis.text.x.top   = element_text(size = 7.5),
    axis.ticks.x.top  = element_line(colour = GREY30, linewidth = 0.3),
    axis.title        = element_text(size = 10),
    plot.background   = element_rect(fill = "white", colour = NA)
  )

ggsave(file.path(OUT_DIR, "wsls_effect_by_rt_quantile.png"), p,
       width = 7, height = 3.5, dpi = 150, bg = "white")
cat(sprintf("\nSaved: %s/wsls_effect_by_rt_quantile.png\n", OUT_DIR))
