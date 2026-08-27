#!/usr/bin/env bash
# KNT Daily Publish — runs Herald, publishes the briefing, notifies Slack
# Called by system cron at 8am ET daily
set -euo pipefail

# --- Config ---
REPO_DIR="/home/mike/Documents/kratom-news-today"
LOG_DIR="/home/mike/.local/log"
LOG_FILE="$LOG_DIR/knt-herald-$(date +%Y-%m-%d).log"
SLACK_CHANNEL="C0AEBQ36W05"  # #bast-chat
SITE_URL="https://kratomnewstoday.com"
# Research wall-clock. Raised 1200 -> 2400 on 2026-08-27. The old 1200 was set in
# June when research ran 550-670s; by late August it ran 680-1170s (denoise cap had
# been raised 80 -> 250, so far more queries land), leaving almost no headroom.
# It blew the wall on 08-19 and 08-27, and came within 34s on 08-20 and 64s on 08-22.
RESEARCH_TIMEOUT=2400
RESEARCH_ATTEMPTS=2    # research retries too now; a single slow-API morning used to kill the day.
RESEARCH_RETRY_DELAY=60
PUBLISH_TIMEOUT=1800   # hard wall-clock cap for the claude SYNTHESIS+publish step (30 min).
MAX_ATTEMPTS=2         # synthesis attempts if no briefing lands.
HERALD_DIR="/home/mike/.claude/skills/herald"

# --- Deploy-watch / liveness config ---
# The GitHub Action "Build and Deploy" is a SEPARATE system that can fail AFTER
# the push lands (08-01: rsync exit 1 after the wrapper had declared success, so
# subscribers held an email to a 404 for ~18 min). The wrapper now waits for that
# deploy, retries once on failure, and proves the page is actually live before it
# lets the newsletter go out.
DEPLOY_WORKFLOW="Build and Deploy"     # workflow name in .github/workflows/deploy.yml
DEPLOY_FIND_TIMEOUT=180                 # secs to wait for the run to appear after a push
DEPLOY_WATCH_TIMEOUT=1200              # hard cap (secs) on watching one run to a terminal state
DEPLOY_MAX_ATTEMPTS=2                  # 1 initial + 1 retry, per Mike's "retry at least once" rule
SITEMAP_URL="$SITE_URL/sitemap.xml"    # liveness asserts each slug appears here

# Testability guards (see agent-docs/deploy-liveness-gate-plan.md):
#   KNT_DRY_RUN=1   -> hard-stub the Klaviyo send (the list is LIVE subscribers)
#   KNT_LIB_ONLY=1  -> source this file for its functions/config without running main
KNT_DRY_RUN="${KNT_DRY_RUN:-}"

mkdir -p "$LOG_DIR"

# Read Slack bot token from Openclaw config at runtime
SLACK_BOT_TOKEN=$(python3 -c "import json; print(json.load(open('/home/mike/.openclaw/openclaw.json'))['channels']['slack']['botToken'])" 2>/dev/null)

# Read Klaviyo config
KLAVIYO_CONFIG="/home/mike/.config/knt/klaviyo.json"
KLAVIYO_API_KEY=$(python3 -c "import json; print(json.load(open('$KLAVIYO_CONFIG'))['privateApiKey'])" 2>/dev/null)
KLAVIYO_LIST_ID=$(python3 -c "import json; print(json.load(open('$KLAVIYO_CONFIG'))['listId'])" 2>/dev/null)
KLAVIYO_TEMPLATE_ID=$(python3 -c "import json; print(json.load(open('$KLAVIYO_CONFIG'))['templateId'])" 2>/dev/null)

# Daily campaign de-dupe: one email per day, no matter how many briefings land.
KNT_STATE_DIR="/home/mike/.config/knt"
CAMPAIGN_STATE_FILE="$KNT_STATE_DIR/last_campaign_date.txt"

# --- Helpers ---
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

slack_notify() {
  local msg="$1"
  if [ -n "$SLACK_BOT_TOKEN" ]; then
    curl -s -X POST "https://slack.com/api/chat.postMessage" \
      -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"channel\":\"$SLACK_CHANNEL\",\"text\":$(python3 -c "import json; print(json.dumps('$msg'))")}" \
      > /dev/null 2>&1 || log "WARN: Slack notification failed"
  fi
}

slack_notify_json() {
  local json_payload="$1"
  if [ -n "$SLACK_BOT_TOKEN" ]; then
    curl -s -X POST "https://slack.com/api/chat.postMessage" \
      -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$json_payload" \
      > /dev/null 2>&1 || log "WARN: Slack notification failed"
  fi
}

