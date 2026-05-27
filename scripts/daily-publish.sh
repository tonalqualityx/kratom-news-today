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

mkdir -p "$LOG_DIR"

# Read Slack bot token from Openclaw config at runtime
SLACK_BOT_TOKEN=$(python3 -c "import json; print(json.load(open('/home/mike/.openclaw/openclaw.json'))['channels']['slack']['botToken'])" 2>/dev/null)

# Read Klaviyo config
KLAVIYO_CONFIG="/home/mike/.config/knt/klaviyo.json"
KLAVIYO_API_KEY=$(python3 -c "import json; print(json.load(open('$KLAVIYO_CONFIG'))['privateApiKey'])" 2>/dev/null)
KLAVIYO_LIST_ID=$(python3 -c "import json; print(json.load(open('$KLAVIYO_CONFIG'))['listId'])" 2>/dev/null)
KLAVIYO_TEMPLATE_ID=$(python3 -c "import json; print(json.load(open('$KLAVIYO_CONFIG'))['templateId'])" 2>/dev/null)

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

send_klaviyo_campaign() {
  local title="$1" summary="$2" url="$3"
  if [ -z "$KLAVIYO_API_KEY" ]; then
    log "WARN: Klaviyo API key not configured, skipping email campaign"
    return
  fi

  log "Preparing Klaviyo campaign..."

  # Step 1: Read the template, swap placeholders, update it, then restore after
  TEMPLATE_UPDATED=$(python3 << PYEOF
import json, sys, urllib.request

api_key = "$KLAVIYO_API_KEY"
template_id = "$KLAVIYO_TEMPLATE_ID"
title = $(python3 -c "import json; print(json.dumps('$title'))")
summary = $(python3 -c "import json; print(json.dumps('$summary'))")
url = "$url"

headers = {
    "Authorization": f"Klaviyo-API-Key {api_key}",
    "Content-Type": "application/json",
    "revision": "2024-02-15"
}

# Read template
req = urllib.request.Request(
    f"https://a.klaviyo.com/api/templates/{template_id}",
    headers=headers
)
resp = urllib.request.urlopen(req)
data = json.loads(resp.read())
original_html = data["data"]["attributes"]["html"]

# Replace placeholders
updated_html = original_html.replace("{{ event.title }}", title)
updated_html = updated_html.replace("{{ event.summary }}", summary)
updated_html = updated_html.replace("{{ event.url }}", url)

# Update template
update_payload = json.dumps({
    "data": {
        "type": "template",
        "id": template_id,
        "attributes": {
            "html": updated_html
        }
    }
}).encode()

req = urllib.request.Request(
    f"https://a.klaviyo.com/api/templates/{template_id}",
    data=update_payload,
    headers=headers,
    method="PATCH"
)
resp = urllib.request.urlopen(req)

# Save original HTML for restore
with open("/tmp/knt-template-backup.json", "w") as f:
    json.dump({"html": original_html}, f)

print("OK")
PYEOF
  )

  if [ "$TEMPLATE_UPDATED" != "OK" ]; then
    log "WARN: Failed to update Klaviyo template"
    return
  fi

  log "Template updated with briefing content. Creating campaign..."

  # Step 2: Create the campaign
  CAMPAIGN_RESPONSE=$(python3 << PYEOF
import json, urllib.request

api_key = "$KLAVIYO_API_KEY"
title = $(python3 -c "import json; print(json.dumps('$title'))")

payload = json.dumps({
    "data": {
        "type": "campaign",
        "attributes": {
            "name": f"Daily Briefing: {title}",
            "audiences": {
                "included": [{"type": "list", "id": "$KLAVIYO_LIST_ID"}]
            },
            "campaign-messages": {
                "data": [{
                    "type": "campaign-message",
                    "attributes": {
                        "channel": "email",
                        "label": "Daily Briefing",
                        "content": {
                            "subject": title,
                            "from_email": "briefing@kratomnewstoday.com",
                            "from_label": "Kratom News Today"
                        },
                        "template_id": "$KLAVIYO_TEMPLATE_ID"
                    }
                }]
            },
            "send_strategy": {
                "method": "immediate"
            }
        }
    }
}).encode()

req = urllib.request.Request(
    "https://a.klaviyo.com/api/campaigns/",
    data=payload,
    headers={
        "Authorization": f"Klaviyo-API-Key {api_key}",
        "Content-Type": "application/json",
        "revision": "2024-02-15"
    }
)
resp = urllib.request.urlopen(req)
data = json.loads(resp.read())
print(data["data"]["id"])
PYEOF
  )

  if [ -z "$CAMPAIGN_RESPONSE" ]; then
    log "WARN: Failed to create Klaviyo campaign"
    # Restore template before returning
    python3 -c "
import json, urllib.request
with open('/tmp/knt-template-backup.json') as f:
    original = json.load(f)['html']
payload = json.dumps({'data': {'type': 'template', 'id': '$KLAVIYO_TEMPLATE_ID', 'attributes': {'html': original}}}).encode()
req = urllib.request.Request('https://a.klaviyo.com/api/templates/$KLAVIYO_TEMPLATE_ID', data=payload, headers={'Authorization': 'Klaviyo-API-Key $KLAVIYO_API_KEY', 'Content-Type': 'application/json', 'revision': '2024-02-15'}, method='PATCH')
urllib.request.urlopen(req)
" 2>/dev/null
    return
  fi

  CAMPAIGN_ID="$CAMPAIGN_RESPONSE"
  log "Campaign created: $CAMPAIGN_ID. Sending..."

  # Step 3: Send the campaign
  python3 << PYEOF
import json, urllib.request

payload = json.dumps({
    "data": {
        "type": "campaign-send-job",
        "id": "$CAMPAIGN_ID"
    }
}).encode()

req = urllib.request.Request(
    "https://a.klaviyo.com/api/campaign-send-jobs/",
    data=payload,
    headers={
        "Authorization": "Klaviyo-API-Key $KLAVIYO_API_KEY",
        "Content-Type": "application/json",
        "revision": "2024-02-15"
    }
)
urllib.request.urlopen(req)
PYEOF

  log "Campaign sent."

  # Step 4: Restore the template with placeholders
  python3 << PYEOF
import json, urllib.request

with open("/tmp/knt-template-backup.json") as f:
    original_html = json.load(f)["html"]

payload = json.dumps({
    "data": {
        "type": "template",
        "id": "$KLAVIYO_TEMPLATE_ID",
        "attributes": {
            "html": original_html
        }
    }
}).encode()

req = urllib.request.Request(
    "https://a.klaviyo.com/api/templates/$KLAVIYO_TEMPLATE_ID",
    data=payload,
    headers={
        "Authorization": "Klaviyo-API-Key $KLAVIYO_API_KEY",
        "Content-Type": "application/json",
        "revision": "2024-02-15"
    },
    method="PATCH"
)
urllib.request.urlopen(req)
PYEOF

  log "Template restored with placeholders."
  rm -f /tmp/knt-template-backup.json
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

# Run Herald via Claude Code in non-interactive mode
log "Running Herald research + publish pipeline..."
CLAUDE_OUTPUT=$(claude -p \
  --dangerously-skip-permissions \
  --max-budget-usd 5.00 \
  "You are running the KNT daily publishing workflow. Follow these steps exactly:

1. Run herald run --config-dir /home/mike/Documents/kratom-news-today
   This invokes the Herald skill which will research, triage, synthesize, and check briefings.

2. After Herald completes, follow the publishing workflow in agent-docs/publishing-workflow.md:
   - Validate the draft(s)
   - Generate OG images: node scripts/generate-og-image.js --slug=<slug> --title=\"<title>\" --beat=<beat> --date=\"<date>\"
   - Move draft(s) from drafts/ to content/briefings/
   - Commit with message format: publish: <title>
   - Push to origin main

3. After push, output ONLY a JSON object on the last line with this structure (no other text after it):
   {\"status\":\"success\",\"slugs\":[\"the-slug\"],\"titles\":[\"The Title\"],\"beats\":[\"regulation\"]}

   If anything fails, output:
   {\"status\":\"error\",\"message\":\"what went wrong\"}

Do not ask questions. Do not wait for input. Execute the full pipeline." 2>> "$LOG_FILE") || {
  log "ERROR: Claude Code exited with non-zero status"
  slack_notify "⚠ KNT daily publish failed: Claude Code error. Check $LOG_FILE"
  exit 1
}

# Save full output to log
echo "$CLAUDE_OUTPUT" >> "$LOG_FILE"

# Parse the JSON result from the last line
RESULT_JSON=$(echo "$CLAUDE_OUTPUT" | grep -o '{.*}' | tail -1)

if [ -z "$RESULT_JSON" ]; then
  log "WARN: Could not parse result JSON from Claude output"
  slack_notify "⚠ KNT daily publish completed but couldn't parse results. Check $LOG_FILE"
  exit 0
fi

STATUS=$(echo "$RESULT_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null)

if [ "$STATUS" = "success" ]; then
  # Build the Slack message with links
  SLACK_MSG=$(echo "$RESULT_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
slugs = d.get('slugs', [])
titles = d.get('titles', [])
beats = d.get('beats', [])
site = '$SITE_URL'
lines = ['📰 *KNT Daily Briefing Published*', '']
for i, slug in enumerate(slugs):
    title = titles[i] if i < len(titles) else slug
    beat = beats[i] if i < len(beats) else ''
    beat_tag = f' [{beat}]' if beat else ''
    lines.append(f'<{site}/briefings/{slug}/|{title}>{beat_tag}')
lines.append('')
lines.append(f'{len(slugs)} briefing(s) live.')
print('\n'.join(lines))
" 2>/dev/null)

  log "SUCCESS: Published $(echo "$RESULT_JSON" | python3 -c "import json,sys; print(len(json.load(sys.stdin).get('slugs',[])))" 2>/dev/null) briefing(s)"

  # Send rich Slack notification
  PAYLOAD=$(python3 -c "
import json
msg = '''$SLACK_MSG'''
print(json.dumps({'channel': '$SLACK_CHANNEL', 'text': msg, 'unfurl_links': False}))
" 2>/dev/null)
  slack_notify_json "$PAYLOAD"

  # Send Klaviyo daily briefing email
  FIRST_TITLE=$(echo "$RESULT_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('titles',[''])[0])" 2>/dev/null)
  FIRST_SLUG=$(echo "$RESULT_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('slugs',[''])[0])" 2>/dev/null)
  FIRST_SUMMARY=$(echo "$RESULT_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('summaries',[''])[0] if d.get('summaries') else '')" 2>/dev/null)
  BRIEFING_URL="$SITE_URL/briefings/$FIRST_SLUG/"
  send_klaviyo_campaign "$FIRST_TITLE" "$FIRST_SUMMARY" "$BRIEFING_URL"

elif [ "$STATUS" = "error" ]; then
  ERROR_MSG=$(echo "$RESULT_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('message','unknown error'))" 2>/dev/null)
  log "ERROR: $ERROR_MSG"
  slack_notify "⚠ KNT daily publish failed: $ERROR_MSG"
else
  log "WARN: Unknown status: $STATUS"
  slack_notify "⚠ KNT daily publish returned unknown status. Check $LOG_FILE"
fi

log "=== KNT Daily Publish finished ==="
