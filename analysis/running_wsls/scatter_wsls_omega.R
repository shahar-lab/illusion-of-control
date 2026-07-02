library(ggplot2)

plot_df <- data.frame(
  pid = c(
    "60e46e6f6bc0c2cdf5d077ce","60e6b55696dade249aa3249b","60e9f29fe1f58945339696d0",
    "6661b6019ab530fb44632cc2","66912a96b8dba143ceba8276","66ab330c867b56b7333c7f26",
    "66ab9137e5573312997df691","678cc86b7a22ead21c11ea4d","67acd3c9faab3a14dfe87135",
    "67f6a640d2046b13fcf33328","697ccad66fdf3bbcccb90fe4","69ef99a65d19811a9ddad38b",
    "69fdce52c07d954848678eaf"
  ),
  x = c(
     0.3333, 0.2500,  0.2831,  0.1932,  0.6283, -0.0895,
     0.6560, -0.0431,  0.0000, -0.0634, -0.0908,  0.1667, -0.1629
  ),
  y = c(
     0.07703,  0.04707, -0.04684, -0.00195, -0.00862, -0.00709,
    -0.00651, -0.01084,  0.01351,  0.00561, -0.01960,  0.01074,  0.00545
  )
)

# safety check
plot_df <- plot_df[complete.cases(plot_df$x, plot_df$y), ]
stopifnot(nrow(plot_df) == 13, length(plot_df$x) == length(plot_df$y))

pearson_r <- cor(plot_df$x, plot_df$y, method = "pearson")
cat(sprintf("Pearson r = %.3f  (n = %d)\n", pearson_r, nrow(plot_df)))

# independent axis limits — expand y generously for readability
x_lim <- range(plot_df$x) + c(-0.05, 0.05)
y_abs <- max(abs(range(plot_df$y))) * 1.6   # symmetric, well-padded
y_lim <- c(-y_abs, y_abs)
x_breaks <- seq(x_lim[1], x_lim[2], length.out = 4)
y_breaks <- seq(y_lim[1], y_lim[2], length.out = 4)

p <- ggplot(plot_df, aes(x = x, y = y)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey70") +
  geom_smooth(method = "lm", se = FALSE, colour = "#D55E00", linewidth = 0.9) +
  geom_point(colour = "#0072B2", alpha = 0.85, size = 3) +
  annotate(
    "text",
    x = Inf, y = Inf,
    label = sprintf("[Pearson r = %.2f]", pearson_r),
    hjust = 1.05, vjust = 1.4,
    size = 3.5, colour = "grey30"
  ) +
  scale_x_continuous(breaks = round(x_breaks, 2)) +
  scale_y_continuous(breaks = round(y_breaks, 3)) +
  coord_cartesian(xlim = x_lim, ylim = y_lim, clip = "off") +
  theme_minimal(base_size = 13) +
  theme(panel.grid.minor = element_blank()) +
  labs(
    x = "Median WSLS  [P(stay|win) − P(stay|loss)]",
    y = "Mean Ω  (trials 31–150)"
  )

ggsave("analysis/running_wsls/scatter_wsls_omega.png",
       plot = p, width = 5, height = 5, dpi = 180)
cat("Saved → analysis/running_wsls/scatter_wsls_omega.png\n")
