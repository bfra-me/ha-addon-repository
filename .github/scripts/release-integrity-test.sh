#!/usr/bin/env bash
# Run from the repository root with no arguments:
#   .github/scripts/release-integrity-test.sh

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
VALIDATOR="$SCRIPT_DIR/release-integrity.sh"
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

passed=0
failed=0

new_case_dir() {
  mktemp -d "$TMP_ROOT/case.XXXXXX"
}

init_repo() {
  local dir=$1

  git init -q -b main "$dir"
  git -C "$dir" config user.email test@invalid.local
  git -C "$dir" config user.name 'Release Integrity Test'
  mkdir -p "$dir/.github/scripts"
  cp "$VALIDATOR" "$dir/.github/scripts/release-integrity.sh"
  chmod +x "$dir/.github/scripts/release-integrity.sh"
}

publish_base() {
  local dir=$1
  local remote

  git -C "$dir" add -A
  git -C "$dir" commit -q -m base
  remote=$(mktemp -d "$TMP_ROOT/remote.XXXXXX")
  git init -q --bare "$remote"
  git -C "$dir" remote add origin "$remote"
  git -C "$dir" push -q origin main
  git -C "$dir" checkout -q -b feature
}

commit_head() {
  local dir=$1

  git -C "$dir" add -A
  git -C "$dir" commit -q -m change
}

write_addon() {
  local dir=$1
  local addon=$2
  local version=$3
  local changelog=$4
  local image=${5:-registry/namespace/$addon}

  mkdir -p "$dir/$addon"
  printf 'name: Test add-on\nversion: "%s"\nslug: "%s"\nimage: "%s"\n' \
    "$version" "$addon" "$image" > "$dir/$addon/config.yaml"
  printf '%s\n' "$changelog" > "$dir/$addon/CHANGELOG.md"
}

run_validator() {
  local dir=$1
  local expected_status=$2
  local expected_text=$3
  local mode=${4:-local}
  local output
  local status

  set +e
  if [[ "$mode" == pr ]]; then
    output=$(cd "$dir" && GITHUB_EVENT_NAME=pull_request GITHUB_BASE_REF=main ./.github/scripts/release-integrity.sh 2>&1)
  else
    output=$(cd "$dir" && env -u GITHUB_EVENT_NAME -u GITHUB_BASE_REF ./.github/scripts/release-integrity.sh 2>&1)
  fi
  status=$?
  set -e

  if [[ "$status" != "$expected_status" ]]; then
    printf 'expected status %s, got %s\n%s\n' "$expected_status" "$status" "$output" >&2
    return 1
  fi
  if [[ -n "$expected_text" && "$output" != *"$expected_text"* ]]; then
    printf 'expected output containing %s, got:\n%s\n' "$expected_text" "$output" >&2
    return 1
  fi
}

test_static_heading_mismatch() {
  local dir
  dir=$(new_case_dir)
  init_repo "$dir"
  write_addon "$dir" alpha 1.1.0 $'## 1.0.0\n\n- Notes'
  run_validator "$dir" 1 'first CHANGELOG.md heading'
}

test_static_tagged_image() {
  local dir
  dir=$(new_case_dir)
  init_repo "$dir"
  write_addon "$dir" alpha 1.1.0 $'## 1.1.0\n\n- Notes' 'registry/namespace/alpha:old'
  run_validator "$dir" 1 'contains a tag'
}

test_static_digest_image() {
  local dir
  dir=$(new_case_dir)
  init_repo "$dir"
  write_addon "$dir" alpha 1.1.0 $'## 1.1.0\n\n- Notes' 'registry/namespace/alpha@sha256:deadbeef'
  run_validator "$dir" 1 'contains a digest'
}

test_static_missing_changelog() {
  local dir
  dir=$(new_case_dir)
  init_repo "$dir"
  write_addon "$dir" alpha 1.1.0 $'## 1.1.0\n\n- Notes'
  rm "$dir/alpha/CHANGELOG.md"
  run_validator "$dir" 1 'CHANGELOG.md is missing'
}

