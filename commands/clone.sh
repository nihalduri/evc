#!/usr/bin/env bash
# evc clone <URL> — clone into a new folder named for the repository.

set -euo pipefail

# shellcheck source=../lib/git_run.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/git_run.sh"

cmd_clone() {
  require_args "Usage: evc clone <URL>" "$@"
  local url=$1

  run_git clone "${url}" || die_oops
  info "Clone complete."
}
