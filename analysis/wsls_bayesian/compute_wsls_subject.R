rm(list = ls())

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(ggplot2)

DATA_DIR <- "../../data/ioc-all-fixed-pilot/task"
OUT_DIR  <- "output"
FIG_DIR  <- "figures"
dir.create(OUT_DIR, showWarnings = FALSE)
dir.create(FIG_DIR, showWarnings = FALSE)

#### LOAD DATA ####
files   <- list.files(DATA_DIR, full.names = TRUE, pattern = "\\.csv$")
df_list <- list()

KEEP_COLS <- c("task", "block_number", "trial_number", "choice_key", "reward", "is_choice_valid")

for (f in files) {
  pid <- str_extract(basename(f), "[a-f0-9]{24}")
  if (is.na(pid)) next
  df_list[[pid]] <- read_csv(f, show_col_types = FALSE) |>
    select(any_of(KEEP_COLS)) |>
    mutate(participant = pid)
}

df <- bind_rows(df_list)
cat("Loaded", length(df_list), "participants,", nrow(df), "total rows\n")

#### FILTER TO VALID STAY/SWITCH TRIALS ####
df <- df |>
  filter(task == "gambling_choice", block_number != "training") |>
  group_by(participant, block_number) |>
  mutate(
    choice_prev   = lag(choice_key,      n = 1),
    reward_prev   = lag(reward,          n = 1),
    is_valid_prev = lag(is_choice_valid, n = 1)
  ) |>
  ungroup() |>
  filter(
    trial_number    > 1,
    is_choice_valid == TRUE,
    is_valid_prev   == TRUE,
    !is.na(choice_prev),
    !is.na(reward_prev)
  ) |>
  mutate(
    stay_ch     = as.integer(choice_key == choice_prev),
    reward_prev = as.integer(reward_prev)
  )

cat("Observations after filtering:", nrow(df), "\n")
cat("Overall P(stay | no reward):", round(mean(df$stay_ch[df$reward_prev == 0]), 3), "\n")
cat("Overall P(stay | reward):   ", round(mean(df$stay_ch[df$reward_prev == 1]), 3), "\n")

#### PER-SUBJECT WSLS EFFECT ####
wsls_subj <- df |>
  group_by(participant) |>
  summarise(
    p_stay_reward   = mean(stay_ch[reward_prev == 1]),
    p_stay_noreward = mean(stay_ch[reward_prev == 0]),
    wsls_effect     = p_stay_reward - p_stay_noreward,
    n_trials        = n(),
    .groups         = "drop"
  )

cat("\nPer-subject WSLS effects:\n")
print(wsls_subj |> select(participant, p_stay_noreward, p_stay_reward, wsls_effect))
cat("\nGroup mean WSLS effect:", round(mean(wsls_subj$wsls_effect), 3),
    "SD:", round(sd(wsls_subj$wsls_effect), 3), "\n")

write_csv(wsls_subj, file.path(OUT_DIR, "wsls_per_subject.csv"))
cat("\nSaved wsls_per_subject.csv\n")

#### SCATTER PLOT: P(stay|no reward) vs P(stay|reward) ####
plot_df <- data.frame(
  x = wsls_subj$p_stay_noreward,
  y = wsls_subj$p_stay_reward
)
plot_df <- plot_df[complete.cases(plot_df), ]
stopifnot(nrow(plot_df) > 0, length(plot_df$x) == length(plot_df$y))

shared_limits <- range(c(plot_df$x, plot_df$y), na.rm = TRUE)
pad           <- 0.07 * diff(shared_limits)
shared_limits <- c(shared_limits[1] - pad, shared_limits[2] + pad)
axis_breaks   <- seq(shared_limits[1], shared_limits[2], length.out = 4)
pearson_r     <- cor(plot_df$x, plot_df$y, method = "pearson")

p_scatter <- ggplot(plot_df, aes(x = x, y = y)) +
  geom_point(colour = "#4477AA", alpha = 0.85, size = 3) +
  geom_smooth(method = "lm", se = FALSE, colour = "#EE6677", linewidth = 0.8) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60") +
  annotate(
    "text",
    x      = Inf, y = Inf,
    label  = sprintf("[Pearson r = %.2f]", pearson_r),
    hjust  = 1.05, vjust = 1.4,
    size   = 3.5, colour = "grey30"
  ) +
  scale_x_continuous(breaks = round(axis_breaks, 2)) +
  scale_y_continuous(breaks = round(axis_breaks, 2)) +
  coord_equal(xlim = shared_limits, ylim = shared_limits, clip = "off") +
  theme_minimal(base_size = 13) +
  theme(panel.grid.minor = element_blank()) +
  labs(
    x = "P(stay | no reward)",
    y = "P(stay | reward)"
  )

ggsave(file.path(FIG_DIR, "wsls_per_subject_scatter.pdf"), p_scatter, width = 5, height = 5)
cat("Saved figures/wsls_per_subject_scatter.pdf\n")
