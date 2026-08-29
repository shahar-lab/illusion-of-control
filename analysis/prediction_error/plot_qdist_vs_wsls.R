rm(list = ls())

#### SETUP ####
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(stringr)

DATA_DIR   <- "../../data/ioc-all-fixed-pilot/task"
ALPHA_FILE <- "subject_alpha_mle.csv"
OUT_PNG    <- "figures/qdist_vs_wsls.png"

GREY30    <- "#4d4d4d"
GREY65    <- "#a6a6a6"
OI_BLUE   <- "#0072B2"
OI_ORANGE <- "#E69F00"

KEY_TO_CARD <- c(arrowleft = 1L, arrowup = 2L, arrowright = 3L)

# Near-perfect stay/switch behavior drives quasi-complete separation in the
# per-subject WSLS GLM, producing a non-informative, extreme wsls_beta.
OUTLIERS <- c("69b7e04340b00585acbb91ac", "65feaaac53eb219f09ad5ea0")

dir.create("figures", showWarnings = FALSE)

#### LOAD CHOICE DATA ####
files <- sort(list.files(DATA_DIR, pattern = "^ioc-all_.*_SESSION.*\\.csv$", full.names = TRUE))
df_raw <- lapply(files, \(f) {
  pid <- str_extract(f, "[a-f0-9]{24}")
  read_csv(f, show_col_types = FALSE, col_types = cols(.default = col_character())) |>
    mutate(participant = pid)
}) |> bind_rows()

gb <- df_raw |>
  filter(task == "gambling_choice",
         block_number != "training",
         as.logical(is_choice_valid)) |>
  mutate(
    block_number = as.integer(block_number),
    trial_number = as.integer(trial_number),
    reward       = as.numeric(reward),
    arm          = KEY_TO_CARD[choice_key]
  ) |>
  arrange(participant, block_number, trial_number) |>
  group_by(participant) |>
  mutate(trial = row_number()) |>
  ungroup()

#### LOAD SUBJECT-LEVEL LEARNING RATES (MLE fit, classic_qval_and_unchosen_eval_zero) ####
alpha_df <- read_csv(ALPHA_FILE, show_col_types = FALSE) |>
  select(participant, alpha = alpha_rl, understood_eq_felt)

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
  inner_join(alpha_df |> select(participant, understood_eq_felt), by = "participant") |>
  mutate(color_grp = if_else(understood_eq_felt, "understood = felt", "understood != felt")) |>
  filter(!(participant %in% OUTLIERS))

cat(sprintf("Merged subjects (after outlier removal): %d\n", nrow(merged)))

r_pearson <- cor(merged$wsls_beta, merged$qdist_mean)

p <- ggplot(merged, aes(x = wsls_beta, y = qdist_mean)) +
  geom_smooth(method = "lm", formula = y ~ x, colour = OI_BLUE, fill = OI_BLUE, alpha = 0.15, linewidth = 1) +
  geom_point(aes(colour = color_grp), size = 2.5, alpha = 0.85) +
  scale_colour_manual(values = c("understood = felt" = OI_BLUE, "understood != felt" = OI_ORANGE), name = NULL) +
  annotate("text", x = Inf, y = -Inf,
           label = sprintf("Pearson r = %.2f", r_pearson), hjust = 1.1, vjust = -1, size = 3.2, colour = GREY65) +
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
