#!/usr/bin/env bats

setup() {
  load "../test_helper/evc_test_helper"
  install_evc_for_test
  BARE="${BATS_TEST_TMPDIR}/remote.git"
  REPO="${BATS_TEST_TMPDIR}/work"
  make_remote_pair "${BARE}" "${REPO}"
  BARE="${REMOTE_BARE_URL}"
}

@test "pull without origin errors" {
  LOCAL="${BATS_TEST_TMPDIR}/nolink"
  make_local_repo "${LOCAL}"
  run evc_in "${LOCAL}" pull
  assert_failure
  assert_output --partial "Usage: evc pull <REMOTE-BRANCH-NAME>"

  run evc_in "${LOCAL}" pull main
  assert_failure
  assert_output --partial "No remote configured."
}

@test "pull records merge conflicts on the feature branch" {
  evc_in "${REPO}" new-feature feat-conflict
  echo "local-side" >"${REPO}/README.md"
  git -C "${REPO}" add README.md
  git -C "${REPO}" commit -m "local side"
  evc_in "${REPO}" push feat-conflict "publish conflict feature"

  OTHER="${BATS_TEST_TMPDIR}/other-conflict"
  git clone "${BARE}" "${OTHER}"
  git -C "${OTHER}" config user.email "evc-test@example.com"
  git -C "${OTHER}" config user.name "EVC Test"
  git -C "${OTHER}" checkout feat-conflict
  echo "remote-side" >"${OTHER}/README.md"
  git -C "${OTHER}" add README.md
  git -C "${OTHER}" commit -m "remote side"
  git -C "${OTHER}" push origin feat-conflict

  echo "later-local" >"${REPO}/README.md"
  git -C "${REPO}" add README.md
  git -C "${REPO}" commit -m "later local"

  run evc_in "${REPO}" pull feat-conflict
  assert_success
  assert_output --partial "Merge conflicts were recorded on this branch"
  assert_equal "$(git -C "${REPO}" branch --show-current)" "feat-conflict"
  run git -C "${REPO}" rev-parse --verify --quiet MERGE_HEAD
  assert_failure
  run git -C "${REPO}" branch --list 'evc-pull-tmp-*'
  assert_output ""
  run git -C "${REPO}" show HEAD:README.md
  assert_success
  assert_output --partial "<<<<<<< local"
  assert_output --partial ">>>>>>> remote"
  refute_output --partial "<<<<<<< HEAD"
  refute_output --partial "evc-pull-tmp-"
  assert_output --partial "later-local"
  assert_output --partial "remote-side"

  echo "resolved" >"${REPO}/README.md"
  evc_in "${REPO}" switch-feature main
  run git -C "${REPO}" show feat-conflict:README.md
  assert_success
  assert_output "resolved"
}

@test "pull pulls main but not non-remote feature branch" {
  evc_in "${REPO}" new-feature feat-non-remote
  echo "local" >"${REPO}/local.txt"
  git -C "${REPO}" add local.txt
  git -C "${REPO}" commit -m "Snapshot local"

  OTHER="${BATS_TEST_TMPDIR}/other"
  git clone "${BARE}" "${OTHER}"
  git -C "${OTHER}" config user.email "evc-test@example.com"
  git -C "${OTHER}" config user.name "EVC Test"
  echo "remote-main" >"${OTHER}/remote-main.txt"
  git -C "${OTHER}" add remote-main.txt
  git -C "${OTHER}" commit -m "on main"
  git -C "${OTHER}" push origin main

  run evc_in "${REPO}" pull feat-non-remote
  assert_failure
  assert_output --partial "No remote branch named 'feat-non-remote'."
  assert_file_not_exist "${REPO}/remote-main.txt"

  run evc_in "${REPO}" pull main
  assert_success
  assert_equal "$(git -C "${REPO}" branch --show-current)" "main"
  assert_file_exist "${REPO}/remote-main.txt"
  run git -C "${REPO}" cat-file -e feat-non-remote:remote-main.txt
  assert_failure
}

@test "pull REMOTE-BRANCH-NAME creates tracking local branch" {
  OTHER="${BATS_TEST_TMPDIR}/seed"
  git clone "${BARE}" "${OTHER}"
  git -C "${OTHER}" config user.email "evc-test@example.com"
  git -C "${OTHER}" config user.name "EVC Test"
  git -C "${OTHER}" checkout -b feat-remote
  echo "from-remote" >"${OTHER}/from-remote.txt"
  git -C "${OTHER}" add from-remote.txt
  git -C "${OTHER}" commit -m "remote feature"
  git -C "${OTHER}" push -u origin feat-remote

  run evc_in "${REPO}" pull feat-remote
  assert_success
  assert_equal "$(git -C "${REPO}" branch --show-current)" "feat-remote"
  assert_equal "$(git -C "${REPO}" rev-parse --abbrev-ref --symbolic-full-name '@{u}')" "origin/feat-remote"
  assert_file_exist "${REPO}/from-remote.txt"
}

