#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/git_run.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/git_run.sh"

cmd_list_current_feature() {
  require_git_repo
  local branch
  branch=$(current_branch)
  if [[ -z "${branch}" ]]; then
    die_oops
  fi
  echo "${branch}"
}
