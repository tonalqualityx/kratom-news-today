# Kratom News Today — Pre-Launch Checklist

A complete punch list of everything that needs to happen between now and launch. Organized by category. Items with dependencies note what blocks them.

---

## Domain and infrastructure

- [ ] **Register or confirm kratomnewstoday.com is owned** (~5 min)
  Confirm domain is registered to you or appropriate entity. If not, register at your usual registrar.

- [ ] **Point DNS for kratomnewstoday.com to Cloudways** (~15 min)
  *Depends on: domain registered*
  Add A records (or use Cloudways DNS) pointing the domain to the Cloudways server IP. Propagation can take up to a few hours.

- [ ] **Create Custom PHP/Nginx app on Cloudways** (~10 min)
  On the existing 4-8GB server. Choose Custom PHP as the application type. Nginx stack. Assign kratomnewstoday.com as the primary domain on the app.

- [ ] **Provision SSL certificate** (~5 min)
  *Depends on: DNS pointing, Cloudways app created*
  Cloudways supports one-click Let's Encrypt SSL once DNS is pointing correctly. Auto-renews.

- [ ] **Configure Cloudflare in front of Cloudways** (~30 min)
  *Depends on: SSL provisioned*
  Add the domain to Cloudflare, point nameservers from registrar to Cloudflare, configure cache rules for static assets (HTML, CSS, JS, images). Set SSL mode to Full (strict) since Cloudways has a valid cert.

- [ ] **Set up mail.kratomnewstoday.com subdomain** (~5 min)
  *Depends on: DNS configured*
  Create the subdomain in DNS (no need to point it anywhere yet — Klaviyo will provide records to add).

---

## GitHub and deployment

- [ ] **Create private GitHub repo: kratomnewstoday** (~2 min)
  Private repo. Add to your personal or organization account, whichever you prefer.

