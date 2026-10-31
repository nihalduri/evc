#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/remote.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/remote.sh"

_pull_usage() {
  die "Usage: evc pull <REMOTE-BRANCH-NAME>"
}

# Label a direct merge of origin/<branch> as local vs remote.
_pretty_pull_conflict_markers() {
  local file tmp
  while IFS= read -r file; do
    [[ -n "${file}" ]] || continue
    tmp=$(mktemp)
    awk '
      {
        line = $0
        sub(/\r$/, "", line)
        if (line == "<<<<<<< HEAD") { print "<<<<<<< local"; next }
        if (line ~ /^>>>>>>> /) { print ">>>>>>> remote"; next }
        print
      }
    ' "${EVC_WORK_DIR}/${file}" >"${tmp}"
    mv "${tmp}" "${EVC_WORK_DIR}/${file}"
  done < <(git -C "${EVC_WORK_DIR}" diff --name-only --diff-filter=U)
}

# Commit conflict-marker contents as the merge resolution on the current branch.
_accept_merge_conflict_markers() {
  is_merge_in_progress || return 1
  _pretty_pull_conflict_markers
  stage_all_except_internal || die_oops
  run_git commit --no-edit || die_oops
  EVC_PULL_HAD_CONFLICTS=1
  return 0
}

# Create/checkout local REMOTE-BRANCH-NAME tracking origin/REMOTE-BRANCH-NAME.
_checkout_tracking_remote_branch() {
  local name=$1
  origin_has_branch "${name}" \
    || die "No remote branch named '${name}'."

  if branch_exists "${name}"; then
    run_git checkout "${name}" || die_oops
    ensure_tracking_to_origin_branch "${name}"
  else
    run_git checkout -b "${name}" --track "origin/${name}" || die_oops
  fi
}

# Merge origin/BRANCH into the current branch.
_merge_origin_into_current() {
  local branch=$1
  origin_has_branch "${branch}" \
    || die "No remote branch named '${branch}'."
  ensure_tracking_to_origin_branch "${branch}"
  if git -C "${EVC_WORK_DIR}" merge-base --is-ancestor "origin/${branch}" HEAD 2>/dev/null; then
    return 0
  fi
  if ! run_git merge -m "EVC pull: merge origin/${branch}" "origin/${branch}"; then
    _accept_merge_conflict_markers || die_oops
  fi
}

_report_pull_preservation() {
  local branch main
  branch=$(current_branch)
  main=$(evc_main_branch)
  if [[ "${branch}" != "${main}" && "${EVC_RESTORED_STASH:-0}" == "1" ]]; then
    restore_stashed_work_as_snapshot
  elif [[ "${branch}" == "${main}" && "${EVC_RESTORED_STASH:-0}" == "1" ]]; then
    info "Uncommitted work was set aside (EVC does not save work on ${main}). Run switch-feature or new-feature to restore it."
  fi
  if [[ "${EVC_PULL_HAD_CONFLICTS:-0}" == "1" ]]; then
    info "Merge conflicts were recorded on this branch. Conflict markers are in the files; edit them to the resolution you want."
  fi
}

cmd_pull() {
  [[ $# -eq 1 && -n "${1:-}" && "$1" != -* ]] || _pull_usage
  local remote_branch=$1

  EVC_PULL_HAD_CONFLICTS=0
  require_git_repo
  has_origin || die "No remote configured."

  maybe_preserve_work

  if is_merge_in_progress; then
    _accept_merge_conflict_markers || die_oops
  fi

  run_git fetch origin || die_oops
  _checkout_tracking_remote_branch "${remote_branch}"
  _merge_origin_into_current "${remote_branch}"
  _report_pull_preservation
  info "Pull complete."
}
