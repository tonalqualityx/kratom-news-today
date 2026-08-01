#!/usr/bin/env bash
# Reproducible execution-verification for the deploy-watch / retry / liveness /
# send-gate logic in daily-publish.sh (Citadel task 1048b593). Proves each guard
# actually BITES, in both directions, without ever touching the real prod deploy
# or the live Klaviyo subscriber list.
#
#   Run:  bash scripts/test-deploy-guards.sh
#
# It derives its live slug + a real successful run id at runtime, so it keeps
# working as content ages. Stub sequencing is file-backed because the wrapper
# invokes its helpers via $(...) subshells (the production helpers only echo,
# so they are correct — the files are purely a test-harness concern).
set -uo pipefail
REPO_DIR="/home/mike/Documents/kratom-news-today"
cd "$REPO_DIR"   # gh resolves the repo from cwd

KNT_LIB_ONLY=1 source "$REPO_DIR/scripts/daily-publish.sh"
set +e
log() { echo "    [wrapper] $*"; }

PASS=0; FAIL=0
ok()  { echo "PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# --- Derive live fixtures ---
LIVE_SLUG=$(ls -t content/briefings/*.md 2>/dev/null | head -1 \
  | xargs -r -I{} python3 -c "import re,sys;c=open(sys.argv[1]).read();m=re.search(r'^slug:\s*\"?(.+?)\"?\s*\$',c,re.M);print(m.group(1) if m else '')" {} )
GOOD_RUN=$(gh run list --workflow "Build and Deploy" --branch main --status success \
  --json databaseId -L 1 -q '.[0].databaseId' 2>/dev/null)

echo "== Test 1: check_liveness against the REAL live site (read-only) =="
if [ -n "$LIVE_SLUG" ]; then
  check_liveness "$LIVE_SLUG" >/dev/null 2>&1 \
    && ok "known-live slug '$LIVE_SLUG' passes liveness" || bad "known-live slug should pass liveness"
else
  bad "could not derive a live slug from content/briefings/"
fi
check_liveness "this-slug-does-not-exist-zzz-000" >/dev/null 2>&1 \
  && bad "nonexistent slug should FAIL liveness" || ok "nonexistent slug fails liveness (guard bites)"

echo "== Test 2: wait_for_deploy_and_verify control flow (fault-injected) =="
SEQ_CONCL=$(mktemp); SEQ_LIVE=$(mktemp); RETRY_CT=$(mktemp)
_find_deploy_run() { echo "TESTRUN"; }
_rerun_deploy()    { echo $(( $(cat "$RETRY_CT") + 1 )) > "$RETRY_CT"; echo "TESTRUN"; }
_watch_deploy_run(){ local c; c=$(head -1 "$SEQ_CONCL"); sed -i '1d' "$SEQ_CONCL"; echo "${c:-failure}"; }
check_liveness()   { local v; v=$(head -1 "$SEQ_LIVE"); sed -i '1d' "$SEQ_LIVE"; return "${v:-0}"; }
run_case() { printf '%s\n' $1 > "$SEQ_CONCL"; printf '%s\n' $2 > "$SEQ_LIVE"; echo 0 > "$RETRY_CT"
  wait_for_deploy_and_verify "deadbeef" "slugA" >/dev/null 2>&1; echo "$?|$(cat "$RETRY_CT")"; }

res=$(run_case "failure success" "0 0")
[ "$res" = "0|1" ] && ok "fail->success recovers with one retry ($res)" || bad "fail->success expected 0|1 got $res"
res=$(run_case "failure failure" "0 0")
[ "${res%%|*}" = "1" ] && ok "fail->fail escalates rc1 ($res)" || bad "fail->fail expected rc1 got $res"
res=$(run_case "success success" "1 0")
[ "$res" = "0|1" ] && ok "green-but-not-live then live recovers ($res)" || bad "green-not-live->live expected 0|1 got $res"
res=$(run_case "success success" "1 1")
[ "${res%%|*}" = "1" ] && ok "green-but-not-live twice escalates rc1 ($res)" || bad "green-not-live x2 expected rc1 got $res"
rm -f "$SEQ_CONCL" "$SEQ_LIVE" "$RETRY_CT"

echo "== Test 3: REAL gh integration, read-only success path =="
if [ -n "$GOOD_RUN" ]; then
  ( KNT_LIB_ONLY=1 source "$REPO_DIR/scripts/daily-publish.sh"; log() { :; }
    concl=$(_watch_deploy_run "$GOOD_RUN")
    [ "$concl" = "success" ] && echo "PASS: real run $GOOD_RUN concludes 'success'" \
                             || echo "FAIL: real run watch got '$concl'" )
else
  echo "SKIP: no successful run found to probe (non-fatal)"
fi

echo "== Test 4: KNT_DRY_RUN suppresses the live Klaviyo send =="
out=$(KNT_DRY_RUN=1 send_klaviyo_campaign '[{"title":"t","summary":"s","url":"u"}]' 2>&1)
echo "$out" | grep -qi "DRY RUN" && ok "dry-run guard suppresses send" || bad "dry-run guard did not suppress: $out"

echo
echo "==== RESULT: $PASS passed, $FAIL failed ===="
[ "$FAIL" -eq 0 ]
