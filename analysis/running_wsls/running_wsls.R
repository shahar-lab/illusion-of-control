rm(list = ls())

#### SETUP ####
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(patchwork)
library(stringr)

DATA_DIR <- "../../data/ioc-all-fixed-pilot/task"
OUT_PNG  <- "running_wsls.png"
WINDOW   <- 30

MISUNDERSTOOD  <- "67dae998d8f2cfb8a8e3bf03"
FELT_DIFFERENT <- c("677009b08130c3028f6a8a6d", "68598a1d4cebd213b2abb1d9",
                    "69b7e04340b00585acbb91ac", "6a0092581cd317f1ff1765a2")

LINE_COL  <- "#0072B2"
ZERO_COL  <- "#888888"
BLOCK_COL <- "#cccccc"
GREY30    <- "#4d4d4d"

# ── load data ─────────────────────────────────────────────────────────────────
files <- list.files(DATA_DIR, pattern = "^ioc-all_[a-f0-9]{24}_SESSION.*\\.csv$", full.names = TRUE)
df_raw <- lapply(files, \(f) {
  pid <- regmatches(f, regexpr("[a-f0-9]{24}", f))
  read_csv(f, show_col_types = FALSE, col_types = cols(.default = col_character())) |>
    mutate(participant = pid)
}) |> bind_rows()

included <- df_raw |>
  distinct(participant) |>
  filter(!(participant %in% c(MISUNDERSTOOD, FELT_DIFFERENT))) |>
  pull(participant)

cat(sprintf("Included subjects: %d\n", length(included)))

# ── build per-subject trial sequence ─────────────────────────────────────────
gb <- df_raw |>
  filter(task == "gambling_choice",
         as.character(block_number) != "training",
         participant %in% included) |>
  mutate(block_number = as.character(block_number),
         trial_number = as.numeric(trial_number),
         reward       = as.numeric(reward),
         is_valid     = tolower(as.character(is_choice_valid)) == "true") |>
  arrange(participant, block_number, trial_number)

# ── compute running WSLS per subject ─────────────────────────────────────────
compute_running <- function(pid) {
  df <- gb |> filter(participant == pid, is_valid)
  n  <- nrow(df)
  if (n < WINDOW + 1) return(NULL)

  # lag-1 stay/reward pairs
  df <- df |>
    mutate(
      stay         = as.integer(choice_key == lag(choice_key)),
      reward_nback = lag(reward)
    ) |>
    filter(!is.na(stay), !is.na(reward_nback))

  n2 <- nrow(df)
  if (n2 < WINDOW) return(NULL)

  # compute block boundaries for shading
  block_starts <- which(df$block_number != lag(df$block_number, default = ""))

  wsls <- rep(NA_real_, n2)
  for (t in WINDOW:n2) {
    window <- df[(t - WINDOW + 1):t, ]
    p_rew   <- mean(window$stay[window$reward_nback == 1], na.rm = TRUE)
    p_norew <- mean(window$stay[window$reward_nback == 0], na.rm = TRUE)
    if (!is.na(p_rew) && !is.na(p_norew)) wsls[t] <- p_rew - p_norew
  }

  data.frame(
    participant = pid,
    trial       = seq_len(n2),
    wsls        = wsls
  )
}

results <- lapply(included, compute_running) |> bind_rows()

# sort by median WSLS effect
order_pid <- results |>
  group_by(participant) |>
  summarise(med = median(wsls, na.rm = TRUE)) |>
  arrange(med) |>
  pull(participant)

results$participant <- factor(results$participant, levels = order_pid)

# ── plot ──────────────────────────────────────────────────────────────────────
p <- ggplot(results, aes(x = trial, y = wsls)) +
  geom_hline(yintercept = 0, colour = ZERO_COL, linetype = "dashed", linewidth = 0.5) +
  geom_line(colour = LINE_COL, linewidth = 0.6, na.rm = TRUE) +
  facet_wrap(~ participant, ncol = 5, scales = "free_x") +
  scale_y_continuous(limits = c(-1, 1)) +
  labs(x = "Trial", y = "Running WSLS effect\np(stay|win) − p(stay|lose)") +
  theme_minimal(base_size = 9) +
  theme(
    panel.grid    = element_blank(),
    strip.text    = element_text(size = 7),
    axis.line.x   = element_line(colour = GREY30),
    axis.line.y   = element_line(colour = GREY30),
    plot.background = element_rect(fill = "white", colour = NA)
  )

ggsave(OUT_PNG, p, width = 12, height = 6, dpi = 150, bg = "white")
cat(sprintf("Saved: %s\n", OUT_PNG))
