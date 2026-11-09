#### WSLS DATA ####

wsls_data = function(df) {
  df |>
    arrange(trial) |>
    transmute(
      trial,
      stay     = as.numeric(ch_card == lag(ch_card)),
      rew_prev = lag(reward) - 0.5
    ) |>
    filter(!is.na(stay))
}

#### WSLS FIT ####

fit_wsls = function(df) {
  d   = wsls_data(df)
  lpm = lm(stay ~ rew_prev, data = d)
  lgt = suppressWarnings(glm(stay ~ rew_prev, family = binomial, data = d))

  rates = d |>
    group_by(rew_prev) |>
    summarise(n = n(), stay = mean(stay), .groups = "drop")

  coefs = bind_rows(
    tibble(model = "linear",   term = c("b0", "b1"), estimate = coef(lpm), se = sqrt(diag(vcov(lpm))),
           baseline = c(1 / 3, 0)),
    tibble(model = "logistic", term = c("b0", "b1"), estimate = coef(lgt), se = sqrt(diag(vcov(lgt))),
           baseline = c(qlogis(1 / 3), 0))
  ) |>
    mutate(vs_baseline = estimate - baseline)

  list(
    data       = d,
    rates      = rates,
    coefs      = coefs,
    lpm        = lpm,
    lgt        = lgt,
    separation = nrow(rates) < 2 || any(rates$stay %in% c(0, 1))
  )
}

#### WSLS PLOTS ####

plot_wsls = function(fit) {
  grid = tibble(rew_prev = seq(-0.5, 0.5, length.out = 101))
  fits = bind_rows(
    grid |> mutate(model = "linear",   stay = predict(fit$lpm, grid)),
    grid |> mutate(model = "logistic", stay = predict(fit$lgt, grid, type = "response"))
  )
  rates = fit$rates |>
    mutate(
      se = sqrt(stay * (1 - stay) / n),
      lo = pmax(stay - 1.96 * se, 0),
      hi = pmin(stay + 1.96 * se, 1)
    )
  b = fit$coefs |> filter(model == "linear")

  ggplot(fits, aes(rew_prev, stay)) +
    geom_hline(yintercept = 1 / 3, linetype = "dashed", colour = "grey55") +
    annotate("text", x = 0.5, y = 1 / 3, label = "no-perseveration baseline 1/3",
             hjust = 1, vjust = -0.5, size = 3.2, colour = "grey40") +
    geom_line(aes(colour = model, linetype = model), linewidth = 0.9) +
    geom_errorbar(data = rates, aes(ymin = lo, ymax = hi), width = 0.04, inherit.aes = TRUE) +
    geom_point(data = rates, size = 3) +
    geom_text(data = rates, aes(y = hi, label = paste0("n = ", n)), vjust = -0.8, size = 3.2) +
    annotate("point", x = 0, y = b$estimate[1], shape = 4, size = 3.5, stroke = 1.2) +
    scale_x_continuous(breaks = c(-0.5, 0, 0.5), labels = c("loss (-0.5)", "0", "win (+0.5)"),
                       expand = expansion(mult = 0.08)) +
    scale_y_continuous(limits = c(0, 1)) +
    scale_colour_manual(values = c(linear = "#2a6fb0", logistic = "#d0702c")) +
    labs(x = "Reward on previous trial", y = "P(stay)", colour = NULL, linetype = NULL,
         caption = "Points: observed stay rates (95% CI). X at 0: linear b0.") +
    theme_minimal(base_size = 13) +
    theme(legend.position = "top")
}

plot_choices = function(df, nshown) {
  ggplot(df, aes(trial, ch_card)) +
    annotate("rect", xmin = 0.5, xmax = nshown + 0.5, ymin = 0.5, ymax = max(df$ch_card, 3) + 0.5,
             fill = "grey90") +
    geom_point(aes(colour = factor(reward)), size = 1.8) +
    scale_colour_manual(values = c(`0` = "#c0392b", `1` = "#27ae60"), labels = c("loss", "win")) +
    scale_y_continuous(breaks = 1:3) +
    labs(x = "Trial (shaded = rows in table)", y = "Chosen arm", colour = NULL) +
    theme_minimal(base_size = 13) +
    theme(legend.position = "top", panel.grid.minor = element_blank())
}
