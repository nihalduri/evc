#!/usr/bin/env bats

setup() {
  load "../test_helper/evc_test_helper"
  install_evc_for_test
  REPO="${BATS_TEST_TMPDIR}/repo"
  make_local_repo "${REPO}"
}

@test "merge-into merges named branches and later picks up only new commits" {
  evc_in "${REPO}" new-feature feat
  echo "from-feat" >"${REPO}/feat.txt"
  git -C "${REPO}" add feat.txt
  git -C "${REPO}" commit -m "Snapshot feat"

  git -C "${REPO}" checkout main
  evc_in "${REPO}" new-feature feat-a
  echo "a" >"${REPO}/a.txt"
  git -C "${REPO}" add a.txt
  git -C "${REPO}" commit -m "Snapshot a"
  local feat_a_tip
  feat_a_tip=$(git -C "${REPO}" rev-parse feat-a)

  run evc_in "${REPO}" merge-into feat --order main
  assert_success
  assert_output --partial "Skipping 'main'"
  assert_file_not_exist "${REPO}/a.txt"

  git -C "${REPO}" checkout main
  echo "from-main" >"${REPO}/main.txt"
  git -C "${REPO}" add main.txt
  git -C "${REPO}" commit -m "on main"

  run evc_in "${REPO}" merge-into feat --order main
  assert_success
  assert_output --partial "Merged 'main'."
  assert_equal "$(git -C "${REPO}" branch --show-current)" "feat"
  assert_file_exist "${REPO}/feat.txt"
  assert_file_exist "${REPO}/main.txt"
  assert_file_not_exist "${REPO}/a.txt"

  run evc_in "${REPO}" merge-into feat --order feat-a
  assert_success
  assert_output --partial "Merged 'feat-a'."
  assert_file_exist "${REPO}/a.txt"
  assert_file_exist "${REPO}/main.txt"
  assert_equal "$(git -C "${REPO}" rev-parse feat-a)" "${feat_a_tip}"

  git -C "${REPO}" checkout feat-a
  echo "a2" >"${REPO}/a2.txt"
  git -C "${REPO}" add a2.txt
  git -C "${REPO}" commit -m "more a"

  run evc_in "${REPO}" merge-into feat --order main
  assert_success
  assert_output --partial "Skipping 'main'"
  assert_file_not_exist "${REPO}/a2.txt"

  run evc_in "${REPO}" merge-into feat --order main,feat-a
  assert_success
  assert_output --partial "Skipping 'main'"
  assert_output --partial "Merged 'feat-a'."
  assert_file_exist "${REPO}/a2.txt"
  assert_file_exist "${REPO}/feat.txt"
}

@test "merge-into refuses main, a missing feature, and a missing branch" {
  run evc_in "${REPO}" merge-into
  assert_failure
  assert_output --partial "Usage: evc merge-into <NAME> --order <BRANCH1>,<BRANCH2>,..."

  run evc_in "${REPO}" merge-into main --order feat
  assert_failure
  assert_output --partial "Cannot merge into 'main'."

  run evc_in "${REPO}" merge-into missing --order main
  assert_failure
  assert_output --partial "Feature 'missing' does not exist."

  evc_in "${REPO}" new-feature feat
  run evc_in "${REPO}" merge-into feat --order missing
  assert_failure
  assert_output --partial "Branch 'missing' does not exist."
}

_commit_on_feature() {
  local repo=$1 feature=$2 file=$3 content=$4
  git -C "${repo}" checkout main
  evc_in "${repo}" new-feature "${feature}"
  echo "${content}" >"${repo}/${file}"
  git -C "${repo}" add "${file}"
  git -C "${repo}" commit -m "Snapshot ${feature}"
}

@test "merge-into records a conflict and continues when the same order is run again" {
  _commit_on_feature "${REPO}" feat-a a.txt a
  _commit_on_feature "${REPO}" feat-b README.md from-b
  _commit_on_feature "${REPO}" feat-c README.md from-c
  _commit_on_feature "${REPO}" feat-d d.txt d
  _commit_on_feature "${REPO}" feat-e e.txt e
  git -C "${REPO}" checkout main
  evc_in "${REPO}" new-feature stack

  local order="feat-a,feat-b,feat-c,feat-d,feat-e"
  run evc_in "${REPO}" merge-into stack --order "${order}"
  assert_success
  assert_output --partial "while merging 'feat-c'"
  assert_output --partial "After resolving them, run: evc merge-into stack --order ${order}"
  assert_equal "$(git -C "${REPO}" branch --show-current)" "stack"
  run git -C "${REPO}" rev-parse --verify --quiet MERGE_HEAD
  assert_failure
  assert_file_exist "${REPO}/a.txt"
  assert_file_not_exist "${REPO}/d.txt"
  run git -C "${REPO}" show HEAD:README.md
  assert_success
  assert_output --partial "<<<<<<< stack"
  assert_output --partial ">>>>>>> feat-c"
  refute_output --partial "<<<<<<< HEAD"
  assert_output --partial "from-b"
  assert_output --partial "from-c"

  echo "resolved" >"${REPO}/README.md"
  run evc_in "${REPO}" merge-into stack --order "${order}"
  assert_success
  assert_output --partial "merge-into complete"
  assert_file_exist "${REPO}/d.txt"
  assert_file_exist "${REPO}/e.txt"
  assert_equal "$(git -C "${REPO}" branch --show-current)" "stack"
  run git -C "${REPO}" show HEAD:README.md
  assert_success
  assert_output --partial "resolved"
}
