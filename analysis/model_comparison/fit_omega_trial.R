rm(list = ls())

# For each subject, estimates omega at every trial using a sliding window of W
# centred on that trial.  omega ∈ [0,1] is the weight on Model 1 (Q+kappa)
# relative to Model 2 (kappa-only):
#
#   P_ω(choice_t) = ω · p_qkappa_t + (1-ω) · p_kappa_t
#
# A window-based estimate lets us track how omega evolves across the session.

library(dplyr)
library(readr)
library(ggplot2)

PREDS_FILE <- "output/trial_predictions.csv"
OUT_DIR    <- "output"
FIG_DIR    <- "figures"
dir.create(FIG_DIR, showWarnings = FALSE)

W <- 40L  # sliding window width (half-window = 20 trials either side)

#### LOAD PREDICTIONS ####
preds <- read_csv(PREDS_FILE, show_col_types = FALSE) |>
  arrange(participant, block_number, trial_number)

#### HELPER: FIT OMEGA ON A WINDOW ####
# Beta(3, 3) log-prior on omega prevents hard snapping to 0/1 in small windows
# (equivalent to 4 soft pseudo-observations pulling toward 0.5).
fit_omega_window <- function(p1, p2) {
  neg_log_post <- function(omega) {
    pc        <- omega * p1 + (1 - omega) * p2
    log_lik   <- sum(log(pmax(pc, 1e-10)))
    log_prior <- (3 - 1) * log(omega) + (3 - 1) * log(1 - omega)  # Beta(3,3)
    -(log_lik + log_prior)
  }
  tryCatch(
    optim(0.5, neg_log_post, method = "Brent", lower = 1e-6, upper = 1 - 1e-6)$par,
    error = function(e) NA_real_
  )
}

#### COMPUTE TRIAL-BY-TRIAL OMEGA PER SUBJECT ####
subjects <- sort(unique(preds$participant))
omega_list <- list()

for (pid in subjects) {
  sp <- preds[preds$participant == pid, ]
  N  <- nrow(sp)
  half_w <- W %/% 2L

  omega_vec <- numeric(N)
  for (t in seq_len(N)) {
    lo <- max(1L,  t - half_w)
    hi <- min(N,   t + half_w)
    omega_vec[t] <- fit_omega_window(sp$p_qkappa[lo:hi], sp$p_kappa[lo:hi])
  }

  omega_list[[pid]] <- data.frame(
    participant  = pid,
    global_trial = seq_len(N),
    block_number = sp$block_number,
    trial_number = sp$trial_number,
    omega        = omega_vec
  )
}

omega_all <- bind_rows(omega_list)
write_csv(omega_all, file.path(OUT_DIR, "omega_trial_trajectory.csv"))
cat("Saved omega_trial_trajectory.csv\n")

#### SELECT EXAMPLE SUBJECT ####
# Pick the subject with the highest within-session SD whose mean omega
# sits between 0.25 and 0.85 — this selects an interesting mid-range trajectory
# rather than a subject that's stuck near 0 or 1 the whole time.
subj_var <- omega_all |>
  group_by(participant) |>
  summarise(mean_omega = mean(omega, na.rm = TRUE),
            sd_omega   = sd(omega,   na.rm = TRUE)) |>
  filter(mean_omega > 0.25, mean_omega < 0.85) |>
  arrange(desc(sd_omega))

example_pid <- subj_var$participant[1]
cat("Example subject:", example_pid,
    sprintf("(mean omega = %.2f, sd = %.2f)\n",
            subj_var$mean_omega[1], subj_var$sd_omega[1]))

ex <- omega_all[omega_all$participant == example_pid, ]

# Block boundary positions (start of each block after the first)
block_starts <- ex |>
  group_by(block_number) |>
  summarise(start_t = min(global_trial), .groups = "drop") |>
  filter(start_t > 1)

#### PLOT ####
p <- ggplot(ex, aes(x = global_trial, y = omega)) +
  # Block boundary lines
  geom_vline(
    data   = block_starts,
    aes(xintercept = start_t),
    linetype = "dotted", colour = "grey70", linewidth = 0.5
  ) +
  # Reference line at omega = 0.5 (equal weight)
  geom_hline(yintercept = 0.5, linetype = "dashed", colour = "grey50", linewidth = 0.5) +
  # Sliding-window omega trajectory
  geom_line(colour = "#4477AA", linewidth = 0.7, alpha = 0.6) +
  geom_smooth(
    method  = "loess", span = 0.35, se = FALSE,
    colour  = "#EE6677", linewidth = 1.0
  ) +
  scale_x_continuous(
    breaks = sort(c(1L, block_starts$start_t)),
    labels = sort(c(1L, block_starts$start_t))
  ) +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.25)) +
  coord_cartesian(xlim = c(1, max(ex$global_trial))) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank()
  ) +
  labs(
    x = "Trial",
    y = expression(omega~"(weight on Q+kappa model)")
  )

ggsave(file.path(FIG_DIR, "omega_trajectory_example.pdf"), p, width = 8, height = 3.5)
cat("Saved figures/omega_trajectory_example.pdf\n")

#### QUICK GROUP SUMMARY ####
group_summary <- omega_all |>
  group_by(participant) |>
  summarise(
    mean_omega = mean(omega, na.rm = TRUE),
    sd_omega   = sd(omega, na.rm = TRUE),
    .groups    = "drop"
  ) |>
  arrange(desc(mean_omega))

cat("\n=== Per-subject omega summary ===\n")
print(group_summary)
cat("\nGroup mean omega:", round(mean(group_summary$mean_omega), 3), "\n")
