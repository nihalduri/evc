#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/snapshot.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/snapshot.sh"

cmd_new_feature() {
  require_args "Usage: evc new-feature <NAME>" "$@"
  local name=$1
  require_git_repo

  local main
  main=$(evc_main_branch)
  [[ "${name}" != "${main}" ]] || die "Feature name cannot be '${main}'."
  branch_exists "${name}" && die "Feature '${name}' already exists."

  local current had_main_changes=0
  current=$(current_branch)

  if [[ "${current}" != "${main}" && -n "${current}" ]]; then
    # Snapshot any uncommitted work onto the current feature, then branch off main.
    if has_uncommitted_work; then
      create_snapshot_commit
    fi
    run_git checkout "${main}" || die_oops
    run_git checkout -b "${name}" || die "Failed to create feature '${name}'."
  else
    # On main (or detached): never commit on main; move dirty work onto the new branch.
    if has_uncommitted_work; then
      had_main_changes=1
    fi
    run_git checkout -b "${name}" || die "Failed to create feature '${name}'."
    if [[ "${had_main_changes}" -eq 1 ]]; then
      create_snapshot_commit
      info "Next time, run \`new-feature\` first. All work has been moved to the new feature branch."
    fi
  fi
  info "Now on feature '${name}'."
}
