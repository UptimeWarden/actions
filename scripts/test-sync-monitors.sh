#!/usr/bin/env bash
# Runs the sync-monitors step script against a stub `uw` and checks its
# outputs and exit code. Guards the has-drift output: it used to match the
# plan's header lines ("  + create  0") and was always true.
# Needs yq (mikefarah), preinstalled on ubuntu-latest.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

yq '.runs.steps[] | select(.id == "apply") | .run' "${root}/sync-monitors/action.yml" > "${tmp}/step.sh"
[ -s "${tmp}/step.sh" ] || { echo "::error::could not extract the sync-monitors step"; exit 1; }

# Stub CLI. STUB_PLAN_CODE is the exit code of the --diff-only run,
# STUB_APPLY_CODE of the --yes run. Every call is logged.
mkdir -p "${tmp}/bin"
cat > "${tmp}/bin/uw" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "${STUB_LOG}"
case " $* " in
  *" --diff-only "*)
    echo "Plan:"
    echo "  + create  ${STUB_CREATE:-0}"
    echo "  ~ update  0"
    echo "  ± replace 0"
    echo "  - delete  0"
    exit "${STUB_PLAN_CODE:-0}"
    ;;
  *" --yes "*)
    i=0
    while [ "${i}" -lt "${STUB_CREATE:-0}" ]; do echo "    ✓ created"; i=$((i + 1)); done
    exit "${STUB_APPLY_CODE:-0}"
    ;;
esac
exit 99
STUB
chmod +x "${tmp}/bin/uw"
echo '{"monitors":[]}' > "${tmp}/monitors.uw.json"

failures=0
# run_case <name> <mode> <plan code> <apply code> <creates> <want exit> <want has-drift> <want created> <want --yes calls>
run_case() {
  local name="$1" mode="$2" plan_code="$3" apply_code="$4" creates="$5"
  local want_exit="$6" want_drift="$7" want_created="$8" want_yes="$9"
  local out="${tmp}/${name}.out" summary="${tmp}/${name}.summary" log="${tmp}/${name}.log"
  : > "${out}"; : > "${summary}"; : > "${log}"

  local code=0
  env PATH="${tmp}/bin:${PATH}" \
    GITHUB_OUTPUT="${out}" GITHUB_STEP_SUMMARY="${summary}" STUB_LOG="${log}" \
    STUB_PLAN_CODE="${plan_code}" STUB_APPLY_CODE="${apply_code}" STUB_CREATE="${creates}" \
    UW_API_TOKEN="uptw_test" UW_API_URL="https://uw.example.com" UW_MODE="${mode}" \
    UW_ALLOW_DELETE="false" UW_CONFIG_FILE="${tmp}/monitors.uw.json" \
    bash "${tmp}/step.sh" > "${tmp}/${name}.stdout" 2>&1 || code=$?

  local got_drift got_created got_yes
  got_drift="$(sed -n 's/^has-drift=//p' "${out}")"
  got_created="$(sed -n 's/^created=//p' "${out}")"
  got_yes="$(grep -c -- '--yes' "${log}" || true)"

  local ok=1
  [ "${code}" = "${want_exit}" ] || { echo "  exit: want ${want_exit}, got ${code}"; ok=0; }
  [ "${got_drift}" = "${want_drift}" ] || { echo "  has-drift: want '${want_drift}', got '${got_drift}'"; ok=0; }
  if [ -n "${want_created}" ]; then
    [ "${got_created}" = "${want_created}" ] || { echo "  created: want '${want_created}', got '${got_created}'"; ok=0; }
  fi
  [ "${got_yes}" = "${want_yes}" ] || { echo "  --yes calls: want ${want_yes}, got ${got_yes}"; ok=0; }

  if [ "${ok}" = 1 ]; then
    echo "ok   ${name}"
  else
    echo "FAIL ${name}"
    sed 's/^/  | /' "${tmp}/${name}.stdout"
    failures=$((failures + 1))
  fi
}

#        name                   mode  plan apply creates exit drift   created yes
run_case plan-no-drift          plan  0    0     0       0    false   0       0
run_case plan-drift             plan  2    0     1       0    true    0       0
run_case diff-no-drift          diff  0    0     0       0    false   0       0
run_case diff-drift             diff  2    0     1       2    true    0       0
run_case apply-no-drift         apply 0    0     0       0    false   0       0
run_case apply-drift            apply 2    0     2       0    true    2       1
run_case apply-blocked          apply 2    1     0       1    true    0       1
run_case plan-error             plan  1    0     0       1    unknown ""      0

if [ "${failures}" -gt 0 ]; then
  echo "::error::${failures} sync-monitors case(s) failed"
  exit 1
fi
echo "all sync-monitors cases passed"
