rm(list = ls())

#### SETUP ####
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(patchwork)

DATA_DIR <- "../../data/ioc-all-fixed-pilot/task"
OUT_PNG  <- "wsls_18_overview.png"
WINDOW   <- 30

MISUNDERSTOOD  <- "67dae998d8f2cfb8a8e3bf03"
FELT_DIFFERENT <- c("677009b08130c3028f6a8a6d", "68598a1d4cebd213b2abb1d9",
                    "69b7e04340b00585acbb91ac", "6a0092581cd317f1ff1765a2")
OMITTED <- c(MISUNDERSTOOD, FELT_DIFFERENT)

OI_BLUE   <- "#0072B2"
OI_ORANGE <- "#E69F00"
GREY30    <- "#4d4d4d"

# ── load data ─────────────────────────────────────────────────────────────────
files  <- list.files(DATA_DIR, pattern = "^ioc-all_[a-f0-9]{24}_SESSION.*\\.csv$", full.names = TRUE)
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
    block_number        = as.integer(block_number),
    trial_number        = as.numeric(trial_number),
    reward              = as.numeric(reward),
    understood_eq_felt  = !(participant %in% OMITTED)
  ) |>
  arrange(participant, block_number, trial_number)

cat(sprintf("Subjects: %d\n", n_distinct(gb$participant)))

# ── per-subject running WSLS and overall stay rates ──────────────────────────
pids <- sort(unique(gb$participant))

running_list <- list()
scatter_rows <- list()

for (pid in pids) {
  df <- gb |> filter(participant == pid) |>
    mutate(
      stay         = as.integer(choice_key == lag(choice_key)),
      reward_nback = lag(reward)
    ) |>
    filter(!is.na(stay), !is.na(reward_nback))

  n <- nrow(df)
  if (n < WINDOW + 1) next

  wsls <- rep(NA_real_, n)
  for (t in WINDOW:n) {
    w      <- df[(t - WINDOW + 1):t, ]
    p_win  <- mean(w$stay[w$reward_nback == 1], na.rm = TRUE)
    p_loss <- mean(w$stay[w$reward_nback == 0], na.rm = TRUE)
    if (!is.na(p_win) && !is.na(p_loss)) wsls[t] <- p_win - p_loss
  }

  running_list[[pid]] <- data.frame(
    participant        = pid,
    trial              = seq_len(n),
    wsls               = wsls,
    understood_eq_felt = df$understood_eq_felt[1]
  )

  p_win_overall  <- mean(df$stay[df$reward_nback == 1], na.rm = TRUE)
  p_loss_overall <- mean(df$stay[df$reward_nback == 0], na.rm = TRUE)
  scatter_rows[[pid]] <- data.frame(
    participant        = pid,
    p_win              = p_win_overall,
    p_loss             = p_loss_overall,
    understood_eq_felt = df$understood_eq_felt[1]
  )
}

df_running <- bind_rows(running_list)
df_scatter <- bind_rows(scatter_rows)

# ── group mean lines ──────────────────────────────────────────────────────────
max_trial <- max(df_running$trial)
group_mean_wsls <- df_running |>
  group_by(understood_eq_felt, trial) |>
  summarise(wsls = mean(wsls, na.rm = TRUE), .groups = "drop")

# ── Panel 1: running WSLS ────────────────────────────────────────────────────
block_lines <- c(51, 76, 101, 126)

p_running <- ggplot() +
  geom_vline(xintercept = block_lines, colour = "#dddddd", linewidth = 0.8) +
  geom_hline(yintercept = 0, colour = "#888888", linetype = "dashed", linewidth = 0.8) +
  geom_line(data = df_running,
            aes(x = trial, y = wsls, group = participant,
                colour = understood_eq_felt),
            linewidth = 0.6, alpha = 0.45, na.rm = TRUE) +
  geom_line(data = group_mean_wsls,
            aes(x = trial, y = wsls, colour = understood_eq_felt),
            linewidth = 2.0, na.rm = TRUE) +
  scale_colour_manual(
    values = c("TRUE" = OI_BLUE, "FALSE" = OI_ORANGE),
    labels = c("TRUE" = "understood = felt", "FALSE" = "understood ≠ felt"),
    name   = NULL
  ) +
  scale_x_continuous(limits = c(WINDOW + 1, max_trial)) +
  scale_y_continuous(limits = c(-1.05, 1.05)) +
  labs(x = "Trial number", y = "P(stay|win) − P(stay|loss)") +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid      = element_blank(),
    axis.line.x     = element_line(colour = GREY30),
    axis.line.y     = element_line(colour = GREY30),
    axis.title      = element_text(size = 13),
    axis.text       = element_text(size = 9),
    legend.text     = element_text(size = 11),
    legend.position = "bottom",
    plot.background = element_rect(fill = "white", colour = NA)
  )

# ── Panel 2: scatter P(stay|win) vs P(stay|loss) ─────────────────────────────
r_pearson <- cor(df_scatter$p_loss, df_scatter$p_win, use = "complete.obs")

p_scatter <- ggplot(df_scatter, aes(x = p_loss, y = p_win)) +
  geom_abline(slope = 1, intercept = 0, colour = "#888888", linetype = "dashed", linewidth = 0.9) +
  geom_point(aes(colour = understood_eq_felt), size = 2.5, alpha = 0.85) +
  scale_colour_manual(
    values = c("TRUE" = OI_BLUE, "FALSE" = OI_ORANGE),
    guide  = "none"
  ) +
  annotate("text", x = 0.97, y = 0.97,
           label = sprintf("[Pearson r = %.2f]", r_pearson),
           hjust = 1, vjust = 1, size = 3, colour = "#555555") +
  scale_x_continuous(limits = c(0, 1), breaks = seq(0, 1, length.out = 4)) +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, length.out = 4)) +
  coord_fixed() +
  labs(x = "P(stay | loss)", y = "P(stay | win)") +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid      = element_blank(),
    axis.line.x     = element_line(colour = GREY30),
    axis.line.y     = element_line(colour = GREY30),
    axis.title      = element_text(size = 13),
    axis.text       = element_text(size = 9),
    plot.background = element_rect(fill = "white", colour = NA)
  )

# ── combine and save ──────────────────────────────────────────────────────────
fig <- p_running | p_scatter
ggsave(OUT_PNG, fig, width = 12, height = 5, dpi = 150, bg = "white")
cat(sprintf("Saved → %s\n", OUT_PNG))
