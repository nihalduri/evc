#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/git_run.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/git_run.sh"

cmd_delete_feature() {
  require_args "Usage: evc delete-feature <NAME>" "$@"
  local name=$1
  require_git_repo

  local main
  main=$(evc_main_branch)
  [[ "${name}" != "${main}" ]] || die "Cannot delete ${main}."
  branch_exists "${name}" || die "Feature '${name}' does not exist."

  local current
  current=$(current_branch)
  if [[ "${current}" == "${name}" ]]; then
    die "You're on that feature currently, switch to a different feature first if you want to delete it."
  fi

  run_git branch -D "${name}" || die "Failed to delete feature '${name}'."
  info "Deleted local feature '${name}'."
}
