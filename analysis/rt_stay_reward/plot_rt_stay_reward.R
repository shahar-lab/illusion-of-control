rm(list = ls())

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(ggplot2)
library(patchwork)
library(rstanarm)
library(posterior)

DATA_DIR <- "../../data/ioc-task/pilot20"
FIGURES  <- "figures"
dir.create(FIGURES, showWarnings = FALSE)

INCLUDED_IDS <- c(
  "6980990e5c9007100eb282b6", "69808775dc84b90f4adafb2f", "61563a4b0def9000ccc976ec",
  "60f19a691466276fe085b461", "69dac2125e535db5a698ea18", "6980792fded33a62e27ce7cc",
  "6981150699107501d80e74b6", "667bd577710d52a05ac09036", "6981e6c2e26c88d954f297eb",
  "69d555ce85e30d6215e559d9", "69829236d776a93cf3afa632", "69d5525ec7afcfce08d8608b",
  "6980d9a70a7862a47c69046d", "6984a9246122d3bd4ca0833e", "69728435c9476fe76dd2ab2f",
  "69e913482ae5864d44e6387c", "697a645e36e6f14eea2b396b", "698341d57fe7b870bddf91b8",
  "697caeea2ec1c2604535f8aa", "62ebe597372fdef388b734b3"
)

cat("=== RT Stay-Reward Bayesian Hierarchical Analysis ===\n")

#### LOAD DATA ####
all_files <- list.files(DATA_DIR, full.names = TRUE)
df_list   <- list()

for (f in all_files) {
  pid <- str_extract(f, "[a-f0-9]{24}")
  if (is.na(pid) || !(pid %in% INCLUDED_IDS)) next
  df_list[[pid]] <- read_csv(f, show_col_types = FALSE) |> mutate(participant = pid)
}

df <- bind_rows(df_list)
cat("Loaded", length(df_list), "participants\n")

#### FILTER AND PREPARE ####
df <- df |>
  filter(task == "gambling_choice") |>
  mutate(
    rt              = suppressWarnings(as.numeric(rt)),
    reward          = as.integer(reward),
    is_choice_valid = as.logical(is_choice_valid),
    block_number    = as.character(block_number),
    trial_number    = as.integer(trial_number)
  ) |>
  filter(block_number != "training", is_choice_valid == TRUE, !is.na(rt)) |>
  group_by(participant, block_number) |>
  arrange(trial_number, .by_group = TRUE) |>
  mutate(
    choice_key_nback = lag(choice_key, n = 1),
    reward_nback     = lag(reward, n = 1),
    valid_nback      = lag(is_choice_valid, n = 1)
  ) |>
  ungroup() |>
  filter(
    !is.na(choice_key_nback),
    !is.na(reward_nback),
    valid_nback == TRUE,
    choice_key_nback != unavailable_key,
    rt > 100, rt < 5000
  ) |>
  mutate(
    stay         = as.integer(choice_key == choice_key_nback),
    reward_nback = as.integer(reward_nback),
    reward_label = factor(reward_nback, levels = c(0, 1),
                          labels = c("Unrewarded", "Rewarded"))
  )

# Stay trials only (same machine chosen as in previous trial)
stay_df <- df |> filter(stay == 1)

cat("Stay trials:", nrow(stay_df), "\n")
cat("N subjects:", n_distinct(stay_df$participant), "\n")
cat("Trials per condition:\n")
stay_df |> count(reward_label) |> print()
cat("RT range:", range(stay_df$rt), "\n")

#### FIT BAYESIAN HIERARCHICAL MODEL ####
# Model: log(RT) ~ reward_label + trial_number_c + (1 | participant)
# Log-transform RT for normality; back-transform predictions to ms for plotting.
# reward_label captures mean RT difference between conditions.
# trial_number_c (centered) captures within-block practice effect.
cat("\nFitting Bayesian hierarchical model...\n")

stay_df <- stay_df |>
  mutate(
    log_rt         = log(rt),
    trial_number_c = trial_number - mean(trial_number)
  )

fit <- stan_lmer(
  formula = log_rt ~ reward_label + trial_number_c + (1 | participant),
  data    = stay_df,
  prior   = normal(0, 0.5),
  prior_intercept = normal(7, 1),  # log(~1000 ms)
  prior_covariance = decov(regularization = 2),
  chains          = 4,
  cores           = 4,
  iter            = 2000,
  warmup          = 1000,
  refresh         = 200,
  seed            = 42
)

cat("\nModel summary:\n")
print(summary(fit))

#### EXTRACT POSTERIORS FOR CONDITION MEANS ####
# Evaluate at mean trial_number (i.e., trial_number_c = 0)
newdata_cond <- data.frame(
  reward_label   = factor(c("Unrewarded", "Rewarded"), levels = c("Unrewarded", "Rewarded")),
  trial_number_c = 0
)

# posterior_linpred gives draws on the log scale (population level, no subject RE)
post_log <- posterior_linpred(fit, newdata = newdata_cond, re.form = NA)
# post_log: [draws x 2], columns = [Unrewarded, Rewarded]
# Exponentiate to get predicted median RT in ms
post_cond_df <- data.frame(
  Unrewarded = exp(post_log[, 1]),
  Rewarded   = exp(post_log[, 2])
) |>
  mutate(diff = Rewarded - Unrewarded)

cat("\nPosterior means (ms):\n")
cat(sprintf("  Unrewarded: %.1f ms [90%% CI: %.1f, %.1f]\n",
    median(post_cond_df$Unrewarded),
    quantile(post_cond_df$Unrewarded, 0.05),
    quantile(post_cond_df$Unrewarded, 0.95)))
