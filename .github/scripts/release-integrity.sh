#!/usr/bin/env bash
# Validate add-on release metadata locally or in GitHub Actions.
# From the repository root, run: .github/scripts/release-integrity.sh

set -Eeuo pipefail

export LC_ALL=C

declare -a supported_configs=(config.json config.yaml config.yml)
declare -A addon_config_count=()
declare -A addon_config_path=()
declare -A addon_version=()
declare -a addons=()
fail_count=0

fail() {
  local addon=$1
  local rule=$2
  local fix=$3

  printf '::error::Add-on "%s" — %s. Fix: %s\n' "$addon" "$rule" "$fix" >&2
  fail_count=$((fail_count + 1))
}

fail_global() {
  local rule=$1
  local fix=$2

  printf '::error::Release integrity — %s. Fix: %s\n' "$rule" "$fix" >&2
  fail_count=$((fail_count + 1))
}

is_semver() {
  local version=$1
  local numeric_identifier='(0|[1-9][0-9]*)'
  local prerelease_identifier="($numeric_identifier|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)"
  local semver_regex="^$numeric_identifier\\.$numeric_identifier\\.$numeric_identifier(-$prerelease_identifier(\\.$prerelease_identifier)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

  [[ "$version" =~ $semver_regex ]]
}

compare_numeric_strings() {
  local left=$1
  local right=$2

  if ((${#left} < ${#right})); then
    printf '%s\n' '-1'
  elif ((${#left} > ${#right})); then
    printf '%s\n' '1'
  elif [[ "$left" == "$right" ]]; then
    printf '%s\n' '0'
  elif [[ "$left" < "$right" ]]; then
    printf '%s\n' '-1'
  else
    printf '%s\n' '1'
  fi
}

compare_prerelease() {
  local left=$1
  local right=$2
  declare -a left_ids=()
  declare -a right_ids=()

  if [[ -z "$left" && -z "$right" ]]; then
    printf '%s\n' '0'
    return
  elif [[ -z "$left" ]]; then
    printf '%s\n' '1'
    return
  elif [[ -z "$right" ]]; then
    printf '%s\n' '-1'
    return
  fi

  IFS='.' read -r -a left_ids <<< "$left"
  IFS='.' read -r -a right_ids <<< "$right"

  local index=0
  local left_id
  local right_id
  local numeric_comparison
  while ((index < ${#left_ids[@]} && index < ${#right_ids[@]})); do
    left_id=${left_ids[index]}
    right_id=${right_ids[index]}

    if [[ "$left_id" =~ ^[0-9]+$ && "$right_id" =~ ^[0-9]+$ ]]; then
      numeric_comparison=$(compare_numeric_strings "$left_id" "$right_id")
      if [[ "$numeric_comparison" != '0' ]]; then
        printf '%s\n' "$numeric_comparison"
        return
      fi
    elif [[ "$left_id" =~ ^[0-9]+$ ]]; then
      printf '%s\n' '-1'
      return
    elif [[ "$right_id" =~ ^[0-9]+$ ]]; then
      printf '%s\n' '1'
      return
    elif [[ "$left_id" == "$right_id" ]]; then
      :
    elif [[ "$left_id" < "$right_id" ]]; then
      printf '%s\n' '-1'
      return
    else
      printf '%s\n' '1'
      return
    fi

    index=$((index + 1))
  done

  if ((${#left_ids[@]} < ${#right_ids[@]})); then
    printf '%s\n' '-1'
  elif ((${#left_ids[@]} > ${#right_ids[@]})); then
    printf '%s\n' '1'
  else
    printf '%s\n' '0'
  fi
}

compare_semver() {
  local left=$1
  local right=$2
  local left_without_build=${left%%+*}
  local right_without_build=${right%%+*}
  local left_core=${left_without_build%%-*}
  local right_core=${right_without_build%%-*}
  local left_prerelease=''
  local right_prerelease=''
  declare -a left_parts=()
  declare -a right_parts=()

  if [[ "$left_without_build" == *-* ]]; then
    left_prerelease=${left_without_build#*-}
  fi
  if [[ "$right_without_build" == *-* ]]; then
    right_prerelease=${right_without_build#*-}
  fi

  IFS='.' read -r -a left_parts <<< "$left_core"
  IFS='.' read -r -a right_parts <<< "$right_core"

  local index
  local numeric_comparison
  for index in 0 1 2; do
    numeric_comparison=$(compare_numeric_strings "${left_parts[index]}" "${right_parts[index]}")
    if [[ "$numeric_comparison" != '0' ]]; then
      printf '%s\n' "$numeric_comparison"
      return
    fi
  done

  compare_prerelease "$left_prerelease" "$right_prerelease"
}

validate_changelog() {
  local addon=$1
  local version=$2
  local changelog="$addon/CHANGELOG.md"
  local line
  local first_heading=''
  local in_section=false
  local section_has_content=false

  if [[ ! -f "$changelog" ]]; then
    fail "$addon" 'CHANGELOG.md is missing' "add CHANGELOG.md with a first section headed '## $version' and release notes"
    return
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^##[[:space:]] ]]; then
      if [[ -z "$first_heading" ]]; then
        first_heading=$line
        in_section=true
        continue
      fi
      break
    fi

    if [[ "$in_section" == true && -n "${line//[[:space:]]/}" ]]; then
      section_has_content=true
    fi
  done < "$changelog"

  if [[ -z "$first_heading" ]]; then
    fail "$addon" 'CHANGELOG.md has no ## heading' "add a first section headed '## $version'"
  elif [[ "$first_heading" != "## $version" ]]; then
    fail "$addon" "the first CHANGELOG.md heading is '$first_heading', not '## $version'" "make the first heading exactly '## $version'"
  fi

  if [[ "$section_has_content" != true ]]; then
    fail "$addon" "the CHANGELOG.md section for '$version' has no content" "add non-empty release notes beneath '## $version'"
  fi

  return 0
}

validate_static_rules() {
  local addon
  local config_path
  local config_json
  local config_type
  local version_type
  local image_type
  local version
  local image
  local image_name

  if ((${#addons[@]} == 0)); then
    return 0
  fi

  for addon in "${addons[@]}"; do
    if [[ "${addon_config_count["$addon"]}" != '1' ]]; then
      fail "$addon" "found ${addon_config_count["$addon"]} supported config files" "keep exactly one of config.json, config.yaml, or config.yml in the add-on directory"
      continue
    fi

    config_path=${addon_config_path["$addon"]}
    if ! config_json=$(yq e -o=json -I=0 '.' "$config_path" 2>/dev/null); then
      fail "$addon" "the supported config file '$config_path' is not valid YAML/JSON" "fix the syntax in '$config_path'"
      continue
    fi

    config_type=$(jq -r 'type' <<< "$config_json")
    if [[ "$config_type" != 'object' ]]; then
      fail "$addon" 'the add-on config is not an object' "make '$config_path' contain the add-on configuration object"
      continue
    fi

    version_type=$(jq -r 'if has("version") then (.version | type) else "missing" end' <<< "$config_json")
    if [[ "$version_type" != 'string' ]]; then
      fail "$addon" "version must be a non-empty string, but is $version_type" "set version in '$config_path' to a quoted SemVer string such as '1.2.6'"
      continue
    fi

    version=$(jq -r '.version' <<< "$config_json")
    if [[ -z "$version" ]]; then
      fail "$addon" 'version is an empty string' "set version in '$config_path' to a quoted SemVer string"
      continue
    fi

    if ! is_semver "$version"; then
      fail "$addon" "version '$version' is not valid SemVer without a v prefix" "set version in '$config_path' to a string like '1.2.6'; Home Assistant documents the field as a string"
      continue
    fi
    addon_version["$addon"]=$version

    image_type=$(jq -r 'if has("image") then (.image | type) else "missing" end' <<< "$config_json")
    if [[ "$image_type" != 'string' ]]; then
      fail "$addon" "image must be a non-empty untagged repository reference, but is $image_type" "set image in '$config_path' to an untagged repository such as 'ghcr.io/example/addon'"
      continue
    fi

    image=$(jq -r '.image' <<< "$config_json")
    image_name=${image##*/}
    if [[ -z "$image" || "$image" =~ [[:space:]] || "$image" == */ || "$image" == /* || "$image" == *//* ]]; then
      fail "$addon" "image '$image' is not a valid repository reference" "set image in '$config_path' to a non-empty repository without whitespace or empty path components"
    elif [[ "$image" == *@* ]]; then
      fail "$addon" "image '$image' contains a digest" "remove the @digest from image in '$config_path'; version supplies the tag"
    elif [[ "$image_name" == *:* ]]; then
      fail "$addon" "image '$image' contains a tag" "remove the :tag from image in '$config_path'; version supplies the tag"
    fi

    validate_changelog "$addon" "$version"
  done

  return 0
}

find_base_config() {
  local base_ref=$1
  local addon=$2
  local candidate
  local found=''
  local count=0

  for candidate in "${supported_configs[@]}"; do
    if git cat-file -e "$base_ref:$addon/$candidate" 2>/dev/null; then
      found=$candidate
      count=$((count + 1))
    fi
  done

  printf '%s\t%s\n' "$count" "$found"
}

validate_pr_diff_rules() {
  local event_name=${GITHUB_EVENT_NAME:-local}
  local base_ref_name=${GITHUB_BASE_REF:-}
  local diff_file
  local changed_file
  local addon
  local basename
  local base_config_info
  local base_config_count
  local base_config
  local base_config_json
  local base_version_type
  local base_version
  local current_version
  local comparison
  declare -A release_affecting=()
  declare -A changelog_changed=()

  if [[ "$event_name" != 'pull_request' ]]; then
    return 0
  fi

  if [[ -z "$base_ref_name" ]]; then
    fail_global 'the pull request base branch is unavailable' 'run this job with GITHUB_BASE_REF set and fetch the base branch before invoking the script'
    return
  fi

  base_ref_name="origin/$base_ref_name"
  if ! git rev-parse --verify "$base_ref_name^{commit}" >/dev/null 2>&1; then
    fail_global "the base ref '$base_ref_name' is not fetched" "check out the repository with fetch-depth: 0 so origin/$GITHUB_BASE_REF is available"
    return
  fi

  diff_file=$(mktemp)
  if ! git diff --name-only --no-renames -z "$base_ref_name...HEAD" > "$diff_file"; then
    rm -f "$diff_file"
    fail_global "unable to compute the PR diff '$base_ref_name...HEAD'" 'ensure the fetched base ref and HEAD are valid commits'
    return
  fi

  while IFS= read -r -d '' changed_file; do
    [[ "$changed_file" == */* ]] || continue
    addon=${changed_file%%/*}
    [[ -n "${addon_config_count["$addon"]+set}" ]] || continue
    basename=${changed_file##*/}

    case "$basename" in
      README.md|DOCS.md|CHANGELOG.md|icon.png|logo.png)
        if [[ "$basename" == 'CHANGELOG.md' ]]; then
          changelog_changed["$addon"]=1
        fi
        ;;
      *)
        release_affecting["$addon"]=1
        ;;
    esac
  done < "$diff_file"
  rm -f "$diff_file"

  if ((${#release_affecting[@]} == 0)); then
    return 0
  fi

  for addon in "${!release_affecting[@]}"; do
    if [[ -z "${addon_version["$addon"]+set}" ]]; then
      fail "$addon" 'the current version is unavailable for PR comparison' "repair this add-on's static version rule before changing release-affecting files"
      continue
    fi
    base_config_info=$(find_base_config "$base_ref_name" "$addon")
    IFS=$'\t' read -r base_config_count base_config <<< "$base_config_info"

    if [[ "$base_config_count" == '0' ]]; then
      continue
    fi
    if [[ "$base_config_count" != '1' ]]; then
      fail "$addon" "the base branch has $base_config_count supported config files, so the version cannot be compared" "leave exactly one of config.json, config.yaml, or config.yml on the base branch"
      continue
    fi

    if ! base_config_json=$(git show "$base_ref_name:$addon/$base_config" | yq e -o=json -I=0 '.' - 2>/dev/null); then
      fail "$addon" "the base config '$base_config' cannot be parsed" "fix the base branch config before changing release-affecting files"
      continue
    fi

    base_version_type=$(jq -r 'if has("version") then (.version | type) else "missing" end' <<< "$base_config_json")
    if [[ "$base_version_type" != 'string' ]]; then
      fail "$addon" "the base version is not a string ($base_version_type)" "repair the base branch version before changing release-affecting files"
      continue
    fi
    base_version=$(jq -r '.version' <<< "$base_config_json")
    if ! is_semver "$base_version"; then
      fail "$addon" "the base version '$base_version' is not valid SemVer" "repair the base branch version before changing release-affecting files"
      continue
    fi
    current_version=${addon_version["$addon"]}
    comparison=$(compare_semver "$current_version" "$base_version")
    if ((comparison <= 0)); then
      fail "$addon" "release-affecting changes do not increase version '$base_version' to a greater SemVer (current: '$current_version')" "increase this add-on's version in its config; versions are compared as SemVer, not strings"
    fi
    if [[ "$current_version" != "$base_version" && -z "${changelog_changed["$addon"]+set}" ]]; then
      fail "$addon" "version changed from '$base_version' to '$current_version' without a CHANGELOG.md change" "add a new '## $current_version' section to this add-on's CHANGELOG.md"
    fi
  done

  return 0
}

while IFS= read -r config_path; do
  addon=${config_path#./}
  addon=${addon%%/*}
  if [[ -z "${addon_config_count["$addon"]+set}" ]]; then
    addons+=("$addon")
    addon_config_count["$addon"]=0
  fi
  addon_config_count["$addon"]=$((addon_config_count["$addon"] + 1))
  addon_config_path["$addon"]="$config_path"
done < <(find . -mindepth 2 -maxdepth 2 -type f \( -name config.json -o -name config.yaml -o -name config.yml \) -print | sort)

validate_static_rules

validate_pr_diff_rules

if ((fail_count > 0)); then
  printf 'Release integrity failed with %d violation(s).\n' "$fail_count" >&2
  exit 1
fi

printf 'Release integrity passed for %d add-on(s).\n' "${#addons[@]}"