- [ ] **Enable SSH access on Cloudways app** (~10 min)
  *Depends on: Cloudways app created*
  In Cloudways app settings, enable SSH. Generate an SSH key pair specifically for GitHub Actions deploys (don't reuse a personal key).

- [ ] **Add GitHub Actions secrets** (~5 min)
  *Depends on: SSH enabled, GitHub repo created*
  Add to repo settings:
  - `CLOUDWAYS_SSH_PRIVATE_KEY` — the private key
  - `CLOUDWAYS_SSH_HOST` — the server hostname
  - `CLOUDWAYS_SSH_USER` — typically `master`
  - `CLOUDWAYS_DEPLOY_PATH` — web root path on server

- [ ] **Configure branch protection on main** (~3 min)
  *Depends on: GitHub repo created*
  Require status checks (the build workflow) to pass before merge. Lightweight protection appropriate for a single-maintainer repo.

---

## Email infrastructure

- [ ] **Set up editor@ and advertising@ email forwarding or Google Workspace** (~20 min)
  Either Google Workspace for kratomnewstoday.com (more setup, ~$6/mo) or simple email forwarding through your registrar. Forwarding is fine for launch.

---

## Klaviyo

- [ ] **Create Klaviyo list for KNT subscribers** (~10 min)
  Separate from any Herba customer lists. Single-purpose: people who signed up for the daily briefing.

- [ ] **Add Klaviyo DNS records to mail.kratomnewstoday.com** (~20 min)
  *Depends on: mail subdomain created, Klaviyo list created*
  Klaviyo provides CNAME, SPF (TXT), DKIM (TXT), and DMARC (TXT) records. Add all to mail.kratomnewstoday.com. Wait for propagation, then verify in Klaviyo.

- [ ] **Configure sender as briefing@kratomnewstoday.com** (~5 min)
  *Depends on: Klaviyo DNS verified*
  Set the visible from-address. Reply-to also briefing@ (or editor@, your choice).

- [ ] **Enable double opt-in** (~5 min)
  *Depends on: Klaviyo list created*
  Klaviyo default may vary. For best deliverability, require confirmation email click before adding subscribers to the active list.

- [ ] **Draft welcome email** (~30 min)
  *Depends on: Klaviyo sender configured*
  One-time send when a subscriber confirms. Brief: what to expect, when briefings arrive, how to unsubscribe. Improves engagement reputation when daily sends begin.

- [ ] **Build daily briefing email template** (~1-2 hours)
  *Depends on: Klaviyo sender configured*
  Template that displays the day's briefing — headline, TL;DR, link to read more on the site, plus ad inventory for Herba. Will be populated via API once daily sends start (week 2-3 after launch).

- [ ] **Wire up API send (deferred to week 2-3)** (~2-3 hours)
  *Depends on: daily template built, list has subscribers*
  Not at launch. After 1-2 weeks of email collection, wire up the API call from the publishing workflow to trigger the daily send to the briefing list when a new article publishes.

---

## Content for launch

- [ ] **Finalize About page content** (~30 min)
  Already drafted in planning sessions. Verify final version, add to repo when site is built.

- [ ] **Place research.md, voice.md, rules.md, options.md in repo** (~30 min)
  *Depends on: GitHub repo created*
  All four KNT config files are drafted from planning. Run Herald setup in the KNT repo, walk through validation (since files already exist), confirm.

- [ ] **Run Herald in batch mode for 30 days backdated coverage** (~half day)
  *Depends on: site infrastructure built, config files in place*
  Generate 30 daily briefings covering the prior 30 days of kratom industry news. Each piece dated correctly (the news date, not the generation date). Review and publish at launch.

- [ ] **Write 2-3 flagship pieces personally** (~1-2 days)
  Cornerstone content that earns links:
  - "State of Kratom Regulation 2026"
  - A piece on the 7-OH manufacturing landscape
  - A piece on the BRAM situation explained for industry readers
  Higher quality than daily briefings; serves as the publication's anchor content.

---

## Site build (Claude Code)

- [ ] **Hand site build instructions to Claude Code on Openclaw** (Claude Code does this)
  *Depends on: GitHub repo created, SSH configured*
  Once site build instructions bundle is ready, Claude Code constructs the Eleventy site, templates, components, GitHub Actions workflow, and publishing-workflow.md documentation in the repo.

- [ ] **Test first deploy from main to Cloudways** (~30 min)
  *Depends on: site build complete, GitHub secrets configured*
  Push a small change to main, verify GitHub Actions builds and deploys to the server. Confirm the site loads at kratomnewstoday.com.

---

## Google News submission

- [ ] **Submit to Google News** (~30 min submission, weeks for approval)
  *Depends on: first deploy successful, backfill content published*
  Once site is live with sufficient content (30-day backfill + flagship pieces), submit through Google News Publisher Center. Approval typically 2-4 weeks. Requires: About page, masthead, editorial policy, contact info, ownership disclosure — all already specified.

---

## Herba promotion (launch fuel)

- [ ] **Send Herba email list announcement** (~15 min draft, send at launch)
  Drafted message introducing Kratom News Today to Herba's existing customer email list. Day-of-launch send for initial traffic.

- [ ] **Add KNT link to Herba main site footer** (~15 min)
  Disclosed publisher relationship working in both directions. Herba's site links to KNT in the footer as "Publisher of Kratom News Today."

- [ ] **Soft community introduction on Reddit** (~30 min)
  Share one of your flagship pieces in r/kratom as a personal contribution, not corporate marketing. Mike's account, not corporate. Genuine engagement only.

---

## Automation (Openclaw)

- [ ] **Set up daily cron job on Openclaw** (~30 min)
  *Depends on: site build complete, config files in place*
  Cron triggers daily at 8am Eastern, invokes the publishing workflow (which runs Herald, then site build, then commit/push).

- [ ] **Monitor first week of automated runs** (15 min daily for week 1)
  *Depends on: cron job running*
  Watch each daily run, verify Herald produces good output, verify publishing workflow commits cleanly, verify deploy succeeds. Catch issues while they're small.

---

## Order of operations (suggested)

The shortest path to launch, with dependencies handled in order:

1. Domain DNS + Cloudways app + SSL (do these in parallel where possible)
2. Cloudflare configuration
3. GitHub repo + SSH key generation
4. Mail subdomain + Klaviyo setup begins
5. Hand site build to Claude Code (this is the long-running step — let it run while you do other items)
6. While Claude Code builds: editor@/advertising@ email setup, Klaviyo DNS, Klaviyo template work
7. Site build completes → test deploy
8. Run Herald backfill against the built site
9. Write flagship pieces (can happen anytime during site build)
10. Add Herba footer link + draft announcement email
11. Submit to Google News
12. Launch day: send Herba announcement, soft Reddit intro
13. Set up cron on Openclaw, monitor first week

Realistic timeline: 1-2 weeks of focused work, depending on how many items happen in parallel. The 8-week traffic target starts ticking from launch.
