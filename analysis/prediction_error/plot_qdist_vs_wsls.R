rm(list = ls())

#### SETUP ####
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)

DATA_DIR   <- "../../data/ioc-all-fixed-pilot/task"
ALPHA_FILE <- "../param_estimation/bayesian_draws_r/posterior_draws_subject.csv"
OUT_PNG    <- "figures/qdist_vs_wsls.png"

GREY30    <- "#4d4d4d"
GREY65    <- "#a6a6a6"
OI_BLUE   <- "#0072B2"
OI_ORANGE <- "#E69F00"

KEY_TO_ARM <- c(arrowup = 1L, arrowleft = 2L, arrowright = 3L)

MISUNDERSTOOD  <- "67dae998d8f2cfb8a8e3bf03"
FELT_DIFFERENT <- c("677009b08130c3028f6a8a6d", "68598a1d4cebd213b2abb1d9",
                    "69b7e04340b00585acbb91ac", "6a0092581cd317f1ff1765a2")

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

#### LOAD SUBJECT-LEVEL LEARNING RATES (M1, abkd_3arm) ####
alpha_df <- read_csv(ALPHA_FILE, show_col_types = FALSE) |>
  filter(param == "alpha_m1") |>
  select(participant, alpha = median)

#### PER-TRIAL Q-DISTANCE FROM 0.5 (RESCORLA-WAGNER FORWARD PASS) ####
compute_qdist <- function(pid) {
  df    <- gb |> filter(participant == pid) |> arrange(trial)
  alpha <- alpha_df$alpha[alpha_df$participant == pid]

  n     <- nrow(df)
  Q     <- rep(0.5, 3)
  qdist <- numeric(n)

  for (t in seq_len(n)) {
    a <- df$arm[t]
    r <- df$reward[t]
    qdist[t] <- sum((Q - 0.5)^2)
    Q[a] <- Q[a] + alpha * (r - Q[a])
  }

  data.frame(participant = pid, qdist_mean = mean(qdist))
}

qdist_summary <- lapply(unique(gb$participant), compute_qdist) |> bind_rows()

#### PER-SUBJECT WSLS EFFECT (lag-1 logistic regression, cross-block pairs kept) ####
wsls_df <- gb |>
  group_by(participant) |>
  mutate(stay = as.integer(choice_key == lag(choice_key)),
         reward_nback = lag(reward)) |>
  ungroup() |>
  filter(!is.na(stay), !is.na(reward_nback))

wsls_betas <- wsls_df |>
  group_by(participant) |>
  summarise(wsls_beta = coef(glm(stay ~ reward_nback, family = binomial(), data = pick(everything())))["reward_nback"],
            .groups = "drop")

#### MERGE AND PLOT ####
merged <- qdist_summary |>
  inner_join(wsls_betas, by = "participant") |>
  mutate(
    understood_eq_felt = !(participant %in% MISUNDERSTOOD) & !(participant %in% FELT_DIFFERENT),
    color_grp = if_else(understood_eq_felt, "understood = felt", "understood != felt")
  )

r_pearson <- cor(merged$wsls_beta, merged$qdist_mean)

p <- ggplot(merged, aes(x = wsls_beta, y = qdist_mean)) +
  geom_smooth(method = "lm", formula = y ~ x, colour = OI_BLUE, fill = OI_BLUE, alpha = 0.15, linewidth = 1) +
  geom_point(aes(colour = color_grp), size = 2.5, alpha = 0.85) +
  scale_colour_manual(values = c("understood = felt" = OI_BLUE, "understood != felt" = OI_ORANGE), name = NULL) +
  annotate("text", x = max(merged$wsls_beta), y = max(merged$qdist_mean),
           label = sprintf("Pearson r = %.2f", r_pearson), hjust = 1, vjust = 1, size = 3.2, colour = GREY65) +
  labs(x = expression("WSLS reward effect (" * beta[j] * ", log-odds)"),
       y = "Mean Q-distance from 0.5\n(summed squared, per-trial average)") +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid     = element_blank(),
    axis.line.x    = element_line(colour = GREY30),
    axis.line.y    = element_line(colour = GREY30),
    legend.position = "bottom",
    plot.background = element_rect(fill = "white", colour = NA)
  )

ggsave(OUT_PNG, p, width = 7, height = 6, dpi = 150, bg = "white")
cat(sprintf("Saved: %s\n", OUT_PNG))
