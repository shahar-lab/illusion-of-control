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

MISUNDERSTOOD  <- "67dae998d8f2cfb8a8e3bf03"
FELT_DIFFERENT <- c("677009b08130c3028f6a8a6d", "68598a1d4cebd213b2abb1d9",
                    "69b7e04340b00585acbb91ac", "6a0092581cd317f1ff1765a2")

GREY30    <- "#4d4d4d"
GREY40    <- "#666666"
GREY65    <- "#a6a6a6"
OI_BLUE   <- "#0072B2"
OI_ORANGE <- "#E69F00"

ETA0 <- 1   # prior pseudo-count per arm; learning rate on first observation = 1/(ETA0+1)
L0   <- 0   # prior log-odds: 0 = equal prior on controllable vs uncontrollable

#### LOAD DATA ####
files <- list.files(DATA_DIR, pattern = "^ioc-all_[a-f0-9]{24}_SESSION.*\\.csv$",
                    full.names = TRUE)
df_raw <- lapply(files, \(f) {
  pid <- regmatches(f, regexpr("[a-f0-9]{24}", f))
  read_csv(f, show_col_types = FALSE, col_types = cols(.default = col_character())) |>
    mutate(participant = pid)
}) |> bind_rows()

pid_info <- df_raw |>
  distinct(participant) |>
  mutate(understood_eq_felt = !(participant %in% c(MISUNDERSTOOD, FELT_DIFFERENT)))

#### BUILD TRIAL SEQUENCE ####
# Exclude training block and invalid trials; sort globally within each participant
trials <- df_raw |>
  filter(task == "gambling_choice",
         as.character(block_number) != "training",
         tolower(as.character(is_choice_valid)) == "true",
         participant != MISUNDERSTOOD) |>
  mutate(
    block_number = as.integer(block_number),
    trial_number = as.integer(trial_number),
    reward       = as.numeric(reward)
  ) |>
  arrange(participant, block_number, trial_number) |>
  group_by(participant) |>
  mutate(trial_seq = row_number()) |>
  ungroup()

#### COMPUTE W TRAJECTORIES ####
# One global "s"; three arms for "a".
# Two models differ only in how theta_s is defined:
#   Model A: theta_s = 0.5 (constant, the true win rate)
#   Model B: theta_s = cumulative wins / cumulative trials (empirical overall rate)
#
# Controllable model updates theta_sa per arm with a decaying learning rate 1/n_a.
# Log-odds L tracks cumulative evidence favouring uncontrollable over controllable:
#   delta_L = r * log(theta_s / theta_a) + (1-r) * log((1-theta_s) / (1-theta_a))
# Weight: w = 1 / (1 + exp(L))
compute_w <- function(df_pid) {
  eps      <- 1e-8
  arms     <- c("arrowleft", "arrowup", "arrowright")
  theta_sa <- setNames(rep(0.5, 3), arms)   # controllable model per-arm estimates
  n_a      <- setNames(rep(ETA0, 3), arms)  # observation counts (start at pseudo-count)

  L_A <- L0
  L_B <- L0

  cum_wins   <- 0
  cum_trials <- 0

  n   <- nrow(df_pid)
  w_A <- numeric(n)
  w_B <- numeric(n)

  for (t in seq_len(n)) {
    a <- df_pid$choice_key[t]
    r <- df_pid$reward[t]

    # Uncontrollable model predictions
    theta_s_A <- 0.5
    theta_s_B <- if (cum_trials == 0) 0.5 else cum_wins / cum_trials

    # Controllable model prediction for chosen arm
    theta_at <- theta_sa[[a]]

    # Clip to avoid log(0)
    t_at  <- pmax(eps, pmin(1 - eps, theta_at))
    t_s_A <- pmax(eps, pmin(1 - eps, theta_s_A))
    t_s_B <- pmax(eps, pmin(1 - eps, theta_s_B))

    # Log-odds update: positive = evidence for uncontrollable
    dL_A <- r * log(t_s_A / t_at) + (1 - r) * log((1 - t_s_A) / (1 - t_at))
    dL_B <- r * log(t_s_B / t_at) + (1 - r) * log((1 - t_s_B) / (1 - t_at))

    L_A <- L_A + dL_A
    L_B <- L_B + dL_B

    w_A[t] <- 1 / (1 + exp(L_A))
    w_B[t] <- 1 / (1 + exp(L_B))

    # Update controllable model per-arm estimate (decaying learning rate)
    n_a[[a]]      <- n_a[[a]] + 1
    theta_sa[[a]] <- theta_sa[[a]] + (1 / n_a[[a]]) * (r - theta_sa[[a]])

    # Update cumulative stats for Model B
    cum_wins   <- cum_wins + r
    cum_trials <- cum_trials + 1
  }

  tibble(trial_seq = seq_len(n), w_A = w_A, w_B = w_B)
}

w_results <- trials |>
  group_by(participant) |>
  group_modify(~ compute_w(.x)) |>
  ungroup() |>
  left_join(pid_info, by = "participant")

#### PLOT ####
w_long <- w_results |>
  pivot_longer(c(w_A, w_B), names_to = "model", values_to = "w") |>
  mutate(model = factor(model,
    levels = c("w_A", "w_B"),
    labels = c(
      "Model A: theta_s = 0.5 (constant)",
      "Model B: theta_s = cumulative win rate"
    )
  ))

w_mean <- w_long |>
  group_by(model, trial_seq) |>
  summarise(w = mean(w), .groups = "drop")

p <- ggplot(w_long, aes(x = trial_seq, y = w)) +
  geom_line(aes(group = participant, colour = understood_eq_felt),
            alpha = 0.4, linewidth = 0.35) +
  geom_line(data = w_mean, aes(group = model),
            colour = GREY30, linewidth = 1.1) +
  geom_hline(yintercept = 0.5, colour = GREY65, linetype = "dashed", linewidth = 0.5) +
  scale_colour_manual(
    values = c("TRUE" = OI_BLUE, "FALSE" = OI_ORANGE),
    labels = c("TRUE" = "understood = felt (N=13)", "FALSE" = "understood != felt (N=4)"),
    name   = NULL
  ) +
  scale_y_continuous(limits = c(0, 1), breaks = c(0, 0.25, 0.5, 0.75, 1)) +
  scale_x_continuous(breaks = c(1, 50, 100, 150)) +
  facet_wrap(~ model, ncol = 1) +
  labs(
    x = "Trial",
    y = "w  [P(uncontrollable | data)]",
    title = "Adaptive Pavlovian weight over trials (eta0=1, L0=0)",
    caption = "Thin lines = individual subjects. Thick dark line = group mean. Dashed = 0.5."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid       = element_blank(),
    axis.line.x      = element_line(colour = GREY30),
    axis.line.y      = element_line(colour = GREY30),
    strip.text       = element_text(size = 11, colour = GREY30),
    legend.position  = "bottom",
    plot.title       = element_text(size = 13, colour = GREY30),
    plot.caption     = element_text(size = 9, colour = GREY65),
    plot.background  = element_rect(fill = "white", colour = NA),
    panel.background = element_rect(fill = "white", colour = NA)
  )

ggsave(file.path(OUT_DIR, "adaptive_w.png"), p,
       width = 9, height = 8, dpi = 150, bg = "white")
cat("Saved: figures/adaptive_w.png\n")