@test "pull pulls remote feature branch, merge-into --order main merges main into local feature branch" {
  evc_in "${REPO}" new-feature feat-track
  echo "one" >"${REPO}/one.txt"
  git -C "${REPO}" add one.txt
  git -C "${REPO}" commit -m "Snapshot one"
  evc_in "${REPO}" push feat-track "first push"

  OTHER="${BATS_TEST_TMPDIR}/other-feat"
  git clone "${BARE}" "${OTHER}"
  git -C "${OTHER}" config user.email "evc-test@example.com"
  git -C "${OTHER}" config user.name "EVC Test"
  git -C "${OTHER}" checkout feat-track
  echo "two" >"${OTHER}/two.txt"
  git -C "${OTHER}" add two.txt
  git -C "${OTHER}" commit -m "remote feature update"
  git -C "${OTHER}" push origin feat-track

  git -C "${OTHER}" checkout main
  echo "main2" >"${OTHER}/main2.txt"
  git -C "${OTHER}" add main2.txt
  git -C "${OTHER}" commit -m "main update"
  git -C "${OTHER}" push origin main

  echo "three" >"${REPO}/three.txt"
  git -C "${REPO}" add three.txt
  git -C "${REPO}" commit -m "Snapshot three"

  run evc_in "${REPO}" pull feat-track
  assert_success
  assert_equal "$(git -C "${REPO}" branch --show-current)" "feat-track"
  assert_file_exist "${REPO}/two.txt"
  assert_file_not_exist "${REPO}/main2.txt"
  assert_file_exist "${REPO}/three.txt"

  run evc_in "${REPO}" pull main
  assert_success
  run evc_in "${REPO}" merge-into feat-track --order main
  assert_success
  assert_equal "$(git -C "${REPO}" branch --show-current)" "feat-track"
  assert_file_exist "${REPO}/two.txt"
  assert_file_exist "${REPO}/main2.txt"
  assert_file_exist "${REPO}/three.txt"
}

@test "push from dirty main exits when the user declines moving work" {
  echo "stay" >"${REPO}/stay.txt"
  run bash -c "printf 'N\n' | (cd '${REPO}' && '${EVC_BIN}' push feat-declined 'Should not push')"
  assert_failure
  assert_output --partial "Move it to a new feature 'feat-declined'"
  assert_output --partial "Push cancelled. Create a new feature for your work, then push again."
  assert_equal "$(git -C "${REPO}" branch --show-current)" "main"
  assert_file_exist "${REPO}/stay.txt"
  run git -C "${REPO}" show-ref --verify --quiet refs/heads/feat-declined
  assert_failure
  run git -C "${BARE}" rev-parse --verify refs/heads/feat-declined
  assert_failure
}

@test "push BRANCH-NAME from main creates that feature" {
  echo "from-main" >"${REPO}/extra.txt"
  run bash -c "printf 'Y\n' | (cd '${REPO}' && '${EVC_BIN}' push feat-from-main 'Publish extra')"
  assert_success
  assert_output --partial "Move it to a new feature 'feat-from-main'"
  assert_equal "$(git -C "${REPO}" branch --show-current)" "feat-from-main"
  run git -C "${BARE}" rev-parse --verify refs/heads/feat-from-main
  assert_success
  run git -C "${REPO}" log -1 --pretty=%s
  assert_output "Publish extra"
  run git -C "${REPO}" show HEAD:extra.txt
  assert_success
  assert_output "from-main"
}

@test "push refuses when remote has unincorporated changes" {
  evc_in "${REPO}" new-feature feat-stale
  echo "one" >"${REPO}/one.txt"
  git -C "${REPO}" add one.txt
  git -C "${REPO}" commit -m "Snapshot one"
  evc_in "${REPO}" push feat-stale "first"

  OTHER="${BATS_TEST_TMPDIR}/other-stale"
  git clone "${BARE}" "${OTHER}"
  git -C "${OTHER}" config user.email "evc-test@example.com"
  git -C "${OTHER}" config user.name "EVC Test"
  git -C "${OTHER}" checkout feat-stale
  echo "remote" >"${OTHER}/remote.txt"
  git -C "${OTHER}" add remote.txt
  git -C "${OTHER}" commit -m "remote only"
  git -C "${OTHER}" push origin feat-stale

  echo "local" >"${REPO}/local.txt"
  git -C "${REPO}" add local.txt
  git -C "${REPO}" commit -m "Snapshot local"

  run evc_in "${REPO}" push feat-stale "should fail"
  assert_failure
  assert_output --partial "There are unincorporated changes in remote"
}

