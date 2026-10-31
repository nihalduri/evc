#!/usr/bin/env bash
# evc configure-main-branch-name ALTERNATE-NAME
# Stores a non-default default-branch name in .evc/main-branch-name
# (file absent => main).

set -euo pipefail

# shellcheck source=../lib/git_run.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/git_run.sh"

cmd_configure_main_branch_name() {
  require_args "Usage: evc configure-main-branch-name <ALTERNATE-NAME>" "$@"
  local name=$1
  require_git_repo

  [[ -n "${name}" ]] || die "Main branch name cannot be empty."
  branch_exists "${name}" || die "No local branch named '${name}'."

  # Only persist a non-main name; default "main" means clear the override.
  ensure_evc_project_dirs
  local f
  f=$(evc_main_branch_file)
  if [[ "${name}" == "main" ]]; then
    rm -f "${f}"
  else
    printf '%s\n' "${name}" >"${f}"
  fi
  info "Main branch name set to '${name}'."
}