# Send ONE Klaviyo campaign containing every briefing published today.
# Arg 1 is a JSON array: [{"title": "...", "summary": "...", "url": "..."}, ...]
# The base template carries a single article block ({{ event.title|summary|url }});
# we duplicate that block once per article so all briefings ride in one email.
send_klaviyo_campaign() {
  local articles_json="$1"

  local count
  count=$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])))" "$articles_json" 2>/dev/null || echo 0)
  if [ "$count" -eq 0 ]; then
    log "No articles to email, skipping Klaviyo campaign."
    return
  fi

  # Hard test guard: never touch the live subscriber list during a dry run.
  if [ -n "$KNT_DRY_RUN" ]; then
    log "DRY RUN (KNT_DRY_RUN set): would send Klaviyo campaign with $count article(s) — send SUPPRESSED."
    return
  fi

  if [ -z "$KLAVIYO_API_KEY" ]; then
    log "WARN: Klaviyo API key not configured, skipping email campaign"
    return
  fi

  # Duplicate prevention: only one campaign per calendar day.
  local today
  today=$(date +%Y-%m-%d)
  if [ -f "$CAMPAIGN_STATE_FILE" ] && [ "$(cat "$CAMPAIGN_STATE_FILE" 2>/dev/null)" = "$today" ]; then
    log "Klaviyo campaign already sent today ($today) — skipping to avoid a duplicate email."
    return
  fi

  log "Preparing Klaviyo campaign with $count article(s)..."

  # Single Python script handles entire Klaviyo flow:
  # 1. Read base template (block-based, read-only)
  # 2. Duplicate the article block once per article and fill placeholders
  # 3. Create temp code-based template with populated HTML
  # 4. Create and send campaign using temp template
  # 5. Delete temp template
  CAMPAIGN_RESULT=$(python3 - "$KLAVIYO_API_KEY" "$KLAVIYO_TEMPLATE_ID" "$KLAVIYO_LIST_ID" "$articles_json" << 'PYEOF'
import json, urllib.request, sys, datetime, re

api_key, base_template_id, list_id = sys.argv[1], sys.argv[2], sys.argv[3]
articles = json.loads(sys.argv[4])
today = datetime.date.today().isoformat()

n = len(articles)
first_title = (articles[0].get("title") or "Kratom News Today") if articles else "Kratom News Today"
subject = first_title if n == 1 else f"{first_title} (+{n - 1} more)"
campaign_title = subject[:80]

headers = {
    "Authorization": f"Klaviyo-API-Key {api_key}",
    "Content-Type": "application/json",
    "revision": "2024-02-15"
}

def api_call(method, endpoint, data=None):
    payload = json.dumps(data).encode() if data else None
    req = urllib.request.Request(
        f"https://a.klaviyo.com/api/{endpoint}",
        data=payload, headers=headers, method=method
    )
    resp = urllib.request.urlopen(req)
    return json.loads(resp.read()) if resp.status != 204 else None

temp_id = None
try:
    # 1. Read base template HTML
    tmpl = api_call("GET", f"templates/{base_template_id}")
    html = tmpl["data"]["attributes"]["html"]

    # 2. Locate the single article block (the {{ event.* }} row) and duplicate it
    #    once per article. Whitespace is tolerated inside the placeholders because
    #    the block editor inserts line breaks. lambda replacements avoid treating
    #    article text (e.g. a stray "\1") as a regex backreference.
    block_re = re.compile(r'<tr><td style="color:#222222.*?</a></td></tr>', re.DOTALL)
    m = block_re.search(html)
    if not m:
        print("ERROR: article block not found in template", file=sys.stderr)
        print("FAIL")
        sys.exit(0)
    block = m.group(0)

    def render(article):
        h = block
        h = re.sub(r'\{\{\s*event\.title\s*\}\}', lambda _: article.get("title", ""), h)
        h = re.sub(r'\{\{\s*event\.summary\s*\}\}', lambda _: article.get("summary", ""), h)
        h = re.sub(r'\{\{\s*event\.url\s*\}\}', lambda _: article.get("url", ""), h)
        return h

    separator = ('<tr><td style="padding:16px 0;">'
                 '<hr style="border:none;border-top:1px solid #e0e0e0;margin:0;"></td></tr>')
    combined = separator.join(render(a) for a in articles)
    html = html[:m.start()] + combined + html[m.end():]

    # 3. Create temp code template
    temp_tmpl = api_call("POST", "templates/", {
        "data": {
            "type": "template",
            "attributes": {
                "name": f"KNT Briefing {today} (auto)",
                "editor_type": "CODE",
                "html": html
            }
        }
    })
    temp_id = temp_tmpl["data"]["id"]
    print(f"Temp template: {temp_id}", file=sys.stderr)

    # 4. Create campaign
    campaign = api_call("POST", "campaigns/", {
        "data": {
            "type": "campaign",
            "attributes": {
                "name": f"Daily Briefing: {campaign_title}",
                "audiences": {
                    "included": [list_id]
                },
                "campaign-messages": {
                    "data": [{
                        "type": "campaign-message",
                        "attributes": {
                            "channel": "email",
                            "label": "Daily Briefing",
                            "content": {
                                "subject": subject,
                                "from_email": "briefing@kratomnewstoday.com",
                                "from_label": "Kratom News Today"
                            }
                        }
                    }]
                },
                "send_options": {
                    "use_smart_sending": False
                },
                "send_strategy": {
                    "method": "immediate"
                }
            }
        }
    })
    campaign_id = campaign["data"]["id"]
    msg_id = campaign["data"]["relationships"]["campaign-messages"]["data"][0]["id"]
    print(f"Campaign: {campaign_id}, Message: {msg_id}", file=sys.stderr)

    # 5. Assign template to campaign message
    api_call("POST", "campaign-message-assign-template/", {
        "data": {
            "type": "campaign-message",
            "id": msg_id,
            "relationships": {
                "template": {
                    "data": {"type": "template", "id": temp_id}
                }
            }
        }
    })
    print("Template assigned", file=sys.stderr)

    # 6. Send campaign
    api_call("POST", "campaign-send-jobs/", {
        "data": {
            "type": "campaign-send-job",
            "id": campaign_id
        }
    })

    # 7. Delete temp template
    try:
        req = urllib.request.Request(
            f"https://a.klaviyo.com/api/templates/{temp_id}",
            headers=headers, method="DELETE"
        )
        urllib.request.urlopen(req)
    except Exception:
        pass

    print("OK")

except urllib.error.HTTPError as e:
    print(f"ERROR: {e.code} {e.read().decode()}", file=sys.stderr)
    # Clean up temp template if created
    if temp_id:
        try:
            req = urllib.request.Request(
                f"https://a.klaviyo.com/api/templates/{temp_id}",
                headers=headers, method="DELETE"
            )
            urllib.request.urlopen(req)
        except Exception:
            pass
    print("FAIL")
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    print("FAIL")
PYEOF
  )

  if [ "$CAMPAIGN_RESULT" = "OK" ]; then
    log "Klaviyo campaign sent successfully ($count article(s))."
    # Mark today as sent so a re-run (e.g. retry/cron overlap) won't duplicate it.
    mkdir -p "$KNT_STATE_DIR"
    echo "$today" > "$CAMPAIGN_STATE_FILE"
  else
    log "WARN: Klaviyo campaign failed. Check log for details."
  fi
}

