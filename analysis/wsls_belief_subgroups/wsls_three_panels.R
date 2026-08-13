rm(list = ls())

#### SETUP ####
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(patchwork)
library(rstanarm)

DATA_DIR <- "../../data/ioc-all-fixed-pilot/task"
OUT_DIR  <- "figures"
dir.create(OUT_DIR, showWarnings = FALSE)

GREY30 <- "#4d4d4d"
GREY40 <- "#666666"
GREY65 <- "#a6a6a6"
GREY80 <- "#cccccc"

MISUNDERSTOOD <- c(
  "67dae998d8f2cfb8a8e3bf03",
  "6a087d170d5521dd2055e045",
  "6a0ac6bc5fb56e6d7f8e6569"
)
FELT_DIFFERENT <- c(
  "677009b08130c3028f6a8a6d", "68598a1d4cebd213b2abb1d9",
  "69b7e04340b00585acbb91ac", "6a0092581cd317f1ff1765a2",
  "5c41f9ce4fe4f800016dfaac", "651d64e4756ee3358eeb981f",
  "6982544679288685d8a0199f", "69a7048762f2aacbfb3c2f02",
  "69de2b262f16bdb2c0122847", "6a01c4c8248651c0157c76c5"
)

GROUPS <- list(
  list(label = "All participants (N=35)",       exclude = character(0)),
  list(label = "Understood correctly (N=32)",   exclude = MISUNDERSTOOD),
  list(label = "Felt = instructed (N=22)",      exclude = c(MISUNDERSTOOD, FELT_DIFFERENT))
)

# ── load data ─────────────────────────────────────────────────────────────────
files <- list.files(DATA_DIR, pattern = "^ioc-all_[a-f0-9]{24}_SESSION.*\\.csv$", full.names = TRUE)
df_raw <- lapply(files, \(f) {
  pid <- regmatches(f, regexpr("[a-f0-9]{24}", f))
  read_csv(f, show_col_types = FALSE, col_types = cols(.default = col_character())) |>
    mutate(participant = pid)
}) |> bind_rows()

gb <- df_raw |>
  filter(task == "gambling_choice", as.character(block_number) != "training") |>
  mutate(block_number = as.character(block_number),
         trial_number = as.numeric(trial_number),
         reward       = as.numeric(reward)) |>
  arrange(participant, block_number, trial_number)

records <- list()
for (key in unique(paste(gb$participant, gb$block_number, sep = "__"))) {
  parts <- strsplit(key, "__")[[1]]
  pid <- parts[1]; blk <- parts[2]
  grp <- gb |> filter(participant == pid, block_number == blk)
  n   <- nrow(grp)
  if (n <= 1) next
  for (i in 2:n) {
    row <- grp[i, ]; nback <- grp[i - 1, ]
    if (!isTRUE(as.logical(row$is_choice_valid))) next
    if (!isTRUE(as.logical(nback$is_choice_valid))) next
    if (is.na(nback$choice_key) || is.na(nback$reward)) next
    records[[length(records) + 1]] <- data.frame(
      participant  = pid,
      stay         = as.integer(row$choice_key == nback$choice_key),
      reward_nback = as.integer(as.numeric(nback$reward))
    )
  }
}
df_wsls <- bind_rows(records)

# ── posterior panel builder ────────────────────────────────────────────────────
make_panel <- function(df, group_info, add_xlabel = FALSE) {
  df_grp <- df |> filter(!(participant %in% group_info$exclude))

  fit <- stan_glm(
    stay ~ reward_nback, data = df_grp, family = binomial(),
    prior_intercept = normal(0, 2), prior = normal(0, 2),
    chains = 4, iter = 2000, warmup = 1000, seed = 42, refresh = 0
  )
  beta_draws <- as.vector(as.matrix(fit)[, "reward_nback"])

  med  <- median(beta_draws)
  pd   <- max(mean(beta_draws > 0), mean(beta_draws < 0)) * 100
  ci90 <- quantile(beta_draws, c(0.05, 0.95))
  ann  <- sprintf("[median = %.2f, pd = %.1f%%]", med, pd)

  df_kde <- data.frame(x = beta_draws)

  ggplot(df_kde, aes(x = x)) +
    stat_density(aes(y = after_stat(density / max(density))), geom = "area",
                 fill = GREY80, colour = NA, bw = "SJ") +
    geom_vline(xintercept = 0,   colour = GREY40, linetype = "dashed", linewidth = 0.9) +
    geom_vline(xintercept = med, colour = GREY65, linetype = "dashed", linewidth = 0.4) +
    annotate("segment", x = ci90[1], xend = ci90[2], y = -0.09, yend = -0.09,
             colour = GREY30, linewidth = 0.9) +
    annotate("point",   x = med, y = -0.09, colour = GREY30, size = 1.8) +
    annotate("text", x = med, y = 0.88, label = ann,
             hjust = 0.5, vjust = 0, size = 2.5, colour = GREY40) +
    coord_cartesian(ylim = c(-0.17, 1.35), clip = "off") +
    labs(title = group_info$label,
         x = if (add_xlabel) "beta  (reward effect on log-odds of staying)" else NULL) +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid    = element_blank(),
      axis.title.y  = element_blank(),
      axis.text.y   = element_blank(),
      axis.ticks.y  = element_blank(),
      axis.line.x   = element_line(colour = GREY30),
      axis.title.x  = element_text(size = 11, colour = "black"),
      axis.text.x   = element_text(size = 9),
      plot.title    = element_text(size = 10, hjust = 0.5),
      plot.background  = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA)
    )
}

# ── build and combine panels ───────────────────────────────────────────────────
panels <- lapply(seq_along(GROUPS), \(i)
  make_panel(df_wsls, GROUPS[[i]], add_xlabel = (i == length(GROUPS))))

fig <- Reduce(`|`, panels) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold"))

ggsave(file.path(OUT_DIR, "wsls_three_panels.png"), fig,
       width = 12, height = 4, dpi = 150, bg = "white")
cat("Saved: figures/wsls_three_panels.png\n")
