# Publishing Workflow — Kratom News Today

This document describes the step-by-step process for publishing a Herald-produced draft. Claude Code on the Openclaw machine reads this file when invoked to publish a draft.

## When this workflow runs

Triggered by the daily cron job on Openclaw at 8am Eastern. The cron command invokes Claude Code with an instruction to "run Herald in this repo, then follow the publishing workflow documented in agent-docs/publishing-workflow.md."

This workflow is also the reference for any manual publish — if you (Mike) need to publish a draft outside the scheduled cron run, run Claude Code with the same instruction.

## Prerequisites

Before this workflow runs, the following must be true:

- This repository is cloned locally on Openclaw with git push access
- Herald is installed at `~/.claude/skills/herald/`
- Herald's four config files exist in this repo root (`research.md`, `voice.md`, `rules.md`, `options.md`)
- Perplexity and OpenAI API keys are configured at `~/.config/herald/credentials`
- The publishing workflow has access to commit and push to the `main` branch

## The workflow

### Step 1: Run Herald

Invoke Herald via the standard skill invocation pattern. Herald will:

- Check that all four config files exist (they should)
- Run pre-run indexing on `./content/briefings/`
- Run research via Perplexity
- Run context retrieval against the vector index
- Run synthesis using voice.md and rules.md
- Run voice check (with revision loop per options.md)
- Run rules check (with revision loop per options.md)
- Run compliance check (enabled per options.md, with halt-and-report on violations)
- Run frontmatter validation
- Write the finalized draft to `./drafts/`
- Report the draft path and a run summary

If Herald reports halt-and-report (typically a compliance violation that couldn't be revised), DO NOT continue with publishing. Log the failure, leave the failed draft in `./drafts/failed/`, and notify Mike. Exit the workflow.

If Herald completes successfully, proceed to Step 2.

### Step 2: Validate the draft

Read the draft file Herald produced. Verify:

- Frontmatter parses as valid YAML
- All required frontmatter fields are present: `title`, `slug`, `date`, `generated_at`, `type`, `summary`, `tags`, `entities`, `sources`, `related_briefings`, `herald_version`, `herald_options_snapshot`
- The `slug` matches the filename (minus the date prefix and `.md` extension)
- Body is non-empty
- All inline reference-style links resolve to slugs that exist in `related_briefings`
- All slugs in `related_briefings` correspond to either existing files in `./content/briefings/` or to other valid slugs in the recent past
- The TL;DR in `summary` is 2-3 sentences and standalone

If validation fails, log the specific failure, leave the draft in `./drafts/`, and notify Mike. Do not continue.

If validation passes, proceed to Step 3.

### Step 3: Generate the OG image for this briefing

Run the OG image generation script (built as part of the site infrastructure):

```
node scripts/generate-og-image.js --slug=<slug> --title="<title>" --beat=<beat>
```

This produces `./src/assets/og-images/<slug>.png` (or .jpg). Verify the file exists.

If the OG generation fails (rare), log the failure but DO NOT halt publishing — the site has a fallback default OG image. The article publishes with the default; we can regenerate later.

### Step 4: Move the draft to content

```
git mv ./drafts/<filename> ./content/briefings/<filename>
```

This moves the file in git's tracking, not just on disk. The draft is no longer a draft; it's published content.

### Step 5: Commit and push

Commit message format:

```
publish: <title>

slug: <slug>
beat: <primary beat tag>
sources: <count> sources cited
```

Commit and push to `main`:

```
git add .
git commit -m "<message>"
git push origin main
```

GitHub Actions will pick up the push, run the Eleventy build, and deploy to Cloudways via rsync. Total time from push to live is typically 2-3 minutes.

### Step 6: Verify the deploy succeeded

Wait briefly (60-90 seconds is typical), then verify:

- The new briefing is live at `https://kratomnewstoday.com/briefings/<slug>/`
- The homepage shows the new briefing as the latest
- The relevant beat page shows the new briefing
- The RSS feed (`/feed.xml` and the beat-specific feed) includes the new briefing

If deploy verification fails, log the issue, notify Mike. The content is committed regardless; the deploy can be triggered again by pushing an empty commit or by manual GitHub Actions invocation.

### Step 7: Trigger the email send (deferred for launch)

NOT IMPLEMENTED AT LAUNCH. The first 1-2 weeks of operation focus on email list collection without daily sends. Once the welcome flow and template are configured in Klaviyo (per the pre-launch checklist), this step gets added:

```
node scripts/send-briefing-email.js --slug=<slug>
```

This calls Klaviyo's API to trigger a send to the briefing list using the day's article. When this step is enabled, add it after Step 6 succeeds.

### Step 8: Report success

Log the successful publish with: timestamp, slug, title, beat, sources count, total workflow duration. Exit cleanly.

## Failure modes

| Failure | Response |
|---|---|
| Herald halt-and-report | Stop. Log. Notify Mike. Do not publish. |
| Frontmatter validation fails | Stop. Log specifics. Leave draft in `./drafts/`. Notify Mike. |
| OG image generation fails | Continue. Use default fallback image. Log warning. |
| Git operations fail | Stop. Log. Notify Mike. (Common causes: merge conflict, no push access, network issue.) |
| GitHub Actions build fails | Content is in git but not deployed. Notify Mike. Can be fixed with a follow-up commit or manual rebuild. |
| Cloudways rsync fails | Same as above. |

## Notification mechanism

For now, "notify Mike" means: write a clear log line in the standard workflow output that the cron job captures, and include the failure details. Mike checks the cron output. Future enhancement may add Slack/email/SMS notifications; not required for launch.

## Manual overrides

If Mike needs to edit a published briefing:

1. Edit the file in `./content/briefings/<slug>.md` directly
2. Add an Update note at the top of the body using the shortcode: `{% update date="<date>" %}<description of what changed>{% endupdate %}`
3. Update the `date_modified` frontmatter field
4. Commit and push

If Mike needs to unpublish a briefing entirely (rare):

1. Move it back to `./drafts/` with `git mv`
2. Commit and push
3. The site will rebuild without it

If the cron job needs to be paused:

1. SSH into Openclaw
2. Disable or comment out the cron entry
3. Re-enable when ready

There is no in-repo pause flag at launch — pausing is handled at the cron level per Mike's preference.

## Future enhancement: presscall skill

This publishing workflow is intentionally written as in-repo documentation rather than as a global Claude Code skill. The intent is to extract these patterns into a global skill (working name: presscall) once a second publication uses the same orchestration. When that happens, this file becomes the reference implementation that presscall is designed around.
