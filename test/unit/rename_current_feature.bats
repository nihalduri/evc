#!/usr/bin/env bats

setup() {
  load "../test_helper/evc_test_helper"
  install_evc_for_test
  REPO="${BATS_TEST_TMPDIR}/repo"
  make_local_repo "${REPO}"
}

@test "rename-current-feature renames the current feature branch" {
  evc_in "${REPO}" new-feature feat-old
  run evc_in "${REPO}" rename-current-feature feat-new
  assert_success
  assert_equal "$(git -C "${REPO}" branch --show-current)" "feat-new"
  run git -C "${REPO}" show-ref --verify --quiet refs/heads/feat-old
  assert_failure
}

@test "rename-current-feature refuses main" {
  run evc_in "${REPO}" rename-current-feature something
  assert_failure
  assert_output --partial "feature branch"
}
