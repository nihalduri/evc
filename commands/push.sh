#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/squash.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/squash.sh"

_push_usage() {
  die "Usage: evc push <BRANCH-NAME> <CHANGE-DESCRIPTION>"
}

_confirm_contribute_to_existing_remote() {
  local branch=$1
  if ask_yn "A feature with this name already exists on remote, do you want to contribute to it or create a new feature? To create new, you must rename. Type 'Y' to contribute, 'N' to exit and rename."; then
    ensure_tracking_to_origin_branch "${branch}"
  else
    die "Push cancelled. Rename your feature (evc rename-current-feature <NEW-NAME>) and push again."
  fi
}

# True if REF exists and has commits not contained in HEAD.
_remote_has_unincorporated_commits() {
  local ref=$1
  git -C "${EVC_WORK_DIR}" rev-parse --verify "${ref}" >/dev/null 2>&1 || return 1
  ! git -C "${EVC_WORK_DIR}" merge-base --is-ancestor "${ref}" HEAD
}

_confirm_move_main_work() {
  local name=$1 main
  main=$(evc_main_branch)
  if ask_yn "Your work is on ${main}, not a feature -- this may have been an accident. Move it to a new feature '${name}'? Type 'Y' to move it and continue, 'N' to exit."; then
    return 0
  fi
  die "Push cancelled. Create a new feature for your work, then push again."
}

# Stay on main without stashing uncommitted work; that work is the initial commit.
_ensure_on_main_for_initial_push() {
  local main current
  main=$(evc_main_branch)
  current=$(current_branch)
  if [[ "${current}" == "${main}" ]]; then
    return 0
  fi
  if branch_exists "${main}"; then
    maybe_preserve_work
    run_git checkout "${main}" || die_oops
    return 0
  fi
  if git -C "${EVC_WORK_DIR}" rev-parse --verify HEAD >/dev/null 2>&1; then
    run_git branch "${main}" HEAD || die_oops
    maybe_preserve_work
    run_git checkout "${main}" || die_oops
    return 0
  fi
  die "No local branch named '${main}'."
}

# Publish local main when the remote does not have it yet (empty clone).
# Squashes any existing unpublished history into one commit with MESSAGE.
_push_initial_main() {
  local message=$1 main
  main=$(evc_main_branch)
  stage_all_except_internal || die_oops

  if ! git -C "${EVC_WORK_DIR}" rev-parse --verify HEAD >/dev/null 2>&1; then
    if git -C "${EVC_WORK_DIR}" diff --cached --quiet; then
      die "Nothing to push."
    fi
    run_git commit -m "${message}" || die_oops
  else
    local count
    count=$(git -C "${EVC_WORK_DIR}" rev-list --count HEAD)
    if [[ "${count}" -eq 1 ]]; then
      run_git commit --amend -m "${message}" || die_oops
    else
      run_git checkout --orphan evc-push-root || die_oops
      stage_all_except_internal || die_oops
      run_git commit -m "${message}" || die_oops
      run_git branch -M "${main}" || die_oops
    fi
  fi

  run_git push -u origin "HEAD:${main}" || die_oops
}

# Move onto NAME, creating it from main when it does not exist yet.
_checkout_branch_for_push() {
  local name=$1
  local current main
  current=$(current_branch)
  main=$(evc_main_branch)

  if [[ "${current}" == "${main}" ]] && has_uncommitted_work; then
    _confirm_move_main_work "${name}"
  fi

  if [[ "${current}" == "${name}" ]]; then
    maybe_preserve_work
    return 0
  fi

  if [[ "${current}" == "${main}" || -z "${current}" ]] && ! branch_exists "${name}"; then
    run_git checkout -b "${name}" || die "Failed to create feature '${name}'."
    if has_uncommitted_work; then
      create_snapshot_commit
    fi
    return 0
  fi

  branch_exists "${name}" || die "Feature '${name}' does not exist."
  maybe_preserve_work
  run_git checkout "${name}" || die_oops
  restore_stashed_work_as_snapshot
}

cmd_push() {
  [[ $# -ge 2 && -n "${1:-}" && "$1" != -* && -n "${2:-}" ]] || _push_usage
  local branch=$1
  shift
  local message=$*
  require_git_repo

  local upstream base main
  main=$(evc_main_branch)

  has_origin || die "No remote configured."
  run_git fetch origin || die_oops

  if [[ "${branch}" == "${main}" ]]; then
    if origin_has_branch "${main}"; then
      die "Cannot push '${main}'."
    fi
    _ensure_on_main_for_initial_push
    _push_initial_main "${message}"
    info "Pushed '${main}'. After this, all work must be done in feature branches."
    return 0
  fi

  if ! origin_has_branch "${main}" && ! branch_exists "${main}"; then
    die "There is no '${main}' branch yet. Run: evc push ${main} <CHANGE-DESCRIPTION>"
  fi

  _checkout_branch_for_push "${branch}"

  if origin_has_branch "${branch}"; then
    upstream=$(upstream_ref)
    if [[ "${upstream}" != "origin/${branch}" ]]; then
      _confirm_contribute_to_existing_remote "${branch}"
    fi
  fi

  if _remote_has_unincorporated_commits "origin/${main}" \
    || (origin_has_branch "${branch}" && _remote_has_unincorporated_commits "origin/${branch}"); then
    die "There are unincorporated changes in remote. Run pull and then push again."
  fi

  base=$(squash_base_for_push "${branch}")
  squash_unpushed_since "${base}" "${message}"

  run_git push -u origin "HEAD:${branch}" || die_oops
  info "Pushed feature '${branch}'."
}
