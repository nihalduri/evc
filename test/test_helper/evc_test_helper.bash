#!/usr/bin/env bash
# Shared setup for EVC bats tests.

EVC_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

load "${TEST_ROOT}/test_helper/bats-support/load"
load "${TEST_ROOT}/test_helper/bats-assert/load"
load "${TEST_ROOT}/test_helper/bats-file/load"

# Use the repo bin/ directly (same layout users add to PATH).
install_evc_for_test() {
  export PATH="${EVC_PROJECT_ROOT}/bin:${PATH}"
  export EVC_BIN="${EVC_PROJECT_ROOT}/bin/evc"
  # Identity for commits created by EVC (e.g. turn-into-git-repo initial commit).
  export GIT_AUTHOR_NAME="EVC Test"
  export GIT_AUTHOR_EMAIL="evc-test@example.com"
  export GIT_COMMITTER_NAME="EVC Test"
  export GIT_COMMITTER_EMAIL="evc-test@example.com"
}

# Run evc in a given directory (EVC always uses cwd).
evc_in() {
  local dir=$1
  shift
  (cd "${dir}" && "${EVC_BIN}" "$@")
}

# Status and tree listings with .evc/ removed.
git_status_outside_evc() {
  local dir=$1
  git -C "${dir}" status --porcelain | grep -vE '(^| )\.evc(/|$)' || true
}

git_ls_tree_outside_evc() {
  local dir=$1
  git -C "${dir}" ls-tree -r --name-only HEAD | grep -v '^\.evc/' || true
}

# Create a folder with a starter file and turn it into a git repo (initial commit via EVC).
make_local_repo() {
  local dir=$1
  mkdir -p "${dir}"
  echo "base" >"${dir}/README.md"
  run evc_in "${dir}" turn-into-git-repo
  assert_success
}

# Local bare remote + clone for integration-style remote ops without the network.
make_remote_pair() {
  local bare=$1
  local work=$2
  mkdir -p "${bare}" "${work}"
  git init --bare -b main "${bare}"
  bare=$(cd "${bare}" && pwd)
  make_local_repo "${work}"
  git -C "${work}" remote add origin "${bare}"
  git -C "${work}" push -u origin main
  REMOTE_BARE_URL="${bare}"
}
