# Plan: watch deploy, retry once, verify liveness, gate email on liveness

Citadel task `1048b593` (Mike-authored, 2026-08-01). Fixes the 08-01 incident where
the Klaviyo send fired on a briefing that never deployed (rsync failed after the
wrapper had already declared success), leaving subscribers with an 18-min 404.

## Scope — one file
`scripts/daily-publish.sh` only. The deploy workflow's Varnish purge step already
works (verified 08-01) — leave `.github/workflows/deploy.yml` untouched.

## Four behaviors (per the task spec)
1. **Watch the deploy.** After the push, find the "Build and Deploy" Actions run for
   the pushed SHA and wait for it to reach a terminal state — the wrapper no longer
   exits the moment the push lands.
2. **Retry once on failure.** Deploy failed (or deployed green but page not live) →
   re-run once and watch again. Escalate only if the retry also fails. Log every attempt.
3. **Post-deploy liveness check.** Fetch each published briefing URL (cache-buster) and
   assert HTTP 200, and assert the slug appears in `sitemap.xml`. A green Action is not
   proof the page is reachable.
4. **Gate the email on liveness, not on the push.** Sequence: push → watch deploy →
   retry on failure → verify live → THEN send Klaviyo. If liveness can't be confirmed
   after the retry: do NOT send, alert loudly.

## Testability guards added
- `KNT_DRY_RUN=1` — hard-stub the Klaviyo send (task: "Stub or guard it"; the list is live).
- `KNT_LIB_ONLY=1` — source the script for its functions/config without running `main`,
  so the deploy-watch/liveness functions can be driven in isolation.

## Verification (by execution, both directions)
- Liveness bites: real read-only fetch of a known-live slug → pass; a nonexistent slug → fail.
- Deploy watch/retry bites: fault-inject scripted run conclusions (fail→success recovers;
  fail→fail escalates) without touching the real prod deploy.
- `bash -n` + `shellcheck` clean.

## Ship
KNT auto-deploys on push to main. Pushing this script change rebuilds identical site
content (idempotent) and the new logic only activates at the next 8am cron. Reversible
via a single-commit revert.
