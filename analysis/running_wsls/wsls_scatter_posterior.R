rm(list = ls())

#### SETUP ####
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(patchwork)
library(rstanarm)

DATA_DIR  <- "../../data/ioc-all-fixed-pilot/task"
OUT_PNG   <- "wsls_scatter_posterior.png"

MISUNDERSTOOD <- c(
  "67dae998d8f2cfb8a8e3bf03",
  "6a087d170d5521dd2055e045",
  "6a0ac6bc5fb56e6d7f8e6569"
)
FELT_DIFFERENT <- c(
  "677009b08130c3028f6a8a6d", "68598a1d4cebd213b2abb1d9",
  "69b7e04340b00585acbb91ac", "6a0092581cd317f1ff1765a2",
  "5c41f9ce4fe4f800016dfaac", "651d64e4756ee3358eeb981f",
  "6982544679288685d8a0199f", "69a7048762f2aacbfb3c2f02",
  "69de2b262f16bdb2c0122847", "6a01c4c8248651c0157c76c5"
)
OMITTED <- c(MISUNDERSTOOD, FELT_DIFFERENT)

OI_BLUE   <- "#0072B2"
OI_ORANGE <- "#E69F00"
GREY30    <- "#4d4d4d"
GREY40    <- "#666666"
GREY65    <- "#a6a6a6"
GREY80    <- "#cccccc"

# ── load task data ────────────────────────────────────────────────────────────
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
    block_number       = as.integer(block_number),
    trial_number       = as.numeric(trial_number),
    reward             = as.numeric(reward),
    understood_eq_felt = !(participant %in% OMITTED)
  ) |>
  arrange(participant, block_number, trial_number)

# ── per-subject P(stay|win) and P(stay|loss) ──────────────────────────────────
df_scatter <- gb |>
  group_by(participant, understood_eq_felt, block_number) |>
  mutate(
    stay         = as.integer(choice_key == lag(choice_key)),
    reward_nback = lag(reward)
  ) |>
  ungroup() |>
  filter(!is.na(stay), !is.na(reward_nback)) |>
  group_by(participant, understood_eq_felt) |>
  summarise(
    p_win  = mean(stay[reward_nback == 1], na.rm = TRUE),
    p_loss = mean(stay[reward_nback == 0], na.rm = TRUE),
    .groups = "drop"
  ) |>
  filter(!is.na(p_win), !is.na(p_loss))

# ── fit pooled WSLS model for group β posterior ───────────────────────────────
df_pool <- gb |>
  group_by(participant, block_number) |>
  mutate(
    stay         = as.integer(choice_key == lag(choice_key)),
    reward_nback = lag(reward)
  ) |>
  ungroup() |>
  filter(!is.na(stay), !is.na(reward_nback))

fit_pool <- stan_glm(
  stay ~ reward_nback, data = df_pool, family = binomial(),
  prior_intercept = normal(0, 2), prior = normal(0, 2),
  chains = 4, iter = 2000, warmup = 1000, seed = 42, refresh = 0
)
beta_mu <- as.vector(as.matrix(fit_pool)[, "reward_nback"])
med      <- median(beta_mu)
pd       <- max(mean(beta_mu > 0), mean(beta_mu < 0)) * 100
ci90     <- quantile(beta_mu, c(0.05, 0.95))

# ── Panel 1: scatter ──────────────────────────────────────────────────────────
p_scatter <- ggplot(df_scatter, aes(x = p_loss, y = p_win)) +
  geom_abline(slope = 1, intercept = 0, colour = GREY40, linetype = "dashed", linewidth = 0.9, alpha = 0.6) +
  geom_point(aes(colour = understood_eq_felt), size = 2.5, alpha = 0.85) +
  scale_colour_manual(
    values = c("TRUE" = OI_BLUE, "FALSE" = OI_ORANGE),
    labels = c("TRUE" = "understood = felt  (n=22)", "FALSE" = "understood != felt  (n=13)"),
    name   = NULL
  ) +
  scale_x_continuous(limits = c(0, 1)) +
  scale_y_continuous(limits = c(0, 1)) +
  coord_fixed() +
  labs(x = "P(stay | loss)", y = "P(stay | win)") +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid      = element_blank(),
    axis.line.x     = element_line(colour = GREY30),
    axis.line.y     = element_line(colour = GREY30),
    axis.title      = element_text(size = 16),
    axis.text       = element_text(size = 8),
    legend.text     = element_text(size = 10),
    legend.position = "bottom",
    plot.background = element_rect(fill = "white", colour = NA)
  )

# ── Panel 2: β_μ posterior ───────────────────────────────────────────────────
ann_label <- sprintf("median = %.2f\npd = %.1f%%", med, pd)
df_draws  <- data.frame(x = beta_mu)

p_post <- ggplot(df_draws, aes(x = x)) +
  stat_density(aes(y = after_stat(density / max(density))), geom = "area",
               fill = GREY80, colour = NA, bw = "SJ") +
  geom_vline(xintercept = 0,   colour = GREY40, linetype = "dashed", linewidth = 0.9) +
  geom_vline(xintercept = med, colour = GREY65, linetype = "dashed", linewidth = 0.4) +
  annotate("segment", x = ci90[1], xend = ci90[2], y = -0.08, yend = -0.08,
           colour = GREY30, linewidth = 0.9) +
  annotate("point",   x = med, y = -0.08, colour = GREY30, size = 2) +
  annotate("text", x = med, y = 1.22,
           label = ann_label,
           hjust = 0.5, vjust = 1, size = 2.5, colour = "#555555") +
  labs(x = expression(beta[mu] ~ "(reward effect on log-odds of staying)"),
       title = "WSLS reward effect") +
  coord_cartesian(ylim = c(-0.23, 1.5), clip = "off") +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid    = element_blank(),
    axis.title.y  = element_blank(),
    axis.text.y   = element_blank(),
    axis.ticks.y  = element_blank(),
    axis.line.x   = element_line(colour = GREY30),
    axis.title.x  = element_text(size = 16),
    axis.text.x   = element_text(size = 8),
    plot.title    = element_text(size = 16, hjust = 0.5),
    plot.background = element_rect(fill = "white", colour = NA)
  )

# ── combine and save ──────────────────────────────────────────────────────────
fig <- p_scatter | p_post
ggsave(OUT_PNG, fig, width = 10, height = 4.5, dpi = 150, bg = "white")
cat(sprintf("Saved → %s\n", OUT_PNG))
