rm(list = ls())

library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(patchwork)

DATA_FILE <- "../../data/ioc-task/all-10/ioc-all_69947fa1a4c3da138296e3c4_SESSION_2026-06-02_13h40.25.893.csv"
FIGURES   <- "figures"
dir.create(FIGURES, showWarnings = FALSE)

#### LOAD & PREP ####
df <- read_csv(DATA_FILE, show_col_types = FALSE)

gdf <- df |>
  filter(task == "gambling_choice") |>
  mutate(
    rt            = suppressWarnings(as.numeric(rt)),
    reward        = as.integer(reward),
    is_choice_valid = as.logical(is_choice_valid),
    block_number  = as.character(block_number),
    trial_number  = as.integer(trial_number)
  )

# All machines always available in this pilot (unavailable_keys == "[]")
cat("=== Pilot Data Overview ===\n")
cat("Participant:", unique(df$subject_id), "\n")
cat("Total gambling trials:", nrow(gdf), "\n")
cat("Training trials:      ", sum(gdf$block_number == "training"), "\n")
cat("Task blocks:          ", length(unique(gdf$block_number[gdf$block_number != "training"])), "\n")
cat("Valid choices:        ", sum(gdf$is_choice_valid, na.rm = TRUE), "/", nrow(gdf), "\n")
cat("RT range (ms):        ", range(gdf$rt, na.rm = TRUE), "\n")
cat("RT median (ms):       ", median(gdf$rt, na.rm = TRUE), "\n")
cat("Reward rate:          ", round(mean(gdf$reward, na.rm = TRUE), 3), "\n\n")

#### FILTER VALID TASK TRIALS ####
task_df <- gdf |>
  filter(block_number != "training", is_choice_valid == TRUE)

cat("Valid task trials:", nrow(task_df), "\n\n")

#### PLOT 1: RT DISTRIBUTION ####
p_rt_hist <- ggplot(task_df, aes(x = rt)) +
  geom_histogram(binwidth = 150, fill = "#56B4E9", color = "white", linewidth = 0.3) +
  geom_vline(xintercept = median(task_df$rt, na.rm = TRUE),
             linetype = "dashed", color = "gray30", linewidth = 0.8) +
  annotate("text",
           x = median(task_df$rt, na.rm = TRUE) + 80,
           y = Inf, vjust = 1.5, hjust = 0, size = 3.5, color = "gray30",
           label = paste0("median = ", round(median(task_df$rt, na.rm = TRUE)), " ms")) +
  scale_x_continuous(breaks = seq(0, 6000, 500), labels = function(x) paste0(x/1000, "s")) +
  labs(x = "Response time", y = "Count",
       title = "RT distribution — luck game",
       subtitle = paste0("N = ", sum(!is.na(task_df$rt)), " valid trials")) +
  theme_classic(base_size = 12)

#### PLOT 2: RT OVER TRIALS (within block) ####
p_rt_trial <- ggplot(task_df, aes(x = trial_number, y = rt)) +
  geom_point(alpha = 0.4, size = 1.5, color = "#56B4E9") +
  geom_smooth(method = "loess", span = 0.6, color = "#0072B2", fill = "#56B4E9", alpha = 0.25, linewidth = 0.9) +
  scale_y_continuous(labels = function(x) paste0(x/1000, "s")) +
  labs(x = "Trial number within block", y = "Response time",
       title = "RT over trials") +
  theme_classic(base_size = 12)

#### PLOT 3: RT BY BLOCK ####
p_rt_block <- ggplot(task_df, aes(x = block_number, y = rt, group = block_number)) +
  geom_boxplot(fill = "#E69F00", color = "gray30", outlier.shape = 21,
               outlier.fill = "#E69F00", outlier.alpha = 0.6, width = 0.5) +
  scale_y_continuous(labels = function(x) paste0(x/1000, "s")) +
  labs(x = "Block", y = "Response time", title = "RT by block") +
  theme_classic(base_size = 12)

#### PLOT 4: RT AFTER WIN VS LOSS ####
p_rt_reward <- ggplot(task_df |> filter(!is.na(reward)),
                      aes(x = factor(reward, labels = c("Not rewarded", "Rewarded")), y = rt)) +
  geom_boxplot(aes(fill = factor(reward)),
               color = "gray30", outlier.shape = 21, outlier.alpha = 0.6, width = 0.4) +
  scale_fill_manual(values = c("0" = "#E69F00", "1" = "#56B4E9"), guide = "none") +
  scale_y_continuous(labels = function(x) paste0(x/1000, "s")) +
  labs(x = NULL, y = "Response time", title = "RT by reward outcome") +
  theme_classic(base_size = 12)

