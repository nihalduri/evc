#!/usr/bin/env bash
# Remote / tracking helpers.

set -euo pipefail

# shellcheck source=snapshot.sh
source "$(dirname "${BASH_SOURCE[0]}")/snapshot.sh"

origin_has_branch() {
  git -C "${EVC_WORK_DIR}" show-ref --verify --quiet "refs/remotes/origin/$1"
}

ensure_tracking_to_origin_branch() {
  local branch=$1
  origin_has_branch "${branch}" \
    || die "No remote feature named '${branch}'."
  run_git branch --set-upstream-to="origin/${branch}" "${branch}" \
    || die_oops
}
