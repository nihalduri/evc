#!/usr/bin/env bash
# evc turn-into-git-repo — git init + main + initial commit of existing files.

set -euo pipefail

# shellcheck source=../lib/git_run.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/git_run.sh"

cmd_turn_into_git_repo() {
  if git -C "${EVC_WORK_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "Already a Git repository: ${EVC_WORK_DIR}"
  fi
  run_git init -b main || die_oops
  ensure_evc_project_dirs
  stage_all_except_internal || die_oops
  # Include any pre-existing files; allow-empty so a brand-new empty folder still gets main.
  run_git commit --allow-empty -m "Initial commit" || die_oops
  info "Initialized Git repository on main in ${EVC_WORK_DIR}"
}
