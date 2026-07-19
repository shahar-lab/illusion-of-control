# Environment Bootstrap (fallback path)

Most of the time, R + `cmdstanr` + CmdStan + tidyverse/`bayesplot`/`ggdist` are already
installed and this whole document is irrelevant — just run `main.R`. This is only for the
case where a fresh container/session has none of it installed, which happened at the
start of this lab's very first session in a from-scratch remote environment.

**Do not try to improvise an install path** (e.g. straight `install.packages()` or
downloading a prebuilt CmdStan release) without first checking whether the container's
network is restricted — the path below exists specifically because the direct routes
failed.

## 1. Install R and base packages via apt

```bash
apt-get install -y \
  r-base r-base-dev \
  r-cran-dplyr r-cran-tidyr r-cran-readr r-cran-stringr \
  r-cran-ggplot2 r-cran-patchwork r-cran-posterior r-cran-tibble r-cran-here \
  r-cran-bayesplot r-cran-checkmate r-cran-jsonlite r-cran-processx r-cran-r6 \
  r-cran-withr r-cran-rlang r-cran-fs
```

Apt in this kind of container usually reaches the base Ubuntu/Debian mirrors fine even
when other outbound hosts are blocked.

## 2. Check whether CRAN/r-universe are reachable

```bash
curl -sS -o /dev/null -w "%{http_code}\n" https://cloud.r-project.org/
```

If this returns anything other than a normal 200-series response (in one real session,
CRAN and `*.r-universe.dev` were both blocked by network policy while `github.com`'s
plain git protocol was not), you'll need the git-based path below for anything not
available via apt.

## 3. Build CmdStan from source via git clone (works even when GitHub's API/release
   endpoints are blocked)

Some sandboxed sessions block `api.github.com` and `codeload.github.com` (i.e. the
GitHub API and release-tarball downloads) but do **not** block plain `git clone` over
HTTPS, because git's smart-HTTP protocol isn't subject to the same scoping. If
`cmdstanr::install_cmdstan()` or a direct `curl` to a GitHub releases URL gets rejected
with something like `"GitHub access to this repository is not enabled for this
session"`, this is almost certainly what's happening — check with a plain clone first:

```bash
git clone --depth 1 https://github.com/stan-dev/cmdstan.git /tmp/test_clone
```

If that works, build CmdStan from source at a pinned release tag:

```bash
mkdir -p ~/.cmdstan
git clone --branch v2.39.0 --depth 1 --recurse-submodules --shallow-submodules \
  https://github.com/stan-dev/cmdstan.git ~/.cmdstan/cmdstan-2.39.0
cd ~/.cmdstan/cmdstan-2.39.0 && make build -j4
```

The `stan` and `math` submodules (cloned automatically via `--recurse-submodules`) vendor
TBB/Eigen/Boost/Sundials directly in `stan/lib/stan_math/lib/` — no further downloads are
needed to build. `~/.cmdstan/cmdstan-<version>` is `cmdstanr`'s default search path, so
once this finishes, `library(cmdstanr); cmdstan_path()` will find it with no extra
configuration. `make build` compiles TBB and the Stan core and can take 10-20+ minutes on
a few cores — expect this, it's a one-time cost per fresh container.

Install the `cmdstanr` R package the same way (it's not on CRAN, only GitHub, and not
available via apt either):

```bash
git clone --depth 1 https://github.com/stan-dev/cmdstanr.git /tmp/cmdstanr_src
R CMD INSTALL /tmp/cmdstanr_src
```

## 4. Any other GitHub-only R package (e.g. `ggdist`)

Same git-clone approach, but check out a release tag whose dependency requirements match
what's already installed — the default branch may require a newer `ggplot2` than what
apt provided:

```bash
git clone --depth 1 https://github.com/mjskay/ggdist.git /tmp/ggdist_src
cd /tmp/ggdist_src && git fetch --tags && git tag --sort=-v:refname | head
# pick the newest tag whose DESCRIPTION's ggplot2 (>= X.Y.Z) is satisfied by:
Rscript -e 'packageVersion("ggplot2")'
git checkout <chosen_tag>
R CMD INSTALL /tmp/ggdist_src
```

## 5. Verify

```r
library(cmdstanr)
cmdstan_version()   # should print the version you built
```

Clean up any scratch clones (`/tmp/test_clone`, `/tmp/cmdstanr_src`, etc.) once installed
— they're not needed after `R CMD INSTALL`/`make build` complete.
