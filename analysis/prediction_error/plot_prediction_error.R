rm(list = ls())

#### SETUP ####
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(stringr)

DATA_DIR   <- "../../data/ioc-all-fixed-pilot/task"
ALPHA_FILE <- "../param_estimation/bayesian_draws_r/posterior_draws_subject.csv"
OUT_PNG    <- "figures/prediction_error_qdist.png"

GREY30   <- "#4d4d4d"
GREY65   <- "#a6a6a6"
OI_BLUE  <- "#0072B2"
OI_ORANGE <- "#E69F00"

KEY_TO_ARM <- c(arrowup = 1L, arrowleft = 2L, arrowright = 3L)

dir.create("figures", showWarnings = FALSE)

#### LOAD CHOICE DATA ####
files <- list.files(DATA_DIR, pattern = "^ioc-all_[a-f0-9]{24}_SESSION.*\\.csv$", full.names = TRUE)
df_raw <- lapply(files, \(f) {
  pid <- regmatches(f, regexpr("[a-f0-9]{24}", f))
  read_csv(f, show_col_types = FALSE, col_types = cols(.default = col_character())) |>
    mutate(participant = pid)
}) |> bind_rows()

gb <- df_raw |>
  filter(task == "gambling_choice",
         as.character(block_number) != "training",
         tolower(as.character(is_choice_valid)) == "true") |>
  mutate(
    block_number = as.integer(block_number),
    trial_number = as.integer(trial_number),
    reward       = as.numeric(reward),
    arm          = KEY_TO_ARM[choice_key]
  ) |>
  arrange(participant, block_number, trial_number) |>
  group_by(participant) |>
  mutate(trial = row_number()) |>
  ungroup()

cat(sprintf("Participants: %d, trials: %d\n", n_distinct(gb$participant), nrow(gb)))

#### LOAD SUBJECT-LEVEL LEARNING RATES (M1, abkd_3arm) ####
alpha_df <- read_csv(ALPHA_FILE, show_col_types = FALSE) |>
  filter(param == "alpha_m1") |>
  select(participant, alpha = median)

#### COMPUTE Q-VALUES, PREDICTION ERROR, AND DISTANCE FROM 0.5 ####
compute_rl <- function(pid) {
  df    <- gb |> filter(participant == pid) |> arrange(trial)
  alpha <- alpha_df$alpha[alpha_df$participant == pid]

  n  <- nrow(df)
  Q  <- rep(0.5, 3)
  pe <- numeric(n)
  qdist <- numeric(n)

  for (t in seq_len(n)) {
    a  <- df$arm[t]
    r  <- df$reward[t]
    qdist[t] <- sum((Q - 0.5)^2)
    pe[t]    <- r - Q[a]
    Q[a]     <- Q[a] + alpha * (r - Q[a])
  }

  data.frame(participant = pid, trial = df$trial, pred_error = pe, q_dist = qdist)
}

results <- lapply(unique(gb$participant), compute_rl) |> bind_rows()

results_long <- results |>
  pivot_longer(c(pred_error, q_dist), names_to = "series", values_to = "value") |>
  mutate(series = recode(series,
    pred_error = "Prediction error (reward - Q_chosen)",
    q_dist     = "Sum of squared Q distance from 0.5"
  ))

#### PLOT ####
p <- ggplot(results_long, aes(x = trial, y = value, colour = series)) +
  geom_hline(yintercept = 0, colour = GREY65, linetype = "dashed", linewidth = 0.4) +
  geom_line(linewidth = 0.5, na.rm = TRUE) +
  scale_colour_manual(values = c(
    "Prediction error (reward - Q_chosen)"     = OI_BLUE,
    "Sum of squared Q distance from 0.5"       = OI_ORANGE
  )) +
  facet_wrap(~ participant, ncol = 5, scales = "free_x") +
  labs(x = "Trial", y = "Value", colour = NULL) +
  theme_minimal(base_size = 9) +
  theme(
    panel.grid      = element_blank(),
    strip.text      = element_text(size = 7),
    axis.line.x     = element_line(colour = GREY30),
    axis.line.y     = element_line(colour = GREY30),
    legend.position = "top",
    plot.background = element_rect(fill = "white", colour = NA)
  )

ggsave(OUT_PNG, p, width = 14, height = 8, dpi = 150, bg = "white")
cat(sprintf("Saved: %s\n", OUT_PNG))
