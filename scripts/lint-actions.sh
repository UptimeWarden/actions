#!/usr/bin/env bash
# Lints every <name>/action.yml in this repository:
#   - required metadata (name, description, composite runs, steps)
#   - every `run` step declares a shell
#   - no `${{ }}` expressions inside `run` scripts (inputs go through env)
#   - shellcheck on each `run` script
# Needs yq (mikefarah) and shellcheck, both preinstalled on ubuntu-latest.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
status=0

fail() {
  echo "::error file=$1::$2"
  status=1
}

shopt -s nullglob
files=("${root}"/*/action.yml)
if [ "${#files[@]}" -eq 0 ]; then
  echo "::error::no action.yml files found"
  exit 1
fi

for file in "${files[@]}"; do
  rel="${file#"${root}"/}"
  action="${rel%/action.yml}"
  echo "Linting ${rel}"

  for key in name description; do
    [ -n "$(yq ".${key} // \"\"" "${file}")" ] || fail "${rel}" "missing '${key}'"
  done
  [ "$(yq '.runs.using' "${file}")" = "composite" ] || fail "${rel}" "runs.using must be 'composite'"
  [ -f "${root}/${action}/README.md" ] || fail "${rel}" "missing ${action}/README.md"

  steps="$(yq '.runs.steps | length' "${file}")"
  [ "${steps}" -gt 0 ] || fail "${rel}" "runs.steps is empty"

  for ((i = 0; i < steps; i++)); do
    run="$(yq ".runs.steps[${i}].run // \"\"" "${file}")"
    [ -z "${run}" ] && continue
    [ -n "$(yq ".runs.steps[${i}].shell // \"\"" "${file}")" ] || fail "${rel}" "step ${i} has 'run' but no 'shell'"
    # shellcheck disable=SC2016 # literal ${{ is intended
    if printf '%s' "${run}" | grep -q '\${{'; then
      fail "${rel}" "step ${i} uses \${{ }} inside 'run'; pass values through 'env' instead"
    fi
    script="${tmp}/${action}-${i}.sh"
    printf '#!/usr/bin/env bash\n%s\n' "${run}" > "${script}"
    shellcheck --severity=warning "${script}" || fail "${rel}" "shellcheck found problems in step ${i}"
  done
done

exit "${status}"