test_static_leading_zero_semver() {
  local dir
  dir=$(new_case_dir)
  init_repo "$dir"
  write_addon "$dir" alpha 01.1.0 $'## 01.1.0\n\n- Notes'
  run_validator "$dir" 1 'not valid SemVer'
}

test_static_v_prefix_semver() {
  local dir
  dir=$(new_case_dir)
  init_repo "$dir"
  write_addon "$dir" alpha v1.1.0 $'## v1.1.0\n\n- Notes'
  run_validator "$dir" 1 'not valid SemVer'
}

test_static_duplicate_configs() {
  local dir
  dir=$(new_case_dir)
  init_repo "$dir"
  write_addon "$dir" alpha 1.1.0 $'## 1.1.0\n\n- Notes'
  cp "$dir/alpha/config.yaml" "$dir/alpha/config.json"
  run_validator "$dir" 1 'found 2 supported config files'
}

test_content_empty_section() {
  local dir
  dir=$(new_case_dir)
  init_repo "$dir"
  write_addon "$dir" alpha 1.1.0 '## 1.1.0'
  run_validator "$dir" 1 'has no content'
}

test_content_single_line_comment() {
  local dir
  dir=$(new_case_dir)
  init_repo "$dir"
  write_addon "$dir" alpha 1.1.0 $'## 1.1.0\n\n<!-- TODO -->'
  run_validator "$dir" 1 'has no content'
}

test_content_multiline_comment() {
  local dir
  dir=$(new_case_dir)
  init_repo "$dir"
  write_addon "$dir" alpha 1.1.0 $'## 1.1.0\n\n<!--\nTODO: fill in release notes\n-->'
  run_validator "$dir" 1 'has no content'
}

test_content_text_after_comment() {
  local dir
  dir=$(new_case_dir)
  init_repo "$dir"
  write_addon "$dir" alpha 1.1.0 $'## 1.1.0\n\n<!-- comment --> release notes'
  run_validator "$dir" 0 ''
}

prepare_pr_addon() {
  local dir=$1

  init_repo "$dir"
  write_addon "$dir" alpha 1.0.0 $'## 1.0.0\n\n- Initial notes'
  mkdir -p "$dir/alpha/rootfs"
  printf '%s\n' base > "$dir/alpha/rootfs/app"
  publish_base "$dir"
}

test_pr_release_change_without_bump() {
  local dir
  dir=$(new_case_dir)
  prepare_pr_addon "$dir"
  printf '%s\n' changed > "$dir/alpha/rootfs/app"
  commit_head "$dir"
  run_validator "$dir" 1 'do not increase version' pr
}

test_pr_release_change_with_bump() {
  local dir
  dir=$(new_case_dir)
  prepare_pr_addon "$dir"
  printf '%s\n' changed > "$dir/alpha/rootfs/app"
  printf '%s\n' $'## 1.0.1\n\n- Release notes\n\n## 1.0.0\n\n- Initial notes' > "$dir/alpha/CHANGELOG.md"
  printf '%s\n' 'name: Test add-on' 'version: "1.0.1"' 'slug: alpha' 'image: registry/namespace/alpha' > "$dir/alpha/config.yaml"
  commit_head "$dir"
  run_validator "$dir" 0 '' pr
}

test_pr_changelog_only() {
  local dir
  dir=$(new_case_dir)
  prepare_pr_addon "$dir"
  printf '%s\n' $'## 1.0.0\n\n- Clarified notes' > "$dir/alpha/CHANGELOG.md"
  commit_head "$dir"
  run_validator "$dir" 0 '' pr
}

test_pr_nested_root_readme() {
  local dir
  dir=$(new_case_dir)
  prepare_pr_addon "$dir"
  mkdir -p "$dir/alpha/rootfs/etc"
  printf '%s\n' changed > "$dir/alpha/rootfs/etc/README.md"
  commit_head "$dir"
  run_validator "$dir" 1 'do not increase version' pr
}

