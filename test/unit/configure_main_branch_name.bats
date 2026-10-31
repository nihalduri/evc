#!/usr/bin/env bats

setup() {
  load "../test_helper/evc_test_helper"
  install_evc_for_test
  REPO="${BATS_TEST_TMPDIR}/repo"
  make_local_repo "${REPO}"
}

@test "configure-main-branch-name stores alternate name in .evc/main-branch-name" {
  git -C "${REPO}" branch -m main trunk
  run evc_in "${REPO}" configure-main-branch-name trunk
  assert_success
  assert_output --partial "Main branch name set to 'trunk'."
  run cat "${REPO}/.evc/main-branch-name"
  assert_success
  assert_output "trunk"
}

@test "configure-main-branch-name main clears the override" {
  git -C "${REPO}" branch -m main trunk
  evc_in "${REPO}" configure-main-branch-name trunk
  git -C "${REPO}" branch -m trunk main
  run evc_in "${REPO}" configure-main-branch-name main
  assert_success
  assert_file_not_exist "${REPO}/.evc/main-branch-name"
}

@test "configure-main-branch-name rejects missing local branch" {
  run evc_in "${REPO}" configure-main-branch-name trunk
  assert_failure
  assert_output --partial "No local branch named 'trunk'."
}

@test "new-feature and list-all-features respect configured main branch" {
  git -C "${REPO}" branch -m main trunk
  evc_in "${REPO}" configure-main-branch-name trunk

  run evc_in "${REPO}" new-feature feat-a
  assert_success
  assert_equal "$(git -C "${REPO}" branch --show-current)" "feat-a"
  assert_equal "$(git -C "${REPO}" merge-base trunk feat-a)" "$(git -C "${REPO}" rev-parse trunk)"

  run evc_in "${REPO}" list-all-features
  assert_success
  assert_output --partial "feat-a"
  assert_output --partial "trunk"

  run evc_in "${REPO}" switch-feature trunk
  assert_success
  assert_equal "$(git -C "${REPO}" branch --show-current)" "trunk"
}

@test "rename-current-feature refuses the configured main branch name" {
  git -C "${REPO}" branch -m main trunk
  evc_in "${REPO}" configure-main-branch-name trunk
  evc_in "${REPO}" new-feature feat-a
  run evc_in "${REPO}" rename-current-feature trunk
  assert_failure
  assert_output --partial "Feature name cannot be 'trunk'."
}
