#!/usr/bin/env bats

setup() {
  load "../test_helper/evc_test_helper"
  install_evc_for_test
  REPO="${BATS_TEST_TMPDIR}/folder"
  mkdir -p "${REPO}"
}

@test "turn-into-git-repo initializes main and commits existing files" {
  echo "hello" >"${REPO}/notes.txt"
  mkdir -p "${REPO}/sub"
  echo "nested" >"${REPO}/sub/file.txt"

  run evc_in "${REPO}" turn-into-git-repo
  assert_success
  assert_equal "$(git -C "${REPO}" branch --show-current)" "main"
  run git -C "${REPO}" log -1 --pretty=%s
  assert_output "Initial commit"
  assert_file_exist "${REPO}/notes.txt"
  # Files are tracked in the initial commit. .evc/ is not included.
  run git_ls_tree_outside_evc "${REPO}"
  assert_output --partial "notes.txt"
  assert_output --partial "sub/file.txt"
  refute_output --partial ".evc/"
  # Working tree clean aside from anything under .evc/.
  run git_status_outside_evc "${REPO}"
  assert_output ""
}

@test "turn-into-git-repo fails if already a git repo" {
  run evc_in "${REPO}" turn-into-git-repo
  assert_success
  run evc_in "${REPO}" turn-into-git-repo
  assert_failure
  assert_output --partial "Already a Git repository"
}
