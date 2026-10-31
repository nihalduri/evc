#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/snapshot.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/snapshot.sh"

cmd_switch_feature() {
  require_args "Usage: evc switch-feature <NAME>" "$@"
  local name=$1
  require_git_repo

  local main current
  main=$(evc_main_branch)
  current=$(current_branch)
  # Dirty work on main is an accident when leaving main for a feature.
  if [[ "${name}" != "${main}" && "${current}" == "${main}" ]] && has_uncommitted_work; then
    die "Your work is on ${main}, not a feature -- this may have been an accident. Run new-feature to save it in a feature branch, then run switch again."
  fi
  if [[ "${name}" == "${main}" && "${current}" == "${main}" ]]; then
    info "Switched to feature '${name}'."
    return
  fi

  maybe_preserve_work

  if ! branch_exists "${name}"; then
    if ask_yn "Unrecognized feature name '${name}', do you want to create it then switch? Type 'Y' or 'N'."; then
      run_git checkout "${main}" || die_oops
      run_git checkout -b "${name}" || die "Failed to create feature '${name}'."
    else
      die "Unrecognized feature name '${name}'."
    fi
  else
    run_git checkout "${name}" || die "Failed to switch to feature '${name}'."
  fi

  restore_stashed_work_as_snapshot
  info "Switched to feature '${name}'."
}
