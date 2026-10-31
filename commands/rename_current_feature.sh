#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/remote.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/remote.sh"

cmd_rename_current_feature() {
  require_args "Usage: evc rename-current-feature <NEW-NAME>" "$@"
  local new_name=$1
  require_git_repo

  local main current
  main=$(evc_main_branch)
  [[ "${new_name}" != "${main}" ]] || die "Feature name cannot be '${main}'."
  current=$(current_branch)
  [[ -n "${current}" && "${current}" != "${main}" ]] \
    || die "Rename from a feature branch (not ${main})."
  [[ "${current}" != "${new_name}" ]] || die "Already named '${new_name}'."
  branch_exists "${new_name}" && die "Feature '${new_name}' already exists."

  run_git branch -m "${new_name}" || die "Failed to rename to '${new_name}'."

  # Drop stale upstream pointing at the old remote name, if any.
  if [[ -n "$(upstream_ref)" ]]; then
    run_git branch --unset-upstream 2>/dev/null || true
  fi

  info "Renamed feature '${current}' to '${new_name}'."
}
