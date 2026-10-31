#!/usr/bin/env bats

setup() {
  load "../test_helper/evc_test_helper"
  if [[ -z "${EVC_TEST_REMOTE_URL:-}" ]]; then
    skip "Set EVC_TEST_REMOTE_URL to run networked remote tests"
  fi
  install_evc_for_test
  DEST="${BATS_TEST_TMPDIR}/net-clone"
  mkdir -p "${DEST}"
}

@test "clone from EVC_TEST_REMOTE_URL" {
  run evc_in "${DEST}" clone "${EVC_TEST_REMOTE_URL}"
  assert_success
  local name
  name=$(basename "${EVC_TEST_REMOTE_URL}")
  name=${name%.git}
  assert_dir_exist "${DEST}/${name}/.git"
  [[ ! -d "${DEST}/.git" ]]
}
