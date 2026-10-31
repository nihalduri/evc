#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/git_run.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/git_run.sh"

cmd_list_all_features() {
  require_git_repo
  git -C "${EVC_WORK_DIR}" for-each-ref --format='%(refname:short)' refs/heads
}