# Send a Slack notification for a single published briefing slug.
# Reads title / beat straight from the committed file — does NOT depend
# on Claude's JSON output, so it works even when the publish step was killed.
# (Email is handled separately: one Klaviyo campaign for all of today's briefings.)
notify_for_slug() {
  local slug="$1"
  local file
  file=$(ls "$REPO_DIR/content/briefings/"*"$slug"*.md 2>/dev/null | head -1)
  if [ -z "$file" ]; then
    log "WARN: could not find briefing file for slug '$slug', skipping notify"
    return 1
  fi

  local meta
  meta=$(python3 - "$file" << 'PYEOF'
import sys, re, json
content = open(sys.argv[1]).read()
def fm(key):
    m = re.search(r'^%s:\s*"?(.+?)"?\s*$' % key, content, re.MULTILINE)
    return m.group(1).strip() if m else ''
title = fm('title')
beat = ''
m = re.search(r'^tags:\s*\n((?:\s*-\s*.+\n?)+)', content, re.MULTILINE)
if m:
    t = re.search(r'-\s*(.+)', m.group(1))
    beat = t.group(1).strip() if t else ''
print(json.dumps({'title': title, 'beat': beat}))
PYEOF
)
  local title beat url
  title=$(echo "$meta" | python3 -c "import json,sys; print(json.load(sys.stdin)['title'])" 2>/dev/null)
  beat=$(echo "$meta" | python3 -c "import json,sys; print(json.load(sys.stdin)['beat'])" 2>/dev/null)
  url="$SITE_URL/briefings/$slug/"

  log "Notifying for: $title"

  # Advisory rules-check warning (Sources section, rules.md:37), if one was
  # recorded for this slug earlier in the run. Appended to the SAME "published"
  # message rather than a separate alert -- loud, but never a second interruption
  # and never a reason to withhold the notification.
  local rules_warning="${RULES_WARNINGS[$slug]:-}"

  local payload
  payload=$(python3 -c "
import json, sys
title, beat, url, chan, warning = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
beat_tag = f' [{beat}]' if beat else ''
lines = ['📰 *KNT Daily Briefing Published*', '', f'<{url}|{title}>{beat_tag}', '', '1 briefing(s) live.']
if warning:
    lines += ['', f'⚠️ *Rules-check warning (advisory, not blocking):* {warning}']
msg = '\n'.join(lines)
print(json.dumps({'channel': chan, 'text': msg, 'unfurl_links': False}))
" "$title" "$beat" "$url" "$SLACK_CHANNEL" "$rules_warning" 2>/dev/null)
  slack_notify_json "$payload"
}

# Extract one briefing's email fields (title, summary, url) as a JSON object.
# Sourced from the committed file — the `summary` frontmatter is the TL;DR and
# single source of truth (also used for the on-page callout, SEO meta,
# schema.org, OG image, and homepage cards). Prints {} and returns 1 if the
# file can't be found, so the caller can skip it.
extract_article_data() {
  local slug="$1"
  local file
  file=$(ls "$REPO_DIR/content/briefings/"*"$slug"*.md 2>/dev/null | head -1)
  if [ -z "$file" ]; then
    log "WARN: could not find briefing file for slug '$slug', skipping email entry"
    echo "{}"
    return 1
  fi

  python3 - "$file" "$SITE_URL/briefings/$slug/" << 'PYEOF'
import sys, re, json
content = open(sys.argv[1]).read()
url = sys.argv[2]
def fm(key):
    m = re.search(r'^%s:\s*"?(.+?)"?\s*$' % key, content, re.MULTILINE)
    return m.group(1).strip() if m else ''
print(json.dumps({'title': fm('title'), 'summary': fm('summary'), 'url': url}))
PYEOF
}

# --- Advisory rules-check: mandatory Sources (rules.md:37) -------------------
# rules.md Required Framing 5 (as of 2026-08-15, corrected to match the
# governing-record precedent): sources are mandatory and live in the `sources`
# frontmatter array -- kratomnewstoday.com's site template
# (_includes/components/sources.njk, per agent-docs/components.md) renders the
# Sources section on the page automatically from that array. A body-level
# `## Sources` heading must NOT be added; the template already renders one,
# and a body-level section would render twice.
#
# History: this rule used to read "always end briefings with a body-level
# Sources section," and Herald's real rules-check agent flagged nearly every
# recent briefing as a hard violation for lacking one (see
# ~/.claude/skills/herald/logs/*.log) -- but the site was never actually
# missing sources; the rule was simply written wrong for this template. Fixed
# 2026-08-15 by correcting rules.md to the frontmatter-only pattern instead of
# forcing synthesis to add a body section (which would have started
# double-rendering Sources on every future briefing). This check was updated
# to match -- see git log for the prior (now-obsolete) version that checked
# for a body heading instead of flagging one.
#
# ADVISORY ONLY, by design (Mike explicitly deferred fail-closed for this
# rule): a failing check here NEVER blocks the commit/push/deploy/email that
# already happened earlier in the run -- it only adds a visible warning to the
# log and to the per-briefing Slack notification, same as any other post-hoc
# audit.
#
# Checks, in order:
#   1. The `sources` frontmatter array exists and is non-empty (the actual
#      mandatory-sources requirement).
#   2. Every entry in it has title/url/publisher (matches rules.md:37's
#      "publisher, date, and URL" and validate.js's existing field checks).
#   3. The body does NOT contain a `## Sources` heading (double-render risk --
#      the template already renders one from frontmatter).
#
# Prints "pass" or "violation: <reason>" on stdout.
#
# IMPORTANT: this always exits 0. Pass/fail is encoded ONLY in the printed
# string ("pass" vs "violation: ..."), never in the process exit code. The
# caller assigns the output via `sources_check=$(check_body_sources_section
# ...)`, and this whole script runs under `set -euo pipefail` -- a non-zero
# exit from a bare command substitution assignment (`var=$(cmd)`) trips
# errexit and would silently kill the entire publish run the moment a
# violation was found, which is exactly the opposite of "advisory, never
# blocking." Keep this exiting 0 unconditionally.
check_body_sources_section() {
  local file="$1"
  python3 - "$file" << 'PYEOF'
import re, sys
import yaml

raw = open(sys.argv[1]).read()
m = re.match(r'^---\n(.*?)\n---\n(.*)$', raw, re.DOTALL)
if not m:
    print("violation: could not find YAML frontmatter delimiters ('---') to check sources")
    sys.exit(0)
fm_text, body = m.group(1), m.group(2)

try:
    fm = yaml.safe_load(fm_text) or {}
except yaml.YAMLError as exc:
    print(f"violation: frontmatter did not parse as YAML ({exc})")
    sys.exit(0)

sources = fm.get('sources')
if not sources or not isinstance(sources, list) or len(sources) == 0:
    print("violation: 'sources' frontmatter array is missing or empty -- sources are "
          "mandatory (rules.md:37)")
    sys.exit(0)

incomplete = [
    i + 1 for i, s in enumerate(sources)
    if not (isinstance(s, dict) and s.get('title') and s.get('url') and s.get('publisher'))
]
if incomplete:
    print(f"violation: 'sources' frontmatter entries missing title/url/publisher "
          f"(entry index {incomplete}, rules.md:37)")
    sys.exit(0)

if re.search(r'^##\s+Sources\s*$', body, re.MULTILINE):
    print("violation: body contains a '## Sources' heading -- the site template already "
          "renders Sources from frontmatter (sources.njk); this will double-render on the "
          "live page (rules.md:37)")
    sys.exit(0)

print("pass")
PYEOF
}

# --- Deploy watch + liveness gate ---------------------------------------------
# These are the four behaviors from Citadel task 1048b593. They are defined as
# small, overridable functions so the control flow can be fault-injected in a
# test harness (redefine _watch_deploy_run / _find_deploy_run / _rerun_deploy)
# without ever touching the real prod deploy. See agent-docs/deploy-liveness-gate-plan.md.

# Find the "Build and Deploy" run id for a given commit SHA. The push usually
# starts the run within a few seconds, but there is a lag, so poll until it
# appears or DEPLOY_FIND_TIMEOUT elapses. Echoes the run id (empty if none).
_find_deploy_run() {
  local sha="$1" deadline id
  deadline=$(( $(date +%s) + DEPLOY_FIND_TIMEOUT ))
  while [ "$(date +%s)" -le "$deadline" ]; do
    id=$(gh run list --workflow "$DEPLOY_WORKFLOW" --branch main \
           --json databaseId,headSha -L 20 2>/dev/null \
         | python3 -c "import json,sys; sha=sys.argv[1]; runs=json.load(sys.stdin); print(next((str(r['databaseId']) for r in runs if r.get('headSha')==sha), ''))" "$sha" 2>/dev/null)
    if [ -n "$id" ]; then echo "$id"; return 0; fi
    sleep 8
  done
  echo ""
  return 1
}

# Watch a run to a terminal state and echo its conclusion (success/failure/...).
# Wrapped in `timeout` so a stuck run can never block the wrapper forever.
_watch_deploy_run() {
  local id="$1"
  timeout -k 15 "$DEPLOY_WATCH_TIMEOUT" gh run watch "$id" --exit-status >/dev/null 2>&1 || true
  gh run view "$id" --json conclusion -q '.conclusion' 2>/dev/null || echo "unknown"
}

# Re-run the deploy after a failure. If the run has failed jobs, re-run just those
# (same run id, new attempt). If it had none (e.g. green-but-not-live), dispatch a
# fresh deploy and return the new run id. Echoes the run id to watch next.
_rerun_deploy() {
  local id="$1" sha="$2" newid
  if gh run rerun "$id" --failed >/dev/null 2>&1; then
    echo "$id"; return 0
  fi
  # No failed jobs to re-run — trigger a fresh deploy via workflow_dispatch.
  if gh workflow run "$DEPLOY_WORKFLOW" --ref main >/dev/null 2>&1; then
    sleep 8
    newid=$(_find_deploy_run "$sha")
    # A dispatched run has no push SHA match; fall back to the newest run on main.
    [ -z "$newid" ] && newid=$(gh run list --workflow "$DEPLOY_WORKFLOW" --branch main \
        --json databaseId -L 1 -q '.[0].databaseId' 2>/dev/null)
    echo "$newid"; return 0
  fi
  echo "$id"; return 1
}

# Liveness: every published slug must return HTTP 200 (cache-buster) AND appear in
# sitemap.xml. A green Action is not proof the page is reachable — only fetching it
# is. Returns 0 only if ALL slugs are live. Args: the slugs.
check_liveness() {
  local slug code ok=0 sitemap
  sitemap=$(curl -s --max-time 30 "$SITEMAP_URL?cb=$(date +%s)" 2>/dev/null || echo "")
  for slug in "$@"; do
    [ -z "$slug" ] && continue
    code=$(curl -s -o /dev/null --max-time 30 -w "%{http_code}" \
             "$SITE_URL/briefings/$slug/?cb=$(date +%s)" 2>/dev/null || echo "000")
    if [ "$code" != "200" ]; then
      log "LIVENESS FAIL: $SITE_URL/briefings/$slug/ returned HTTP $code (expected 200)."
      ok=1
    elif ! printf '%s' "$sitemap" | grep -q "$slug"; then
      log "LIVENESS FAIL: slug '$slug' not found in $SITEMAP_URL."
      ok=1
    else
      log "LIVENESS OK: /briefings/$slug/ is 200 and present in sitemap."
    fi
  done
  return "$ok"
}

# Orchestrate: watch the deploy for $sha, retry once on failure OR on green-but-
# not-live, and only return 0 once the deploy is terminal-success AND every slug
# is live. Every attempt is logged. Args: sha, then the slugs.
wait_for_deploy_and_verify() {
  local sha="$1"; shift
  local slugs=("$@")
  local attempt=1 run_id conclusion

  run_id=$(_find_deploy_run "$sha")
  if [ -z "$run_id" ]; then
    log "ERROR: no '$DEPLOY_WORKFLOW' run found for $sha within ${DEPLOY_FIND_TIMEOUT}s."
    return 1
  fi

  while [ "$attempt" -le "$DEPLOY_MAX_ATTEMPTS" ]; do
    log "Deploy attempt $attempt/$DEPLOY_MAX_ATTEMPTS: watching run $run_id ..."
    conclusion=$(_watch_deploy_run "$run_id")
    log "Deploy run $run_id concluded: $conclusion"

    if [ "$conclusion" = "success" ]; then
      if check_liveness "${slugs[@]}"; then
        log "Deploy succeeded and all briefing(s) are live."
        return 0
      fi
      log "Deploy was green but liveness failed — treating as a failure for retry purposes."
    fi

    if [ "$attempt" -lt "$DEPLOY_MAX_ATTEMPTS" ]; then
      log "Retrying deploy (attempt $((attempt + 1)) of $DEPLOY_MAX_ATTEMPTS)..."
      run_id=$(_rerun_deploy "$run_id" "$sha")
      if [ -z "$run_id" ]; then
        log "ERROR: could not start a retry deploy run."
        return 1
      fi
    fi
    attempt=$((attempt + 1))
  done

  log "ERROR: deploy did not reach a live state after $DEPLOY_MAX_ATTEMPTS attempt(s)."
  return 1
}

# Allow `KNT_LIB_ONLY=1 source scripts/daily-publish.sh` to load the functions and
# config above WITHOUT executing the pipeline below — used by the test harness.
if [ -n "${KNT_LIB_ONLY:-}" ]; then
  return 0 2>/dev/null || exit 0
fi

# --- Main ---
log "=== KNT Daily Publish starting ==="
cd "$REPO_DIR"

# Pull latest to avoid conflicts
log "Pulling latest from origin..."
git pull --ff-only origin main >> "$LOG_FILE" 2>&1 || {
  log "ERROR: git pull failed"
  slack_notify "⚠ KNT daily publish failed: git pull error. Check $LOG_FILE"
  exit 1
}

# Record where we started so we can detect what (if anything) got published,
# independent of whatever Claude prints to stdout.
START_HEAD=$(git rev-parse HEAD)

# --- Auth preflight (cheap, BEFORE the expensive research call) ---
# The synthesis/publish step shells out to `claude -p`, which fails fast with
# "Not logged in · Please run /login" (rc=1) when the CLI's OAuth token has
# expired overnight. That used to surface only AFTER the ~8-minute Perplexity
# research call, burning the spend for a run that could never publish. Probe auth
# with a tiny prompt up front and abort loudly if it's logged out — no tools, no
# permissions, ~1 cent, a few seconds. Probe on Haiku: auth is account-level so the
# model is irrelevant to the login check, and it keeps the probe genuinely cheap so
# the $0.10 budget guard doesn't trip on loaded-context input cost (a bare Opus
# probe now exceeds $0.10 just loading CLAUDE.md + skills, which is a false logout).
log "Checking Claude CLI auth..."
set +e
AUTH_OUT=$(timeout -k 10 60 claude -p --model claude-haiku-4-5-20251001 --max-budget-usd 0.10 "Reply with exactly: OK" 2>&1)
auth_rc=$?
set -e
if [ "$auth_rc" -ne 0 ] || echo "$AUTH_OUT" | grep -qiE "not logged in|please run /login"; then
  log "ERROR: Claude CLI not authenticated (rc=$auth_rc). Output: $AUTH_OUT"
  slack_notify "⚠ KNT daily publish ABORTED before research: Claude CLI is logged out, so the publish step can't run. Run \`/login\` in a Claude Code session on the host, then re-run scripts/daily-publish.sh. No research spend was used. Log: $LOG_FILE"
  exit 1
fi
log "Claude CLI auth OK."

# --- Research phase (deterministic Python, NOT the agent) ---
# Run Perplexity research + de-noise + context retrieval in the shell and save the
# findings to a file. Keeping this OUT of the agent is the whole point of this
# design: the agent used to background this ~10-minute call and end its turn
# before ever synthesizing. The shell just blocks on it normally.
RESEARCH_FILE=$(mktemp "/tmp/knt-research-$(date +%Y%m%d)-XXXXXX.json")
# Research gets RESEARCH_ATTEMPTS tries. It used to get exactly one, so a single
# slow-API morning killed the whole day's briefing with no second chance --
# that is what lost 2026-08-19 and 2026-08-27, both rc=124 at the wall.
research_rc=1
for attempt in $(seq 1 "$RESEARCH_ATTEMPTS"); do
  log "Running Herald research (Python/Perplexity, attempt ${attempt}/${RESEARCH_ATTEMPTS}, up to ${RESEARCH_TIMEOUT}s)..."
  set +e
  timeout -k 30 "$RESEARCH_TIMEOUT" "$HERALD_DIR/.venv/bin/python" "$HERALD_DIR/run_phase.py" \
    research --config-dir "$REPO_DIR" > "$RESEARCH_FILE" 2>>"$LOG_FILE"
  research_rc=$?
  set -e
  [ "$research_rc" -eq 0 ] && break
  if [ "$research_rc" -eq 124 ]; then
    log "WARNING: research attempt ${attempt} timed out at ${RESEARCH_TIMEOUT}s (rc=124)."
  else
    log "WARNING: research attempt ${attempt} failed (rc=${research_rc})."
  fi
  if [ "$attempt" -lt "$RESEARCH_ATTEMPTS" ]; then
    log "Retrying research after ${RESEARCH_RETRY_DELAY}s..."
    sleep "$RESEARCH_RETRY_DELAY"
  fi
done
if [ "$research_rc" -ne 0 ]; then
  log "ERROR: research phase failed (rc=$research_rc) or timed out after ${RESEARCH_ATTEMPTS} attempt(s)."
  slack_notify "⚠ KNT daily publish FAILED: research phase errored (rc=$research_rc) after ${RESEARCH_ATTEMPTS} attempts. Check $LOG_FILE"
  exit 1
fi
RSTATUS=$(python3 -c "import json; print(json.load(open('$RESEARCH_FILE')).get('status','?'))" 2>/dev/null || echo "?")
RMSG=$(python3 -c "import json; print(json.load(open('$RESEARCH_FILE')).get('message',''))" 2>/dev/null || echo "")
RTYPE=$(python3 -c "import json; print(json.load(open('$RESEARCH_FILE')).get('error_type',''))" 2>/dev/null || echo "")
NUM_FINDINGS=$(python3 -c "import json; d=json.load(open('$RESEARCH_FILE')); f=d.get('findings') or {}; print(len(f.get('findings',[])) if isinstance(f,dict) else 0)" 2>/dev/null || echo 0)
log "Research complete: status=$RSTATUS, $NUM_FINDINGS findings -> $RESEARCH_FILE"
if [ "$RSTATUS" != "success" ]; then
  log "ERROR: research returned status=$RSTATUS: ${RMSG:-no usable findings}"
  # Prefer the engine's specific, actionable message; fall back to the generic one.
  if [ "$RTYPE" = "perplexity_quota" ]; then
    slack_notify "⚠ KNT daily publish FAILED: Perplexity API is out of quota/credits — no briefing today. Top up the account at https://www.perplexity.ai/settings/api, then re-run scripts/daily-publish.sh. Log: $LOG_FILE"
  elif [ "$RTYPE" = "perplexity_auth" ]; then
    slack_notify "⚠ KNT daily publish FAILED: Perplexity API key was rejected (authentication). Check or rotate perplexity_api_key in ~/.config/herald/credentials, then re-run scripts/daily-publish.sh. Log: $LOG_FILE"
  elif [ -n "$RMSG" ]; then
    slack_notify "⚠ KNT daily publish FAILED: $RMSG Check $LOG_FILE"
  else
    slack_notify "⚠ KNT daily publish FAILED: research status=$RSTATUS. Check $LOG_FILE"
  fi
  exit 1
fi

PUBLISH_PROMPT="You are running the KNT daily publishing workflow. Herald's RESEARCH PHASE IS ALREADY DONE — do NOT run it again and do NOT run \`herald run\`. The research findings (with related-coverage context and the loaded config) are saved as JSON at:

  $RESEARCH_FILE

Steps:

1. Read $RESEARCH_FILE. Its keys: findings, context, config, options.

2. Follow the Herald synthesis pipeline in ~/.claude/skills/herald/SKILL.md, Phases 2-5, using those saved findings as the research input (skip Phase 1, Research — it is done):
   - Triage the findings into distinct stories.
   - Synthesize each briefing using the synthesis prompt (~/.claude/skills/herald/prompts/synthesis-agent.xml), voice.md and rules.md in $REPO_DIR, and the frontmatter schema (~/.claude/skills/herald/schemas/frontmatter.yaml). Carefully distinguish natural-trace vs concentrated vs synthetic 7-OH.
   - Run the voice, rules, and compliance checks and revise as needed. If a compliance violation cannot be resolved, halt and report (do NOT publish).
   - Write each finalized draft with: cd ~/.claude/skills/herald && .venv/bin/python run_phase.py write --config-dir $REPO_DIR --draft /tmp/herald-draft-<slug>.md

3. For each written draft, follow agent-docs/publishing-workflow.md: validate, generate the OG image (node scripts/generate-og-image.js --slug=<slug> --title=\"<title>\" --beat=<beat> --date=\"<date>\"), move it into content/briefings/, commit with message 'publish: <title>', and push origin main.

4. Output ONLY a JSON object on the last line: {\"status\":\"success\",\"slugs\":[\"the-slug\"]}. If triage finds no publishable new development (a real no-news day, NOT a technical failure), skip synthesis and output {\"status\":\"no_news\",\"message\":\"why nothing was publishable\"}. On a technical failure output {\"status\":\"error\",\"message\":\"what went wrong\"}.

CRITICAL EXECUTION RULES: run every command in the FOREGROUND and wait for it. Do NOT run anything in the background, do NOT schedule a wakeup, do NOT wait for a notification, do NOT ask questions. The research file already exists, so there is nothing long-running to wait on. Complete the synthesis and publish in this single turn, then exit."

# Run the publish step under a hard wall-clock timeout. timeout sends SIGTERM at
# the limit, then SIGKILL 30s later if it's still alive — so a hung Claude can no
# longer block the script (and the notifications) forever.
# Each attempt's output is captured separately (then appended to the log) so the
# loop can inspect the pipeline's status JSON for a declared no-news day.
ATTEMPT_OUT=$(mktemp)
trap 'rm -f "$ATTEMPT_OUT"' EXIT

# Run the publish step under a single hard wall-clock cap. `timeout` SIGTERMs at
# the limit, then SIGKILLs 30s later, so a hung claude can't block forever.
#
# NOTE: an earlier no-progress stall detector (watch ATTEMPT_OUT's mtime, kill if
# it stops growing) was removed because it cannot work here: `claude -p` buffers
# its output when redirected to a file, so the file stays empty until the run
# ends. The detector therefore saw "no output" the entire run and fired at its
# threshold regardless of whether the agent was working -- it killed two days of
# otherwise-healthy runs mid-pipeline. The real hang fix is upstream (clean
# queries + de-noised findings); this hard wall is the only backstop we need.
# --verbose still lands the full transcript in the log on exit.
LAST_ATTEMPT_REASON=""
# --max-budget-usd is a RUNAWAY backstop, not a per-run cost target. It was 5.00,
# but by late July it tripped on ~half the runs (07-24/26/28/29/31) — including
# single-briefing days — as loaded context (CLAUDE.md + skills + research findings)
# crept up, and it reliably blew on 2–3 briefing days. Every one of those runs had
# already produced its briefing(s) before dying, so the cap was killing completed
# work, not runaways. Raised to 10.00: ~2x the current single-briefing spend, which
# comfortably covers a 2–3 briefing day while still catching a genuinely runaway
# agent. The 30-min PUBLISH_TIMEOUT is the orthogonal wall-clock backstop.
run_publish() {
  set +e
  : > "$ATTEMPT_OUT"
  timeout -k 30 "$PUBLISH_TIMEOUT" claude -p \
    --dangerously-skip-permissions \
    --verbose \
    --max-budget-usd 10.00 \
    "$PUBLISH_PROMPT" > "$ATTEMPT_OUT" 2>&1
  local rc=$?
  set -e
  cat "$ATTEMPT_OUT" >> "$LOG_FILE"
  LAST_ATTEMPT_REASON=""
  if [ "$rc" -eq 124 ]; then
    LAST_ATTEMPT_REASON="timeout"
  elif grep -qiE 'Exceeded USD budget|max-budget' "$ATTEMPT_OUT"; then
    # Budget-cap exit: NOT a real failure on its own — it usually means the run
    # finished its briefing(s) and only then ran over. Flag the reason so the log
    # and any Slack alert read "budget", distinct from a genuine ERROR. The
    # published-files check below remains the real arbiter of success.
    LAST_ATTEMPT_REASON="budget"
  fi
  return "$rc"
}

# Print newly-added/modified briefing files since START_HEAD (empty if none committed).
new_briefings() {
  git diff --name-only --diff-filter=AM "$START_HEAD" HEAD -- content/briefings/ 2>/dev/null | grep '\.md$' || true
}

PUBLISHED_FILES=""
NO_NEWS=0
attempt=1
while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
  log "Running Herald synthesis + publish agent (attempt $attempt/$MAX_ATTEMPTS, timeout ${PUBLISH_TIMEOUT}s)..."
  rc=0; run_publish || rc=$?
  if [ "$rc" -eq 124 ]; then
    log "WARN: synthesis step hit the ${PUBLISH_TIMEOUT}s hard timeout and was killed."
  elif [ "$rc" -ne 0 ] && [ "$LAST_ATTEMPT_REASON" = "budget" ]; then
    log "NOTE: publish agent hit its USD budget cap (rc=$rc) — not a failure in itself; checking whether briefing(s) still landed."
  elif [ "$rc" -ne 0 ]; then
    log "WARN: publish step exited non-zero (rc=$rc)."
  else
    log "Publish step exited cleanly."
  fi

  # Did a briefing actually land, regardless of how Claude exited?
  PUBLISHED_FILES=$(new_briefings)
  if [ -n "$PUBLISHED_FILES" ]; then
    log "Detected published briefing(s):"
    echo "$PUBLISHED_FILES" | tee -a "$LOG_FILE"
    break
  fi

  # A clean exit that declared a no-news day is a valid outcome, not a failure.
  # Don't burn a retry re-running the same research against the same window.
  if [ "$rc" -eq 0 ] && grep -q '"status"[[:space:]]*:[[:space:]]*"no_news"' "$ATTEMPT_OUT"; then
    NO_NEWS=1
    log "No-news day declared by Herald triage. Skipping retry."
    break
  fi

  log "No new briefing detected after attempt $attempt."
  attempt=$((attempt + 1))
done

# Nothing published: a declared no-news day exits clean; anything else is a
# loud failure, no silent exit.
if [ -z "$PUBLISHED_FILES" ]; then
  if [ "$NO_NEWS" -eq 1 ]; then
    log "NO NEWS: Herald found no verifiable new development in the window. Exiting cleanly."
    slack_notify "🟢 KNT: no briefing today. Herald triage found no verifiable new development in the 24h window, so it skipped publishing per the no-padding rule. No action needed."
    log "=== KNT Daily Publish finished (no-news day) ==="
    exit 0
  fi
  log "ERROR: no briefing published after $MAX_ATTEMPTS attempt(s)."
  # Include the tail of the last attempt's transcript and how it ended so the
  # failure can be triaged from the Slack alert without opening the log.
  FAIL_TAIL=$(tail -n 15 "$ATTEMPT_OUT" 2>/dev/null | tr '\n' ' ' | tr -s ' ' | cut -c1-500)
  slack_notify "⚠ KNT daily publish FAILED: no briefing after $MAX_ATTEMPTS attempt(s) (last attempt ended: ${LAST_ATTEMPT_REASON:-clean-no-output}). Last log: ${FAIL_TAIL:-<empty>} — full log: $LOG_FILE"
  exit 1
fi

# Make sure the day's briefing(s) are on origin — but decide against REAL remote
# state, and NEVER let a push hiccup cost the day's send.
#
# The publish agent usually pushes its own commit to origin DURING the run. So by
# the time we reach here the remote typically already holds HEAD, and a second
# wrapper push gets rejected by git's compare-and-swap purely BECAUSE the work
# already succeeded. The old code compared HEAD against the STALE local origin/main
# tracking ref, saw "commits not on origin yet", pushed, hit
# "cannot lock ref 'refs/heads/main'... is at <new> but expected <stale>", and
# exit 1'd — killing the Klaviyo send even though both briefings were already live.
# Two rules now:
#   1. Fetch first; compare HEAD to the AUTHORITATIVE remote sha, not a stale ref.
#   2. An unnecessary push (remote already has HEAD) is SUCCESS. A genuine push
#      failure is logged + alerted but is NON-FATAL — the notification always runs,
#      because the briefings deploy independently of this wrapper's push.
git fetch --quiet origin main >> "$LOG_FILE" 2>&1 || log "WARN: git fetch origin main failed; comparing via ls-remote only."
REMOTE_MAIN=$(git ls-remote origin main 2>>"$LOG_FILE" | awk 'NR==1{print $1}') || REMOTE_MAIN=""
LOCAL_HEAD=$(git rev-parse HEAD)
if [ -z "$REMOTE_MAIN" ]; then
  log "WARN: could not read origin/main — attempting a fallback push (non-fatal)."
  if git push origin main >> "$LOG_FILE" 2>&1; then
    log "Fallback push succeeded."
  else
    log "WARN: fallback push failed and remote state is unknown; sending the newsletter anyway."
    slack_notify "⚠ KNT publish: wrapper push failed and remote state was unverifiable — newsletter sent anyway. Confirm briefings are live: $LOG_FILE"
  fi
elif [ "$REMOTE_MAIN" = "$LOCAL_HEAD" ]; then
  log "origin/main already at HEAD ($LOCAL_HEAD) — the publish agent pushed during the run. No wrapper push needed."
elif git merge-base --is-ancestor "$REMOTE_MAIN" "$LOCAL_HEAD" 2>/dev/null; then
  log "HEAD is ahead of origin/main — pushing..."
  if git push origin main >> "$LOG_FILE" 2>&1; then
    log "Push succeeded."
  else
    log "WARN: git push failed though HEAD is ahead of origin — NON-FATAL; the newsletter still sends. Push by hand later."
    slack_notify "⚠ KNT publish: briefing committed but wrapper PUSH FAILED (HEAD ahead of origin). Newsletter sent anyway; push by hand and check $LOG_FILE"
  fi
else
  log "origin/main ($REMOTE_MAIN) is ahead of or diverged from HEAD ($LOCAL_HEAD) — not pushing (never force). Proceeding to notification."
fi

# Collect every briefing's slug + email data. NOTHING is announced as "live" and
# NOTHING is emailed until the deploy is watched to success AND the pages are
# proven reachable — the send is gated on liveness, never on the push (08-01:
# the push/commit succeeded but the deploy failed, so the newsletter linked a 404).
ARTICLES_JSON="[]"
SLUGS=()
declare -A RULES_WARNINGS   # slug -> violation message, populated below (advisory only, never blocks)
while IFS= read -r f; do
  [ -z "$f" ] && continue
  slug=$(python3 -c "import re,sys; c=open(sys.argv[1]).read(); m=re.search(r'^slug:\s*\"?(.+?)\"?\s*\$', c, re.M); print(m.group(1) if m else '')" "$f" 2>/dev/null)
  if [ -z "$slug" ]; then
    slug=$(basename "$f" .md | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//')
  fi
  SLUGS+=("$slug")

  # Advisory rules-check (Sources section, rules.md:37). LOUD, never blocking:
  # logs a clear warning and records it for the Slack notification below, but
  # the commit/push/deploy/email flow proceeds exactly as it would otherwise.
  sources_check=$(check_body_sources_section "$f")
  if [ "$sources_check" != "pass" ]; then
    log "RULES WARNING: '$slug' -- $sources_check (advisory only, publish NOT blocked, see rules.md:37)"
    RULES_WARNINGS["$slug"]="$sources_check"
  fi

  # Email: append this briefing to the array (skip if its file can't be read).
  if article=$(extract_article_data "$slug"); then
    ARTICLES_JSON=$(python3 -c "import json,sys; arr=json.loads(sys.argv[1]); arr.append(json.loads(sys.argv[2])); print(json.dumps(arr))" "$ARTICLES_JSON" "$article")
  fi
done <<< "$PUBLISHED_FILES"

# THE LIVENESS GATE. Watch the deploy for the pushed commit, retry once on failure,
# and require every briefing URL to be live before anything goes out.
if wait_for_deploy_and_verify "$LOCAL_HEAD" "${SLUGS[@]}"; then
  # Live: announce on Slack (one message per briefing) and send the one daily email.
  for slug in "${SLUGS[@]}"; do
    [ -z "$slug" ] && continue
    notify_for_slug "$slug"
  done
  send_klaviyo_campaign "$ARTICLES_JSON"
  log "SUCCESS: published, verified live, and notified."
else
  # Not live after the retry: DO NOT email subscribers. Alert loudly instead.
  log "ERROR: briefing(s) did not go live after deploy + retry — SUPPRESSING the newsletter."
  slack_notify "⚠ KNT publish: briefing(s) committed but NOT verified live after deploy + one retry. Newsletter was NOT sent (no email to a 404). Check the deploy Action and $LOG_FILE"
  log "=== KNT Daily Publish finished (email suppressed — not live) ==="
  exit 1
fi

log "=== KNT Daily Publish finished ==="
