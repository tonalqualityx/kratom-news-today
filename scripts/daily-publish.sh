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
PUBLISH_TIMEOUT=1200   # max seconds for the claude publish step before we kill it (20 min)
MAX_ATTEMPTS=2         # how many times to attempt publish if no briefing lands

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

  local payload
  payload=$(python3 -c "
import json, sys
title, beat, url, chan = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
beat_tag = f' [{beat}]' if beat else ''
msg = '\n'.join(['📰 *KNT Daily Briefing Published*', '', f'<{url}|{title}>{beat_tag}', '', '1 briefing(s) live.'])
print(json.dumps({'channel': chan, 'text': msg, 'unfurl_links': False}))
" "$title" "$beat" "$url" "$SLACK_CHANNEL" 2>/dev/null)
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

PUBLISH_PROMPT="You are running the KNT daily publishing workflow. Follow these steps exactly:

1. Run herald run --config-dir /home/mike/Documents/kratom-news-today
   This invokes the Herald skill which will research, triage, synthesize, and check briefings.

2. After Herald completes, follow the publishing workflow in agent-docs/publishing-workflow.md:
   - Validate the draft(s)
   - Generate OG images: node scripts/generate-og-image.js --slug=<slug> --title=\"<title>\" --beat=<beat> --date=\"<date>\"
   - Move draft(s) from drafts/ to content/briefings/
   - Commit with message format: publish: <title>
   - Push to origin main

3. After push, output ONLY a JSON object on the last line:
   {\"status\":\"success\",\"slugs\":[\"the-slug\"]}
   If anything fails, output: {\"status\":\"error\",\"message\":\"what went wrong\"}

Do not ask questions. Do not wait for input. Do NOT start a dev server or any
long-running foreground process. Execute the full pipeline and exit."

# Run the publish step under a hard wall-clock timeout. timeout sends SIGTERM at
# the limit, then SIGKILL 30s later if it's still alive — so a hung Claude can no
# longer block the script (and the notifications) forever.
run_publish() {
  set +e
  timeout -k 30 "$PUBLISH_TIMEOUT" claude -p \
    --dangerously-skip-permissions \
    --max-budget-usd 5.00 \
    "$PUBLISH_PROMPT" >> "$LOG_FILE" 2>&1
  local rc=$?
  set -e
  return "$rc"
}

# Print newly-added/modified briefing files since START_HEAD (empty if none committed).
new_briefings() {
  git diff --name-only --diff-filter=AM "$START_HEAD" HEAD -- content/briefings/ 2>/dev/null | grep '\.md$' || true
}

PUBLISHED_FILES=""
attempt=1
while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
  log "Running Herald research + publish pipeline (attempt $attempt/$MAX_ATTEMPTS, timeout ${PUBLISH_TIMEOUT}s)..."
  rc=0; run_publish || rc=$?
  if [ "$rc" -eq 124 ]; then
    log "WARN: publish step hit the ${PUBLISH_TIMEOUT}s timeout and was killed."
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

  log "No new briefing detected after attempt $attempt."
  attempt=$((attempt + 1))
done

# Nothing published after all attempts → loud failure, no silent exit.
if [ -z "$PUBLISHED_FILES" ]; then
  log "ERROR: no briefing published after $MAX_ATTEMPTS attempt(s)."
  slack_notify "⚠ KNT daily publish FAILED: no briefing published after $MAX_ATTEMPTS attempt(s). Check $LOG_FILE"
  exit 1
fi

# A timeout-kill can land between commit and push — make sure it's on origin.
if [ -n "$(git log origin/main..HEAD --oneline 2>/dev/null)" ]; then
  log "Local commit(s) not on origin yet — pushing..."
  git push origin main >> "$LOG_FILE" 2>&1 || {
    log "ERROR: git push failed"
    slack_notify "⚠ KNT publish: briefing committed but PUSH FAILED. Check $LOG_FILE"
    exit 1
  }
fi

# Notify Slack per published briefing, and collect every briefing's email data
# so they all ride in a single Klaviyo campaign (one email per day, never one
# per article). Sourced from the committed files.
ARTICLES_JSON="[]"
while IFS= read -r f; do
  [ -z "$f" ] && continue
  slug=$(python3 -c "import re,sys; c=open(sys.argv[1]).read(); m=re.search(r'^slug:\s*\"?(.+?)\"?\s*\$', c, re.M); print(m.group(1) if m else '')" "$f" 2>/dev/null)
  if [ -z "$slug" ]; then
    slug=$(basename "$f" .md | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//')
  fi

  # Slack: one message per briefing.
  notify_for_slug "$slug"

  # Email: append this briefing to the array (skip if its file can't be read).
  if article=$(extract_article_data "$slug"); then
    ARTICLES_JSON=$(python3 -c "import json,sys; arr=json.loads(sys.argv[1]); arr.append(json.loads(sys.argv[2])); print(json.dumps(arr))" "$ARTICLES_JSON" "$article")
  fi
done <<< "$PUBLISHED_FILES"

# Email: ONE Klaviyo campaign carrying all of today's briefings.
send_klaviyo_campaign "$ARTICLES_JSON"

log "SUCCESS: published and notified."
log "=== KNT Daily Publish finished ==="
