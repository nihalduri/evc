#!/usr/bin/env bats

setup() {
  load "../test_helper/evc_test_helper"
  install_evc_for_test
  REPO="${BATS_TEST_TMPDIR}/repo"
  make_local_repo "${REPO}"
}

@test "new-feature from clean main creates branch off main" {
  run evc_in "${REPO}" new-feature feat-a
  assert_success
  assert_equal "$(git -C "${REPO}" branch --show-current)" "feat-a"
  assert_equal "$(git -C "${REPO}" merge-base main feat-a)" "$(git -C "${REPO}" rev-parse main)"
}

@test "new-feature from dirty main moves changes onto the new branch" {
  echo "work" >"${REPO}/file.txt"
  run evc_in "${REPO}" new-feature feat-keep
  assert_success
  assert_output --partial "Next time, run \`new-feature\` first"
  assert_equal "$(git -C "${REPO}" branch --show-current)" "feat-keep"
  assert_file_exist "${REPO}/file.txt"
  assert_equal "$(git -C "${REPO}" merge-base main feat-keep)" "$(git -C "${REPO}" rev-parse main)"
  run git -C "${REPO}" log -1 --pretty=%s
  assert_output --partial "Snapshot"
}

@test "new-feature from a dirty feature snapshots there then branches off main" {
  evc_in "${REPO}" new-feature feat-a
  echo "only-on-a" >"${REPO}/only-a.txt"
  run evc_in "${REPO}" new-feature feat-b
  assert_success
  assert_equal "$(git -C "${REPO}" branch --show-current)" "feat-b"
  assert_equal "$(git -C "${REPO}" rev-parse feat-b)" "$(git -C "${REPO}" rev-parse main)"
  run git -C "${REPO}" log feat-a -1 --pretty=%s
  assert_output --partial "Snapshot"
  assert_file_not_exist "${REPO}/only-a.txt"
  git -C "${REPO}" checkout feat-a
  assert_file_exist "${REPO}/only-a.txt"
}

@test "switch-feature from dirty main refuses and leaves the work" {
  evc_in "${REPO}" new-feature feat-a
  git -C "${REPO}" checkout main
  echo "accident" >"${REPO}/accident.txt"
  run evc_in "${REPO}" switch-feature feat-a
  assert_failure
  assert_output --partial "Your work is on main, not a feature -- this may have been an accident. Run new-feature to save it in a feature branch, then run switch again."
  assert_equal "$(git -C "${REPO}" branch --show-current)" "main"
  assert_file_exist "${REPO}/accident.txt"
  run git -C "${REPO}" status --porcelain
  assert_output --partial "accident.txt"
  run git -C "${REPO}" stash list
  assert_output ""
}

@test "switch-feature between existing features" {
  evc_in "${REPO}" new-feature feat-a
  evc_in "${REPO}" new-feature feat-b
  run evc_in "${REPO}" switch-feature feat-a
  assert_success
  assert_equal "$(git -C "${REPO}" branch --show-current)" "feat-a"
}

@test "switch-feature prompts to create missing feature" {
  run bash -c "printf 'Y\n' | (cd '${REPO}' && '${EVC_BIN}' switch-feature feat-new)"
  assert_success
  assert_equal "$(git -C "${REPO}" branch --show-current)" "feat-new"
}

@test "switch-feature errors when user declines creating missing feature" {
  run bash -c "printf 'N\n' | (cd '${REPO}' && '${EVC_BIN}' switch-feature missing)"
  assert_failure
  assert_output --partial "Unrecognized feature name"
}

@test "list-current-feature and list-all-features" {
  evc_in "${REPO}" new-feature feat-a
  evc_in "${REPO}" new-feature feat-b
  run evc_in "${REPO}" list-current-feature
  assert_success
  assert_output --partial "feat-b"
  run evc_in "${REPO}" list-all-features
  assert_success
  assert_output --partial "feat-a"
  assert_output --partial "feat-b"
  assert_output --partial "main"
}

@test "switch-feature can switch to main" {
  evc_in "${REPO}" new-feature feat-a
  echo "on-a" >"${REPO}/on-a.txt"
  run evc_in "${REPO}" switch-feature main
  assert_success
  assert_equal "$(git -C "${REPO}" branch --show-current)" "main"
  run git -C "${REPO}" log feat-a -1 --pretty=%s
  assert_output --partial "Snapshot"
  assert_file_not_exist "${REPO}/on-a.txt"

  echo "on-main" >"${REPO}/on-main.txt"
  run evc_in "${REPO}" switch-feature main
  assert_success
  assert_equal "$(git -C "${REPO}" branch --show-current)" "main"
  assert_file_exist "${REPO}/on-main.txt"
  run git -C "${REPO}" status --porcelain
  assert_output --partial "on-main.txt"
}

@test "delete-feature refuses when currently on that feature" {
  evc_in "${REPO}" new-feature feat-a
  run evc_in "${REPO}" delete-feature feat-a
  assert_failure
  assert_output --partial "You're on that feature currently"
}

@test "delete-feature removes a local feature when not currently on it" {
  evc_in "${REPO}" new-feature feat-a
  evc_in "${REPO}" new-feature feat-b
  run evc_in "${REPO}" delete-feature feat-a
  assert_success
  run git -C "${REPO}" show-ref --verify --quiet refs/heads/feat-a
  assert_failure
}

@test "switch-feature snapshots dirty work on a feature branch" {
  evc_in "${REPO}" new-feature feat-a
  evc_in "${REPO}" new-feature feat-b
  echo "more" >"${REPO}/more.txt"
  run evc_in "${REPO}" switch-feature feat-a
  assert_success
  assert_equal "$(git -C "${REPO}" branch --show-current)" "feat-a"
  run git -C "${REPO}" log feat-b -1 --pretty=%s
  assert_output --partial "Snapshot"
}
