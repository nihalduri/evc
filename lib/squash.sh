#!/usr/bin/env bash
# Squash unpushed commits.

set -euo pipefail

# shellcheck source=remote.sh
source "$(dirname "${BASH_SOURCE[0]}")/remote.sh"

# Soft-reset unpushed commits onto BASE and recommit with MESSAGE.
# BASE should be the remote tip already published (or main for a first push).
squash_unpushed_since() {
  local base=$1
  local message=$2
  local count
  git -C "${EVC_WORK_DIR}" rev-parse --verify "${base}" >/dev/null 2>&1 \
    || die_oops

  count=$(git -C "${EVC_WORK_DIR}" rev-list --count "${base}..HEAD")
  if [[ "${count}" -eq 0 ]]; then
    die "Nothing to push."
  fi
  if [[ "${count}" -eq 1 ]]; then
    # Single unpushed commit: just set the push message (still not on remote).
    run_git commit --amend -m "${message}" || die_oops
    return 0
  fi
  run_git reset --soft "${base}" || die_oops
  run_git commit -m "${message}" || die_oops
}

# Prefer origin/<branch> when it exists; otherwise origin/<main> or <main>.
squash_base_for_push() {
  local branch=$1
  local main
  main=$(evc_main_branch)
  if origin_has_branch "${branch}"; then
    echo "origin/${branch}"
  elif git -C "${EVC_WORK_DIR}" show-ref --verify --quiet "refs/remotes/origin/${main}"; then
    echo "origin/${main}"
  else
    echo "${main}"
  fi
}
