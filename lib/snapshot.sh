#!/usr/bin/env bash
# Snapshot uncommitted work without ever committing on the main branch.

set -euo pipefail

# shellcheck source=git_run.sh
source "$(dirname "${BASH_SOURCE[0]}")/git_run.sh"

has_uncommitted_work() {
  require_git_repo
  local dirty untracked
  # .evc/ is EVC bookkeeping, not the user's work.
  dirty=$(git -C "${EVC_WORK_DIR}" status --porcelain -- . ':(exclude).evc')
  [[ -n "${dirty}" ]]
}

# Stage and commit on the current (non-main) branch.
create_snapshot_commit() {
  local branch ts main
  branch=$(current_branch)
  main=$(evc_main_branch)
  [[ "${branch}" != "${main}" ]] || die "Internal error: cannot snapshot on ${main}."
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  stage_all_except_internal
  run_git commit -m "Snapshot ${ts}" || die_oops
}

# If dirty on a feature branch, snapshot. If dirty on main, stash for later restore.
# Sets EVC_RESTORED_STASH=1 when a stash was created.
maybe_preserve_work() {
  EVC_RESTORED_STASH=0
  has_uncommitted_work || return 0
  local branch main
  branch=$(current_branch)
  main=$(evc_main_branch)
  if [[ "${branch}" == "${main}" || -z "${branch}" ]]; then
    run_git stash push -u -m "EVC auto-stash $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      || die_oops
    EVC_RESTORED_STASH=1
  else
    create_snapshot_commit
  fi
}

# After moving off main onto a feature branch, pop stash and snapshot if needed.
restore_stashed_work_as_snapshot() {
  [[ "${EVC_RESTORED_STASH:-0}" == "1" ]] || return 0
  if run_git stash pop; then
    if has_uncommitted_work; then
      create_snapshot_commit
    fi
  else
    die_oops
  fi
  EVC_RESTORED_STASH=0
}
