rm(list = ls())

#### SETUP ####
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(patchwork)

DATA_DIR <- "../../data/ioc-all-fixed-pilot/task"
OUT_DIR  <- "figures"
dir.create(OUT_DIR, showWarnings = FALSE)

GREY30 <- "#4d4d4d"
GREY40 <- "#666666"
GREY65 <- "#a6a6a6"
GREY80 <- "#cccccc"
OI_BLUE   <- "#56B4E9"
OI_ORANGE <- "#E69F00"

MISUNDERSTOOD  <- "67dae998d8f2cfb8a8e3bf03"
FELT_DIFFERENT <- c("677009b08130c3028f6a8a6d", "68598a1d4cebd213b2abb1d9",
                    "69b7e04340b00585acbb91ac", "6a0092581cd317f1ff1765a2")

GROUPS <- list(
  list(label = "All participants",    exclude = character(0),                              n_omit = 0),
  list(label = "Understood correctly", exclude = MISUNDERSTOOD,                            n_omit = 1),
  list(label = "Felt = instructed",    exclude = c(MISUNDERSTOOD, FELT_DIFFERENT),         n_omit = 5)
)

# ── load data ─────────────────────────────────────────────────────────────────
files <- list.files(DATA_DIR, pattern = "^ioc-all_[a-f0-9]{24}_SESSION.*\\.csv$", full.names = TRUE)
df_raw <- lapply(files, \(f) {
  pid <- regmatches(f, regexpr("[a-f0-9]{24}", f))
  read_csv(f, show_col_types = FALSE, col_types = cols(.default = col_character())) |>
    mutate(participant = pid)
}) |> bind_rows()

# ── build lag-1 wsls data ─────────────────────────────────────────────────────
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

# ── panel builder ─────────────────────────────────────────────────────────────
make_panel <- function(df, group_info, add_xlabel = FALSE) {
  df_grp <- df |> filter(!(participant %in% group_info$exclude))
  n      <- n_distinct(df_grp$participant)

  fit   <- glm(stay ~ reward_nback, data = df_grp, family = binomial())
  b_med <- coef(fit)["reward_nback"]
  b_se  <- summary(fit)$coefficients["reward_nback", "Std. Error"]
  beta_draws <- rnorm(4000, b_med, b_se)

  med  <- median(beta_draws)
  pd   <- max(mean(beta_draws > 0), mean(beta_draws < 0)) * 100
  ci90 <- quantile(beta_draws, c(0.05, 0.95))
  ann  <- sprintf("[median = %.2f, pd = %.1f%%]", med, pd)

  subtitle <- sprintf("N = %d", n)
  if (group_info$n_omit > 0) subtitle <- sprintf("%s (-%d excluded)", subtitle, group_info$n_omit)

  # Per-subject p(stay | reward) and p(stay | no reward)
  props <- df_grp |>
    group_by(participant, reward_nback) |>
    summarise(p_stay = mean(stay), .groups = "drop") |>
    mutate(condition = ifelse(reward_nback == 0, "No reward", "Reward"))

  set.seed(0)
  p_box <- ggplot(props, aes(x = condition, y = p_stay,
                              fill = condition, colour = condition)) +
    geom_boxplot(width = 0.45, outlier.shape = NA, colour = "black",
                 linewidth = 0.4, alpha = 0.75) +
    geom_jitter(width = 0.13, size = 1.5, alpha = 0.85, show.legend = FALSE) +
    scale_fill_manual(values = c("No reward" = OI_ORANGE, "Reward" = OI_BLUE)) +
    scale_colour_manual(values = c("No reward" = OI_ORANGE, "Reward" = OI_BLUE)) +
    scale_y_continuous(limits = c(0, 1.05), breaks = c(0, .25, .5, .75, 1),
                       labels = c("0", ".25", ".50", ".75", "1")) +
    labs(title = group_info$label, subtitle = subtitle,
         y = "p(stay)", x = if (add_xlabel) "Condition" else NULL) +
    theme_minimal(base_size = 11) +
    theme(
      legend.position  = "none",
      panel.grid       = element_blank(),
      axis.line.x      = element_line(colour = GREY30),
      axis.line.y      = element_line(colour = GREY30),
      plot.background  = element_rect(fill = "white", colour = NA)
    )

  p_box
}

# ── assemble ──────────────────────────────────────────────────────────────────
panels <- lapply(seq_along(GROUPS), \(i)
  make_panel(df_wsls, GROUPS[[i]], add_xlabel = (i == length(GROUPS))))

fig <- Reduce(`|`, panels) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold"))

ggsave(file.path(OUT_DIR, "wsls_three_panels_r.png"), fig,
       width = 12, height = 4, dpi = 150, bg = "white")
cat("Saved: figures/wsls_three_panels_r.png\n")
