#!/usr/bin/env bash
# Validate the Home Assistant repository metadata locally or in GitHub Actions.
# From the repository root, run: .github/scripts/repository-metadata.sh

set -Eeuo pipefail

export LC_ALL=C

repository_file='repository.yaml'
fail_count=0

fail() {
  local rule=$1
  local fix=$2

  printf '::error::Repository metadata — %s. Fix: %s\n' "$rule" "$fix" >&2
  fail_count=$((fail_count + 1))
}

warn() {
  local rule=$1
  local fix=$2

  printf '::warning::Repository metadata — %s. Fix: %s\n' "$rule" "$fix" >&2
}

is_absolute_http_url() {
  local url=$1

  [[ "$url" =~ ^https?://[^/?#[:space:]]+([/?#][^[:space:]]*)?$ ]]
}

if [[ ! -f "$repository_file" ]]; then
  fail "'$repository_file' is missing" "create '$repository_file' at the repository root"
  exit 1
fi

for command in jq yq; do
  if ! command -v "$command" >/dev/null 2>&1; then
    fail "required command '$command' is unavailable" "install '$command' before running this validator"
  fi
done

if ((fail_count > 0)); then
  exit 1
fi

repository_json=''
if ! repository_json=$(yq e -o=json -I=0 '.' "$repository_file" 2>/dev/null); then
  fail "'$repository_file' is not valid YAML" "fix the YAML syntax in '$repository_file'"
  exit 1
fi

repository_type=''
if ! repository_type=$(jq -r 'type' <<< "$repository_json" 2>/dev/null); then
  fail "'$repository_file' could not be read as one YAML document" "make '$repository_file' contain one valid YAML document"
  exit 1
fi

if [[ "$repository_type" != 'object' ]]; then
  fail "the top level of '$repository_file' is $repository_type, not a mapping" "make '$repository_file' contain a mapping of repository metadata"
  exit 1
fi

name_type=$(jq -r 'if has("name") then (.name | type) else "missing" end' <<< "$repository_json")
if [[ "$name_type" == 'missing' ]]; then
  fail "required key 'name' is missing" "add a non-empty repository name to '$repository_file'"
elif [[ "$name_type" != 'string' ]]; then
  fail "'name' must be a non-empty string, but is $name_type" "set 'name' in '$repository_file' to a quoted repository name"
else
  name=$(jq -r '.name' <<< "$repository_json")
  if [[ -z "${name//[[:space:]]/}" ]]; then
    fail "'name' must not be empty" "set 'name' in '$repository_file' to a non-empty repository name"
  fi
fi

url_type=$(jq -r 'if has("url") then (.url | type) else "missing" end' <<< "$repository_json")
if [[ "$url_type" != 'missing' ]]; then
  if [[ "$url_type" != 'string' ]]; then
    fail "optional key 'url' must be a string, but is $url_type" "set 'url' in '$repository_file' to an absolute http(s) URL or remove the optional key"
  else
    url=$(jq -r '.url' <<< "$repository_json")
    if ! is_absolute_http_url "$url"; then
      fail "'url' is not a valid absolute http(s) URL" "set 'url' in '$repository_file' to an absolute URL such as 'https://example.com/addons' or remove the optional key"
    fi
  fi
fi

maintainer_type=$(jq -r 'if has("maintainer") then (.maintainer | type) else "missing" end' <<< "$repository_json")
if [[ "$maintainer_type" != 'missing' ]]; then
  if [[ "$maintainer_type" != 'string' ]]; then
    fail "optional key 'maintainer' must be non-empty contact information, but is $maintainer_type" "set 'maintainer' in '$repository_file' to contact information or remove the optional key"
  else
    maintainer=$(jq -r '.maintainer' <<< "$repository_json")
    if [[ -z "${maintainer//[[:space:]]/}" ]]; then
      fail "optional key 'maintainer' must not be empty" "set 'maintainer' in '$repository_file' to contact information such as 'Your Name <you@example.com>' or remove the optional key"
    fi
  fi
fi

while IFS= read -r key; do
  warn "unknown top-level key '$key'" "confirm that Home Assistant supports it; keep the documented keys 'name', 'url', and 'maintainer'"
done < <(jq -r 'keys[] | select(. != "name" and . != "url" and . != "maintainer")' <<< "$repository_json")

if ((fail_count > 0)); then
  printf 'Repository metadata validation failed with %d violation(s).\n' "$fail_count" >&2
  exit 1
fi

printf 'Repository metadata validation passed.\n'