@test "push prompts when remote same-name exists without tracking" {
  evc_in "${REPO}" new-feature feat-dup
  echo "one" >"${REPO}/one.txt"
  git -C "${REPO}" add one.txt
  git -C "${REPO}" commit -m "Snapshot one"
  git -C "${REPO}" push origin feat-dup
  git -C "${REPO}" branch --unset-upstream 2>/dev/null || true

  echo "two" >"${REPO}/two.txt"
  git -C "${REPO}" add two.txt
  git -C "${REPO}" commit -m "Snapshot two"

  run bash -c "printf 'N\n' | (cd '${REPO}' && '${EVC_BIN}' push feat-dup 'should cancel')"
  assert_failure
  assert_output --partial "rename"

  run bash -c "printf 'Y\n' | (cd '${REPO}' && '${EVC_BIN}' push feat-dup 'contribute')"
  assert_success
  assert_equal "$(git -C "${REPO}" rev-parse --abbrev-ref --symbolic-full-name '@{u}')" "origin/feat-dup"
}

@test "push squashes only unpushed commits" {
  evc_in "${REPO}" new-feature feat-push
  echo "one" >"${REPO}/one.txt"
  git -C "${REPO}" add one.txt
  git -C "${REPO}" commit -m "Snapshot one"
  echo "two" >"${REPO}/two.txt"
  git -C "${REPO}" add two.txt
  git -C "${REPO}" commit -m "Snapshot two"

  run evc_in "${REPO}" push feat-push "Add one and two"
  assert_success
  first=$(git -C "${REPO}" rev-parse HEAD)
  assert_equal "$(git -C "${REPO}" rev-list --count origin/main..HEAD)" "1"

  echo "three" >"${REPO}/three.txt"
  git -C "${REPO}" add three.txt
  git -C "${REPO}" commit -m "Snapshot three"
  echo "four" >"${REPO}/four.txt"
  git -C "${REPO}" add four.txt
  git -C "${REPO}" commit -m "Snapshot four"

  run evc_in "${REPO}" push feat-push "Add three and four"
  assert_success
  # Previously pushed commit remains; one new squashed commit on top.
  assert_equal "$(git -C "${REPO}" rev-list --count origin/main..HEAD)" "2"
  assert_equal "$(git -C "${REPO}" rev-parse HEAD~1)" "${first}"
  run git -C "${REPO}" log -1 --pretty=%s
  assert_output "Add three and four"
}

@test "push main is allowed only when the remote has no main" {
  local bare dest work
  bare="${BATS_TEST_TMPDIR}/empty.git"
  git init --bare -b main "${bare}"
  bare=$(cd "${bare}" && pwd)
  dest="${BATS_TEST_TMPDIR}/empty-parent"
  mkdir -p "${dest}"
  run evc_in "${dest}" clone "${bare}"
  assert_success
  work="${dest}/empty"
  echo "hello" >"${work}/notes.txt"

  run evc_in "${work}" push feat "too soon"
  assert_failure
  assert_output --partial "evc push main <CHANGE-DESCRIPTION>"
  assert_equal "$(git -C "${work}" branch --show-current)" "main"
  run git -C "${work}" show-ref --verify --quiet refs/heads/feat
  assert_failure

  run evc_in "${work}" push main "Initial"
  assert_success
  assert_equal "$(git -C "${work}" branch --show-current)" "main"
  run git -C "${work}" log -1 --pretty=%s
  assert_output "Initial"
  local check="${BATS_TEST_TMPDIR}/empty-check"
  git clone "${bare}" "${check}"
  assert_file_exist "${check}/notes.txt"

  run evc_in "${work}" push main "Again"
  assert_failure
  assert_output --partial "Cannot push 'main'."

  echo "feat" >"${work}/feat.txt"
  run bash -c "printf 'Y\n' | (cd '${work}' && '${EVC_BIN}' push feat 'Add feat')"
  assert_success
  assert_equal "$(git -C "${work}" branch --show-current)" "feat"
  assert_file_exist "${work}/feat.txt"
}

@test "clone clones into a new folder" {
  DEST="${BATS_TEST_TMPDIR}/cloned"
  mkdir -p "${DEST}"
  run evc_in "${DEST}" clone "${BARE}"
  assert_success
  local name
  name=$(basename "${BARE}")
  name=${name%.git}
  assert_file_exist "${DEST}/${name}/README.md"
  assert_dir_exist "${DEST}/${name}/.git"
  [[ ! -d "${DEST}/.git" ]]
}
