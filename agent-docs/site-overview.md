# Site Overview — Kratom News Today

This document orients any agent working in this repository. Read it first before doing publishing or maintenance work.

## What this site is

Kratom News Today (kratomnewstoday.com) is a daily briefing publication on the kratom industry. Coverage spans three beats: regulation, business, and science. The publication operates as a trade publication with disclosed ownership — published by Herba Releaf, a kratom products manufacturer based in Wyoming, Pennsylvania.

The publication's editorial position: "report what is being reported." It does not make first-person claims about kratom. It reports what regulators, researchers, courts, advocacy organizations, and other publications have said, with attribution and links to primary sources.

The publication has a dual audience: industry operators, retailers, advocates, researchers, lawyers, regulators, and journalists primarily — plus informed consumers as a secondary audience. The voice is plainspoken, attributive, measured, and curious. It assumes baseline industry literacy and treats readers as intelligent adults.

## Who runs it

**Managing Editor:** Mike Dion (mike@becomeindelible.com / editor@kratomnewstoday.com). Configures the publication's voice and rules, oversees the editorial process, signs off on the workflow.

**Publisher:** Herba Releaf. Founded by Cory and Austin Kilheeney.

The masthead and footer disclose the publisher relationship clearly. Editorial coverage is independent of Herba Releaf's commercial operations.

## How content gets produced

Daily briefings are produced by Herald, a Claude Code skill that researches via the Perplexity API and synthesizes briefings using the publication's voice and rules configuration. Herald produces markdown drafts in `./drafts/` of this repository. A publishing workflow (documented in `publishing-workflow.md`) validates and publishes those drafts.

The full pipeline:

1. Cron on Openclaw machine triggers daily at 8am Eastern
2. Herald runs in this repository, researching the past 24 hours of industry news and producing a draft
3. The publishing workflow validates the draft, moves it from `./drafts/` to `./content/briefings/`, commits, and pushes
4. GitHub Actions runs the Eleventy build and deploys to Cloudways via rsync
5. Site is live with the new briefing
6. Klaviyo API send is triggered to email the briefing to subscribers (this step deferred until week 2-3 after launch)

## Editorial standards (high-level)

Detailed editorial rules live in `rules.md` and are enforced by Herald's check agents. The high-level standards every agent working in this repo should know:

- Every claim is attributed to a source
- The publication does not give medical or legal advice (enforced by Herald's compliance check)
- Editorial content does not link to commercial pages — including Herba Releaf's own
- Em dashes are banned
- "Not X, but Y" contrast-pivot patterns are banned
- Headlines front-load the news, not the analysis
- The publication is BRAM-aware in its framing and link practices

## What's in this repo

Source content in `./content/briefings/` (and eventually `./content/opinions/` when phase 2 launches). Drafts awaiting publish in `./drafts/`. Herald's vector index in `./.herald/` (gitignored). Eleventy site infrastructure: configuration in `.eleventy.js`, templates in `./_includes/`, components in `./_includes/components/`, source files in `./src/`. GitHub Actions workflow in `.github/workflows/`. Agent documentation in `./agent-docs/`.

## Things this site is NOT

- A vendor marketing site or product blog
- A medical information site or health publication
- A legal services site or regulatory advice publication
- A platform for product reviews, recommendations, or rankings
- A comment-driven community forum

Coverage that drifts toward any of these is a violation of the publication's editorial standards.

## Things to watch

- 7-OH coverage in particular requires precision. Three different things often get conflated and the publication distinguishes them carefully: 7-OH as it occurs naturally in trace amounts in raw leaf; 7-OH in concentrated extracts; synthetic 7-OH preparations.
- Herba Releaf is covered like any other industry company. No preferential treatment, no protection from unfavorable coverage if it arises. The credibility of the publication and the defensibility of the disclosed publisher relationship depend on this.
- Payment processor and platform risk (BRAM, banking, ad networks) is a high-velocity beat for this industry. Cover it journalistically; do not create exposure through framing.