#### COMBINE RT PANEL ####
rt_panel <- (p_rt_hist | p_rt_trial) / (p_rt_block | p_rt_reward) +
  plot_annotation(
    title    = "Response Time — Luck Game Pilot Check",
    subtitle = paste0("Participant: ", unique(df$subject_id)),
    tag_levels = "A"
  ) &
  theme(plot.tag = element_text(face = "bold"))

ggsave(file.path(FIGURES, "rt_pilot_check.png"), rt_panel,
       width = 12, height = 9, dpi = 150, bg = "white")
cat("Saved: figures/rt_pilot_check.png\n\n")

#### WSLS EFFECT ####
# Lag within block to get n-back choice and reward
wsls_df <- task_df |>
  group_by(block_number) |>
  arrange(trial_number, .by_group = TRUE) |>
  mutate(
    choice_nback = lag(choice_key, n = 1),
    reward_nback = lag(reward,     n = 1)
  ) |>
  ungroup() |>
  filter(
    !is.na(choice_nback),
    !is.na(reward_nback)
  ) |>
  mutate(
    stay         = as.integer(choice_key == choice_nback),
    reward_nback = as.integer(reward_nback)
  )

cat("=== WSLS Effect (1-back) ===\n")
cat("Trials in WSLS analysis:", nrow(wsls_df), "\n\n")

# Raw proportions
p_stay_noreward <- mean(wsls_df$stay[wsls_df$reward_nback == 0], na.rm = TRUE)
p_stay_reward   <- mean(wsls_df$stay[wsls_df$reward_nback == 1], na.rm = TRUE)
wsls_raw        <- p_stay_reward - p_stay_noreward

cat(sprintf("P(stay | no reward): %.3f\n", p_stay_noreward))
cat(sprintf("P(stay | reward):    %.3f\n", p_stay_reward))
cat(sprintf("WSLS effect (raw delta): %.3f\n\n", wsls_raw))

# Logistic regression (base R) — equivalent to the Bayesian model in the full analysis
glm_fit <- glm(stay ~ reward_nback, data = wsls_df, family = binomial)
coefs   <- coef(glm_fit)
cat("Logistic regression:\n")
cat(sprintf("  alpha (intercept):  %.3f  [log-odds of staying after loss]\n", coefs["(Intercept)"]))
cat(sprintf("  beta (reward):      %.3f  [WSLS log-odds effect]\n", coefs["reward_nback"]))
cat(sprintf("  P(stay|no reward):  %.3f  [inv_logit(alpha)]\n", plogis(coefs["(Intercept)"])))
cat(sprintf("  P(stay|reward):     %.3f  [inv_logit(alpha+beta)]\n", plogis(coefs["(Intercept)"] + coefs["reward_nback"])))

#### PLOT 5: WSLS SUMMARY ####
wsls_summary <- wsls_df |>
  group_by(reward_nback) |>
  summarise(
    p_stay = mean(stay),
    n      = n(),
    se     = sqrt(p_stay * (1 - p_stay) / n),
    .groups = "drop"
  ) |>
  mutate(
    condition = factor(reward_nback, labels = c("Not rewarded", "Rewarded")),
    ci_lo = pmax(0, p_stay - 1.96 * se),
    ci_hi = pmin(1, p_stay + 1.96 * se)
  )

p_wsls <- ggplot(wsls_summary, aes(x = condition, y = p_stay, fill = condition)) +
  geom_col(width = 0.45, color = "gray30") +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.12, linewidth = 0.7) +
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "gray50") +
  scale_fill_manual(values = c("Not rewarded" = "#E69F00", "Rewarded" = "#56B4E9"),
                    guide = "none") +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.25),
                     labels = scales::percent_format(accuracy = 1)) +
  annotate("segment",
           x = 1, xend = 2,
           y = max(wsls_summary$ci_hi) + 0.05,
           yend = max(wsls_summary$ci_hi) + 0.05,
           color = "gray40") +
  annotate("text",
           x = 1.5, y = max(wsls_summary$ci_hi) + 0.08, hjust = 0.5,
           label = sprintf("Δ = %.3f", wsls_raw), size = 4, color = "gray30") +
  labs(
    x = "Previous trial outcome",
    y = "P(stay)",
    title = "WSLS Effect — Luck Game",
    subtitle = sprintf("beta = %.3f  (logistic regression)", coefs["reward_nback"])
  ) +
  theme_classic(base_size = 13)

ggsave(file.path(FIGURES, "wsls_pilot_check.png"), p_wsls,
       width = 5, height = 5, dpi = 150, bg = "white")
cat("\nSaved: figures/wsls_pilot_check.png\n")