cat(sprintf("  Rewarded:   %.1f ms [90%% CI: %.1f, %.1f]\n",
    median(post_cond_df$Rewarded),
    quantile(post_cond_df$Rewarded, 0.05),
    quantile(post_cond_df$Rewarded, 0.95)))
cat(sprintf("  Difference (Rewarded - Unrewarded): %.1f ms [90%% CI: %.1f, %.1f]\n",
    median(post_cond_df$diff),
    quantile(post_cond_df$diff, 0.05),
    quantile(post_cond_df$diff, 0.95)))
cat(sprintf("  P(Rewarded < Unrewarded): %.3f\n", mean(post_cond_df$diff < 0)))

#### EXTRACT POSTERIORS ACROSS TRIAL NUMBERS ####
mean_tn   <- mean(stay_df$trial_number)
trial_seq <- 1:25

newdata_time <- expand.grid(
  trial_number   = trial_seq,
  reward_label   = factor(c("Unrewarded", "Rewarded"), levels = c("Unrewarded", "Rewarded"))
) |>
  mutate(trial_number_c = trial_number - mean_tn)

post_time_log <- posterior_linpred(fit, newdata = newdata_time, re.form = NA)
# Exponentiate to get predicted RT in ms
post_time <- exp(post_time_log)
# post_time: [draws x (25*2)]

time_summary <- newdata_time |>
  mutate(
    med  = apply(post_time, 2, median),
    lo90 = apply(post_time, 2, quantile, 0.05),
    hi90 = apply(post_time, 2, quantile, 0.95)
  )

#### PLOTTING ####
pal <- c("Unrewarded" = "#E69F00", "Rewarded" = "#56B4E9")

# ---- Panel A: Posterior distributions of condition means ----
post_long <- post_cond_df |>
  select(Unrewarded, Rewarded) |>
  pivot_longer(everything(), names_to = "condition", values_to = "rt_est") |>
  mutate(condition = factor(condition, levels = c("Unrewarded", "Rewarded")))

dens_list <- lapply(levels(post_long$condition), function(cond) {
  vals <- post_long$rt_est[post_long$condition == cond]
  d    <- density(vals, n = 512)
  data.frame(x = d$x, y = d$y / max(d$y), condition = cond, stringsAsFactors = FALSE)
})
dens_df <- bind_rows(dens_list) |>
  mutate(condition = factor(condition, levels = c("Unrewarded", "Rewarded")))

ci_df <- post_long |>
  group_by(condition) |>
  summarise(
    med  = median(rt_est),
    lo90 = quantile(rt_est, 0.05),
    hi90 = quantile(rt_est, 0.95),
    .groups = "drop"
  )

all_rt <- post_long$rt_est
r      <- range(all_rt)
span   <- diff(r)
xlims  <- c(r[1] - 0.20 * span, r[2] + 0.20 * span)

p_post <- ggplot(dens_df, aes(x = x, y = y, fill = condition, colour = condition)) +
  geom_area(alpha = 0.50, position = "identity") +
  geom_segment(
    data = ci_df,
    aes(x = lo90, xend = hi90, y = -0.04, yend = -0.04, colour = condition),
    linewidth = 1.5, inherit.aes = FALSE
  ) +
  geom_point(
    data = ci_df,
    aes(x = med, y = -0.04, colour = condition),
    size = 3, inherit.aes = FALSE
  ) +
  scale_fill_manual(values = pal) +
  scale_colour_manual(values = pal) +
  scale_x_continuous(labels = function(x) paste0(round(x), " ms")) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid           = element_blank(),
    axis.title.y         = element_blank(),
    axis.text.y          = element_blank(),
    axis.ticks.y         = element_blank(),
    axis.line.y          = element_blank(),
    axis.line.x          = element_line(colour = "grey30"),
    legend.position      = c(1, 0.95),
    legend.justification = c("right", "top"),
    legend.background    = element_blank(),
    legend.key           = element_blank()
  ) +
  labs(x = "Mean RT — stay trials (ms)", fill = NULL, colour = NULL) +
  coord_cartesian(xlim = xlims, ylim = c(-0.15, 1.15), clip = "off")

# ---- Panel B: RT across trial numbers ----
p_time <- ggplot(time_summary,
                 aes(x = trial_number, fill = reward_label, colour = reward_label)) +
  geom_ribbon(aes(ymin = lo90, ymax = hi90), alpha = 0.20, colour = NA) +
  geom_line(aes(y = med), linewidth = 1) +
  scale_fill_manual(values = pal) +
  scale_colour_manual(values = pal) +
  scale_x_continuous(breaks = seq(1, 25, by = 4)) +
  scale_y_continuous(labels = function(x) paste0(round(x), " ms")) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid           = element_blank(),
    axis.line.x          = element_line(colour = "grey30"),
    axis.line.y          = element_line(colour = "grey30"),
    legend.position      = c(1, 0.95),
    legend.justification = c("right", "top"),
    legend.background    = element_blank(),
    legend.key           = element_blank()
  ) +
  labs(
    x      = "Trial number (within block)",
    y      = "Expected RT (ms)",
    fill   = NULL,
    colour = NULL
  )

#### COMBINE AND SAVE ####
combined <- p_post / p_time +
  plot_layout(heights = c(1, 1.8)) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold"))

ggsave(
  file.path(FIGURES, "rt_stay_reward_bayesian.png"),
  combined,
  width  = 8,
  height = 8,
  dpi    = 150,
  bg     = "white"
)
cat("\nSaved:", file.path(FIGURES, "rt_stay_reward_bayesian.png"), "\n")