test_pr_root_readme() {
  local dir
  dir=$(new_case_dir)
  prepare_pr_addon "$dir"
  printf '%s\n' changed > "$dir/alpha/README.md"
  commit_head "$dir"
  run_validator "$dir" 0 '' pr
}

test_pr_delete_config_only() {
  local dir
  dir=$(new_case_dir)
  prepare_pr_addon "$dir"
  rm "$dir/alpha/config.yaml"
  commit_head "$dir"
  run_validator "$dir" 1 'no supported config file exists' pr
}

test_pr_delete_whole_addon() {
  local dir
  dir=$(new_case_dir)
  prepare_pr_addon "$dir"
  rm -rf "$dir/alpha"
  commit_head "$dir"
  run_validator "$dir" 0 '' pr
}

test_pr_rename_without_bump() {
  local dir
  dir=$(new_case_dir)
  prepare_pr_addon "$dir"
  git -C "$dir" mv alpha renamed
  printf '%s\n' changed > "$dir/renamed/rootfs/app"
  commit_head "$dir"
  run_validator "$dir" 1 'do not increase version' pr
}

test_pr_rename_with_bump() {
  local dir
  dir=$(new_case_dir)
  prepare_pr_addon "$dir"
  git -C "$dir" mv alpha renamed
  printf '%s\n' changed > "$dir/renamed/rootfs/app"
  printf '%s\n' $'## 1.0.1\n\n- Renamed release\n\n## 1.0.0\n\n- Initial notes' > "$dir/renamed/CHANGELOG.md"
  printf '%s\n' 'name: Test add-on' 'version: "1.0.1"' 'slug: alpha' 'image: registry/namespace/alpha' > "$dir/renamed/config.yaml"
  commit_head "$dir"
  run_validator "$dir" 0 '' pr
}

test_pr_brand_new_addon() {
  local dir
  dir=$(new_case_dir)
  init_repo "$dir"
  publish_base "$dir"
  write_addon "$dir" beta 1.0.0 $'## 1.0.0\n\n- Initial notes'
  mkdir -p "$dir/beta/rootfs"
  printf '%s\n' new > "$dir/beta/rootfs/app"
  commit_head "$dir"
  run_validator "$dir" 0 '' pr
}

test_pr_addon_isolation() {
  local dir
  dir=$(new_case_dir)
  init_repo "$dir"
  write_addon "$dir" alpha 1.0.0 $'## 1.0.0\n\n- Initial notes'
  write_addon "$dir" beta 1.0.0 $'## 1.0.0\n\n- Initial notes'
  mkdir -p "$dir/alpha/rootfs" "$dir/beta/rootfs"
  printf '%s\n' base > "$dir/alpha/rootfs/app"
  printf '%s\n' base > "$dir/beta/rootfs/app"
  publish_base "$dir"
  printf '%s\n' changed > "$dir/alpha/rootfs/app"
  printf '%s\n' changed > "$dir/beta/rootfs/app"
  printf '%s\n' $'## 1.0.1\n\n- Alpha release\n\n## 1.0.0\n\n- Initial notes' > "$dir/alpha/CHANGELOG.md"
  printf '%s\n' 'name: Test add-on' 'version: "1.0.1"' 'slug: alpha' 'image: registry/namespace/alpha' > "$dir/alpha/config.yaml"
  commit_head "$dir"
  run_validator "$dir" 1 'Add-on "beta"' pr
}

