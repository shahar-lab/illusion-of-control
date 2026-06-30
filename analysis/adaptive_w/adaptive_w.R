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

ETA0      <- 1     # prior pseudo-count per arm; learning rate on first observation = 1/(ETA0+1)
ETA0_S_A  <- 100   # prior pseudo-count for theta_s, Model A (near-constant, slow-adapting)
ETA0_S_B  <- 1     # prior pseudo-count for theta_s, Model B (fast-adapting, cumulative-like)
L0        <- 0     # prior log-odds: 0 = equal prior on controllable vs uncontrollable

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
# Both theta_s (uncontrollable model) and theta_sa (controllable model, per arm) are
# tracked with the *same* incremental Bayesian running-mean update,
#   theta <- theta + (1/n) * (r - theta),
# starting from a prior mean of 0.5 with n initialised to a pseudo-count eta0
# (learning rate on the first observation = 1/(eta0+1)). The two models differ only
# in the size of theta_s's pseudo-count:
#   Model A: eta0_s = 100 (theta_s stays close to the prior 0.5, slow-adapting)
#   Model B: eta0_s = 1   (theta_s adapts quickly, ~ cumulative win rate)
# theta_s updates every trial regardless of which arm was chosen, since there is
# only one global stimulus.
#
# Log-odds L tracks cumulative evidence favouring uncontrollable over controllable:
#   delta_L = r * log(theta_s / theta_a) + (1-r) * log((1-theta_s) / (1-theta_a))
# Weight: w = P(uncontrollable | data) = 1 / (1 + exp(-L))
compute_w <- function(df_pid) {
  eps      <- 1e-8
  arms     <- c("arrowleft", "arrowup", "arrowright")
  theta_sa <- setNames(rep(0.5, 3), arms)   # controllable model per-arm estimates
  n_a      <- setNames(rep(ETA0, 3), arms)  # observation counts (start at pseudo-count)

  theta_s_A <- 0.5
  theta_s_B <- 0.5
  n_s_A     <- ETA0_S_A
  n_s_B     <- ETA0_S_B

  L_A <- L0
  L_B <- L0

  n   <- nrow(df_pid)
  w_A <- numeric(n)
  w_B <- numeric(n)

  for (t in seq_len(n)) {
    a <- df_pid$choice_key[t]
    r <- df_pid$reward[t]

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

    w_A[t] <- 1 / (1 + exp(-L_A))
    w_B[t] <- 1 / (1 + exp(-L_B))

    # Update controllable model per-arm estimate (decaying learning rate)
    n_a[[a]]      <- n_a[[a]] + 1
    theta_sa[[a]] <- theta_sa[[a]] + (1 / n_a[[a]]) * (r - theta_sa[[a]])

    # Update uncontrollable model estimates (decaying learning rate, every trial)
    n_s_A     <- n_s_A + 1
    theta_s_A <- theta_s_A + (1 / n_s_A) * (r - theta_s_A)
    n_s_B     <- n_s_B + 1
    theta_s_B <- theta_s_B + (1 / n_s_B) * (r - theta_s_B)
  }

  tibble(trial_seq = seq_len(n), w_A = w_A, w_B = w_B)
}

w_results <- trials |>
  group_by(participant) |>
  group_modify(~ compute_w(.x)) |>
  ungroup() |>
  left_join(pid_info, by = "participant")

#### PLOT ####
# Give each participant a short numeric label, sorted by understood_eq_felt then participant
w_results <- w_results |>
  arrange(understood_eq_felt, participant) |>
  mutate(subj_label = sprintf("S%02d", as.integer(factor(participant, levels = unique(participant)))))

# Re-attach subj_label to long format
w_long <- w_results |>
  pivot_longer(c(w_A, w_B), names_to = "model", values_to = "w") |>
  mutate(model = factor(model,
    levels = c("w_A", "w_B"),
    labels = c("A: theta_s slow (eta0=100)", "B: theta_s fast (eta0=1)")
  ))

# One row per subject with the panel background fill encoding group membership
bg_data <- w_results |>
  distinct(subj_label, understood_eq_felt) |>
  mutate(bg_fill = if_else(understood_eq_felt,
                           scales::alpha(OI_BLUE,   0.07),
                           scales::alpha(OI_ORANGE, 0.12)))

# Add bg_fill to w_long so geom_rect can find it per facet
w_long <- w_long |>
  left_join(bg_data, by = "subj_label")

p <- ggplot(w_long, aes(x = trial_seq, y = w, colour = model, group = model)) +
  geom_rect(aes(xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf, fill = bg_fill),
            inherit.aes = FALSE, data = distinct(w_long, subj_label, bg_fill)) +
  scale_fill_identity() +
  geom_hline(yintercept = 0.5, colour = GREY65, linetype = "dashed", linewidth = 0.4) +
  geom_line(linewidth = 0.55, alpha = 0.85) +
  scale_colour_manual(
    values = c("A: theta_s slow (eta0=100)" = GREY30, "B: theta_s fast (eta0=1)" = OI_ORANGE),
    name   = "Model"
  ) +
  scale_y_continuous(limits = c(0, 1), breaks = c(0, 0.5, 1),
                     labels = c("0", ".5", "1")) +
  scale_x_continuous(breaks = c(1, 75, 150)) +
  facet_wrap(~ subj_label, ncol = 5) +
  labs(
    x     = "Trial",
    y     = "w  [P(uncontrollable | data)]",
    title = "Adaptive w per subject (eta0_arm = 1, L0 = 0)",
    caption = paste0("Panel background: blue = understood = felt (N=13), ",
                     "orange = understood != felt (N=4). Dashed = 0.5.")
  ) +
  theme_minimal(base_size = 10) +
  theme(
    panel.grid        = element_blank(),
    axis.line.x       = element_line(colour = GREY30, linewidth = 0.3),
    axis.line.y       = element_line(colour = GREY30, linewidth = 0.3),
    axis.text         = element_text(size = 7, colour = GREY40),
    axis.title        = element_text(size = 10, colour = GREY30),
    strip.text        = element_text(size = 8, colour = GREY30, face = "bold"),
    strip.background  = element_rect(fill = "white", colour = NA),
    legend.position   = "bottom",
    legend.text       = element_text(size = 9),
    plot.title        = element_text(size = 12, colour = GREY30),
    plot.caption      = element_text(size = 8, colour = GREY65),
    plot.background   = element_rect(fill = "white", colour = NA),
    panel.background  = element_rect(fill = "white", colour = NA),
    panel.spacing     = unit(0.6, "lines")
  )

ggsave(file.path(OUT_DIR, "adaptive_w.png"), p,
       width = 12, height = 10, dpi = 150, bg = "white")
cat("Saved: figures/adaptive_w.png\n")
