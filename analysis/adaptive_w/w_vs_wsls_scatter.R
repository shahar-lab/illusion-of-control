rm(list = ls())

#### SETUP ####
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)

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

ETA0     <- 1
ETA0_S_B <- 1
L0       <- 0

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
  filter(participant != MISUNDERSTOOD) |>
  mutate(understood_eq_felt = !(participant %in% FELT_DIFFERENT))

#### BUILD TRIAL SEQUENCE ####
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

#### COMPUTE MEAN W_B PER SUBJECT ####
compute_w_B <- function(df_pid) {
  eps       <- 1e-8
  arms      <- c("arrowleft", "arrowup", "arrowright")
  theta_sa  <- setNames(rep(0.5, 3), arms)
  n_a       <- setNames(rep(ETA0, 3), arms)
  theta_s_B <- 0.5
  n_s_B     <- ETA0_S_B
  L_B       <- L0
  n         <- nrow(df_pid)
  w_B       <- numeric(n)

  for (t in seq_len(n)) {
    a <- df_pid$choice_key[t]
    r <- df_pid$reward[t]
    t_at  <- pmax(eps, pmin(1 - eps, theta_sa[[a]]))
    t_s_B <- pmax(eps, pmin(1 - eps, theta_s_B))
    dL_B  <- r * log(t_s_B / t_at) + (1 - r) * log((1 - t_s_B) / (1 - t_at))
    L_B   <- L_B + dL_B
    w_B[t] <- 1 / (1 + exp(-L_B))
    n_a[[a]]      <- n_a[[a]] + 1
    theta_sa[[a]] <- theta_sa[[a]] + (1 / n_a[[a]]) * (r - theta_sa[[a]])
    n_s_B     <- n_s_B + 1
    theta_s_B <- theta_s_B + (1 / n_s_B) * (r - theta_s_B)
  }

  tibble(mean_w_B = mean(w_B))
}

w_subj <- trials |>
  group_by(participant) |>
  group_modify(~ compute_w_B(.x)) |>
  ungroup()

#### COMPUTE PER-SUBJECT WSLS EFFECT SIZE ####
# Per-subject logistic regression beta (reward effect on log-odds of staying),
# lag-1 pairs per participant x block — same approach as wm_wsls/wm_wsls.R
gb <- df_raw |>
  filter(task == "gambling_choice", as.character(block_number) != "training",
         participant != MISUNDERSTOOD) |>
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

wsls_subj <- df_wsls |>
  group_by(participant) |>
  summarise(wsls_effect = {
    fit <- glm(stay ~ reward_nback, family = binomial(), data = pick(everything()))
    coef(fit)["reward_nback"]
  }, .groups = "drop")

#### COMBINE ####
S02 <- "68598a1d4cebd213b2abb1d9"  # low w outlier excluded
S03 <- "69b7e04340b00585acbb91ac"  # extreme WSLS beta (logistic MLE blowup) excluded

plot_df <- w_subj |>
  left_join(wsls_subj, by = "participant") |>
  left_join(pid_info,  by = "participant") |>
  filter(complete.cases(mean_w_B, wsls_effect), !participant %in% c(S02, S03))

stopifnot(nrow(plot_df) == n_distinct(plot_df$participant))

#### SCATTER PLOT ####
pearson_r <- cor(plot_df$wsls_effect, plot_df$mean_w_B, method = "pearson")

x_breaks <- seq(floor(min(plot_df$wsls_effect) * 10) / 10,
                ceiling(max(plot_df$wsls_effect) * 10) / 10,
                length.out = 4)
y_breaks <- seq(floor(min(plot_df$mean_w_B) * 10) / 10,
                ceiling(max(plot_df$mean_w_B) * 10) / 10,
                length.out = 4)

p <- ggplot(plot_df, aes(x = wsls_effect, y = mean_w_B)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60") +
  geom_smooth(method = "lm", se = FALSE, colour = GREY65, linewidth = 0.8) +
  geom_point(aes(colour = understood_eq_felt), size = 3, alpha = 0.85) +
  scale_colour_manual(
    values = c("TRUE" = OI_BLUE, "FALSE" = OI_ORANGE),
    labels = c("TRUE" = "understood = felt", "FALSE" = "understood != felt"),
    name   = NULL
  ) +
  annotate("text",
           x = Inf, y = Inf,
           label = sprintf("[Pearson r = %.2f]", pearson_r),
           hjust = 1.05, vjust = 1.4,
           size = 3.5, colour = GREY40) +
  scale_x_continuous(breaks = round(x_breaks, 2)) +
  scale_y_continuous(breaks = round(y_breaks, 3)) +
  coord_cartesian(xlim = range(plot_df$wsls_effect) + c(-0.05, 0.05),
                  ylim = range(plot_df$mean_w_B)    + c(-0.05, 0.05)) +
  labs(x = "WSLS beta  [reward effect on log-odds of staying, lag-1]",
       y = "Mean w  [P(uncontrollable | data), Model B]") +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid.minor  = element_blank(),
    panel.grid.major  = element_line(colour = "#e5e5e5"),
    axis.line.x       = element_line(colour = GREY30, linewidth = 0.3),
    axis.line.y       = element_line(colour = GREY30, linewidth = 0.3),
    axis.text         = element_text(colour = GREY40),
    axis.title        = element_text(colour = GREY30, size = 11),
    legend.position   = "bottom",
    legend.text       = element_text(size = 10, colour = GREY40),
    plot.background   = element_rect(fill = "white", colour = NA),
    panel.background  = element_rect(fill = "white", colour = NA)
  )

ggsave(file.path(OUT_DIR, "w_vs_wsls_scatter.png"), p,
       width = 6, height = 6, dpi = 150, bg = "white")
cat("Saved: figures/w_vs_wsls_scatter.png\n")
