#!/usr/bin/env bash
# Runs the heartbeat step script against a stub curl: success goes to /ping,
# failure to /fail, the message reaches the API as valid JSON, the token
# never appears in the log, and an unknown state sends nothing.
# Needs yq (mikefarah) and jq, both preinstalled on ubuntu-latest.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

yq '.runs.steps[] | select(.id == "ping") | .run' "${root}/heartbeat/action.yml" > "${tmp}/step.sh"
[ -s "${tmp}/step.sh" ] || { echo "::error::could not extract the heartbeat step"; exit 1; }

mkdir -p "${tmp}/bin"
cat > "${tmp}/bin/curl" <<'STUB'
#!/usr/bin/env bash
# Records the URL (last argument) and the --data payload; answers 202.
data=""
while [ "$#" -gt 1 ]; do
  if [ "$1" = "--data" ]; then data="$2"; shift; fi
  shift
done
printf '%s\n' "$1" > "${STUB_DIR}/url"
printf '%s' "${data}" > "${STUB_DIR}/data"
printf '202'
STUB
chmod +x "${tmp}/bin/curl"

failures=0
fail() { echo "FAIL $1: $2"; failures=$((failures + 1)); }

# run_case <name> <state> <message>; sets code, and leaves url/data/log in ${tmp}/<name>
run_case() {
  local name="$1" state="$2" message="$3"
  local dir="${tmp}/${name}"
  mkdir -p "${dir}"
  : > "${dir}/out"; : > "${dir}/summary"
  code=0
  env PATH="${tmp}/bin:${PATH}" STUB_DIR="${dir}" \
    GITHUB_OUTPUT="${dir}/out" GITHUB_STEP_SUMMARY="${dir}/summary" \
    UW_TOKEN="secret-token-123" UW_STATE="${state}" UW_MESSAGE="${message}" \
    UW_BASE_URL="https://uw.example.com/" \
    bash "${tmp}/step.sh" > "${dir}/log" 2>&1 || code=$?
}

run_case success success "deploy ok"
[ "${code}" = 0 ] || fail success "exit ${code}"
[ "$(cat "${tmp}/success/url")" = "https://uw.example.com/api/heartbeat/secret-token-123/ping" ] || fail success "url $(cat "${tmp}/success/url")"
[ "$(jq -r .message "${tmp}/success/data")" = "deploy ok" ] || fail success "payload $(cat "${tmp}/success/data")"
grep -q '^status=202$' "${tmp}/success/out" || fail success "status output missing"
if grep -q secret-token-123 "${tmp}/success/log"; then fail success "token printed in the log"; fi

tricky=$'pg_dump "main" failed\\n at C:\\backup\nline two'
run_case failure failure "${tricky}"
[ "${code}" = 0 ] || fail failure "exit ${code}"
[ "$(cat "${tmp}/failure/url")" = "https://uw.example.com/api/heartbeat/secret-token-123/fail" ] || fail failure "url $(cat "${tmp}/failure/url")"
want=$'pg_dump "main" failed\\n at C:\\backup line two'
got="$(jq -r .message "${tmp}/failure/data")" || fail failure "payload is not valid JSON: $(cat "${tmp}/failure/data")"
[ "${got}" = "${want}" ] || fail failure "message: got [${got}] want [${want}]"
if grep -q secret-token-123 "${tmp}/failure/log"; then fail failure "token printed in the log"; fi

run_case bad degraded ""
[ "${code}" = 1 ] || fail bad "exit ${code}, want 1"
[ ! -e "${tmp}/bad/url" ] || fail bad "curl was called"

if [ "${failures}" -gt 0 ]; then
  echo "::error::${failures} heartbeat check(s) failed"
  exit 1
fi
echo "all heartbeat cases passed"
