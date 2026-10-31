#!/usr/bin/env bats

setup() {
  load "../test_helper/evc_test_helper"
  install_evc_for_test
  REPO="${BATS_TEST_TMPDIR}/repo"
  make_local_repo "${REPO}"
}

@test "git commands write logs under project .evc/logs" {
  evc_in "${REPO}" new-feature feat-log
  assert_dir_exist "${REPO}/.evc/logs"
  # Batched into one UTC-hour file (not one file per run_git call).
  local stamp count
  stamp=$(date -u +%Y%m%d_%H00_UTC)
  assert_file_exist "${REPO}/.evc/logs/git_${stamp}.log"
  count=$(find "${REPO}/.evc/logs" -type f -name 'git_*.log' | wc -l)
  [[ "${count}" -eq 1 ]]
  local log="${REPO}/.evc/logs/git_${stamp}.log"
  # The evc command is recorded once, with the git commands indented under it.
  run grep -c '^evc new-feature feat-log$' "${log}"
  assert_success
  [[ "${output}" -eq 1 ]]
  # Multiple git invocations from the same EVC command share that hour's log.
  run grep -c '^    + git ' "${log}"
  assert_success
  [[ "${output}" -ge 2 ]]
  local line
  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ "${line}" == evc\ * || "${line}" == "    "* ]]
  done <"${log}"
}

@test "snapshot commits exclude .evc" {
  git -C "${REPO}" branch -m main trunk
  evc_in "${REPO}" configure-main-branch-name trunk
  echo "work" >"${REPO}/work.txt"
  run evc_in "${REPO}" new-feature feat
  assert_success
  run git -C "${REPO}" ls-tree -r --name-only HEAD
  assert_success
  assert_output --partial "work.txt"
  refute_output --partial ".evc/"
  assert_file_exist "${REPO}/.evc/main-branch-name"
}