test_pr_semver_1_10_greater_than_1_9() {
  local dir
  dir=$(new_case_dir)
  init_repo "$dir"
  write_addon "$dir" alpha 1.9.0 $'## 1.9.0\n\n- Initial notes'
  mkdir -p "$dir/alpha/rootfs"
  printf '%s\n' base > "$dir/alpha/rootfs/app"
  publish_base "$dir"
  printf '%s\n' changed > "$dir/alpha/rootfs/app"
  printf '%s\n' $'## 1.10.0\n\n- Release notes\n\n## 1.9.0\n\n- Initial notes' > "$dir/alpha/CHANGELOG.md"
  printf '%s\n' 'name: Test add-on' 'version: "1.10.0"' 'slug: alpha' 'image: registry/namespace/alpha' > "$dir/alpha/config.yaml"
  commit_head "$dir"
  run_validator "$dir" 0 '' pr
}

test_pr_version_decrease() {
  local dir
  dir=$(new_case_dir)
  init_repo "$dir"
  write_addon "$dir" alpha 1.2.0 $'## 1.2.0\n\n- Initial notes'
  mkdir -p "$dir/alpha/rootfs"
  printf '%s\n' base > "$dir/alpha/rootfs/app"
  publish_base "$dir"
  printf '%s\n' changed > "$dir/alpha/rootfs/app"
  printf '%s\n' $'## 1.1.0\n\n- Release notes\n\n## 1.2.0\n\n- Initial notes' > "$dir/alpha/CHANGELOG.md"
  printf '%s\n' 'name: Test add-on' 'version: "1.1.0"' 'slug: alpha' 'image: registry/namespace/alpha' > "$dir/alpha/config.yaml"
  commit_head "$dir"
  run_validator "$dir" 1 'do not increase version' pr
}

test_pr_version_reuse() {
  local dir
  dir=$(new_case_dir)
  prepare_pr_addon "$dir"
  printf '%s\n' changed > "$dir/alpha/rootfs/app"
  commit_head "$dir"
  run_validator "$dir" 1 'do not increase version' pr
}

run_case() {
  local name=$1
  local test_function=$2

  if "$test_function"; then
    printf 'PASS %s\n' "$name"
    passed=$((passed + 1))
  else
    printf 'FAIL %s\n' "$name" >&2
    failed=$((failed + 1))
  fi
}

run_case 'static: heading mismatch' test_static_heading_mismatch
run_case 'static: tagged image' test_static_tagged_image
run_case 'static: digest image' test_static_digest_image
run_case 'static: missing CHANGELOG' test_static_missing_changelog
run_case 'static: leading-zero SemVer' test_static_leading_zero_semver
run_case 'static: v-prefixed SemVer' test_static_v_prefix_semver
run_case 'static: duplicate configs' test_static_duplicate_configs
run_case 'content: empty section' test_content_empty_section
run_case 'content: single-line HTML comment' test_content_single_line_comment
run_case 'content: multi-line HTML comment' test_content_multiline_comment
run_case 'content: text after HTML comment close' test_content_text_after_comment
run_case 'PR: release change without bump' test_pr_release_change_without_bump
run_case 'PR: release change with bump and changelog' test_pr_release_change_with_bump
run_case 'PR: changelog-only edit' test_pr_changelog_only
run_case 'PR: nested rootfs README' test_pr_nested_root_readme
run_case 'PR: root README' test_pr_root_readme
run_case 'PR: config-only deletion' test_pr_delete_config_only
run_case 'PR: whole add-on deletion' test_pr_delete_whole_addon
run_case 'PR: rename without bump' test_pr_rename_without_bump
run_case 'PR: rename with bump' test_pr_rename_with_bump
run_case 'PR: brand-new add-on' test_pr_brand_new_addon
run_case 'PR: add-on isolation' test_pr_addon_isolation
run_case 'SemVer: 1.10.0 greater than 1.9.0' test_pr_semver_1_10_greater_than_1_9
run_case 'SemVer: decrease rejected' test_pr_version_decrease
run_case 'SemVer: reuse rejected' test_pr_version_reuse

printf '\n%d passed, %d failed\n' "$passed" "$failed"
if ((failed > 0)); then
  exit 1
fi
