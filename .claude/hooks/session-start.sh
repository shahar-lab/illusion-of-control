#!/bin/bash
set -euo pipefail

# Only run in remote (web) sessions
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

echo '{"async": true, "asyncTimeout": 300000}'

# Install R and required packages via apt (no CRAN network needed)
apt-get install -y \
  r-base r-base-dev \
  r-cran-dplyr r-cran-tidyr r-cran-readr r-cran-stringr \
  r-cran-ggplot2 r-cran-patchwork r-cran-posterior \
  r-cran-cmdstanr 2>/dev/null || \
apt-get install -y \
  r-base r-base-dev \
  r-cran-dplyr r-cran-tidyr r-cran-readr r-cran-stringr \
  r-cran-ggplot2 r-cran-patchwork r-cran-posterior
