# Templates — Kratom News Today

This document describes the Eleventy templates that make up the site. Each template defines the layout for one type of page.

## Layout templates

These are Nunjucks files in `_includes/layouts/`.

### `base.njk`
Foundational layout for all pages. Includes:
- HTML doctype, head section
- Meta tags (charset, viewport, OG, Twitter Card, canonical)
- Schema markup (Organization for the publisher, plus page-specific)
- Stylesheet link to `assets/styles.css`
- Favicon and other head metadata
- Site header partial
- Main content slot
- Site footer partial
- Analytics script (if/when configured)

All other layouts extend `base.njk`.

### `briefing.njk`
Layout for individual briefing articles. Extends `base.njk`. Includes:
- Breadcrumbs component
- Article header (headline, article meta block)
- TL;DR component (rendered from `summary` frontmatter)
- Article body content (markdown rendered to HTML)
- Update note component (only if frontmatter has an update note)
- Pull quote components (rendered inline as the synthesis agent placed them)
- Social share buttons component
- End-of-article ad slot
- Sources component (rendered from `sources` frontmatter)
- Related coverage component (rendered from `related_briefings` frontmatter)
- Newsletter signup component
- Schema markup: NewsArticle, with full structured data including author, publisher, datePublished, dateModified, headline, description, image (the OG image), citation array (from sources)

### `opinion.njk` (phase 2 — placeholder for launch)
Layout for opinion pieces. Extends `base.njk`. Will include similar structure to briefing.njk but with author byline support and looser editorial framing. Not active at launch; creates the file as an empty/stub template so the framework is ready.

### `beat.njk`
Layout for beat archive pages (Regulation, Business, Science). Extends `base.njk`. Includes:
- Beat header (beat name, brief description, beat-specific RSS link)
- List of briefings in the beat, newest first
- Pagination
- Sidebar ad slot
- Sidebar newsletter signup

### `archive.njk`
Layout for the full archive page. Extends `base.njk`. Includes:
- Header
- All briefings grouped by month, newest first
- Pagination

### `home.njk`
Layout for the homepage. Extends `base.njk`. Includes:
- Featured (most recent) briefing displayed prominently with full TL;DR visible
- Below: list of next 5-7 recent briefings with date, beat label, headline, TL;DR snippet
- Sidebar: newsletter signup, "more in [beat]" links to each beat page, possibly recent across all beats
- Header banner ad slot
- Footer banner ad slot

### `about.njk` (deprecated in favor of standard page)
Actually, the about page is just a markdown page using `page.njk`. No special layout needed.

### `page.njk`
Layout for static pages (About, Contact, Editorial Policy, Corrections). Extends `base.njk`. Includes:
- Simple content area
- Sidebar with newsletter signup
- Standard breadcrumbs

### `search.njk`
Layout for the search results page. Extends `base.njk`. Includes:
- Search input at top
- Results area populated by client-side JS
- Brief explanation of search behavior

## Data files

These are JSON/JavaScript files in `_data/` that templates can reference globally.

### `site.json`
```json
{
  "title": "Kratom News Today",
  "tagline": "The daily briefing on kratom — regulation, science, business, and what you need to know.",
  "url": "https://kratomnewstoday.com",
  "author": "Kratom News Today Staff",
  "managingEditor": "Mike Dion",
  "publisher": {
    "name": "Herba Releaf",
    "url": "https://herbapumps.com",
    "address": {
      "street": "281 West 6th Street",
      "city": "Wyoming",
      "state": "PA",
      "zip": "18644"
    }
  },
  "beats": [
    {"slug": "regulation", "name": "Regulation", "description": "Federal action, state legislation, court decisions, enforcement."},
    {"slug": "business", "name": "Business", "description": "Companies, markets, retail and wholesale trends, financial news."},
    {"slug": "science", "name": "Science", "description": "Peer-reviewed research, NIH-funded studies, university programs, harm reduction research."}
  ],
  "email": {
    "editor": "editor@kratomnewstoday.com",
    "advertising": "advertising@kratomnewstoday.com",
    "newsletter": "briefing@kratomnewstoday.com"
  }
}
```

### `klaviyo.json`
```json
{
  "publicApiKey": "<KLAVIYO_PUBLIC_KEY>",
  "listId": "<KLAVIYO_LIST_ID>"
}
```

(These values get set after Klaviyo configuration. May be in environment variables that the build reads.)

## Content collections

Defined in `.eleventy.js`. Eleventy auto-builds these:

### `briefings`
- Source: `./content/briefings/*.md`
- Sorted by date descending
- Used in: home, beat pages, archive, RSS feeds, search index

### `briefingsByBeat` (computed)
- One collection per beat tag (regulation, business, science)
- Filtered from `briefings` by the primary beat tag
- Used in: beat pages, beat RSS feeds

### `opinions` (phase 2 — placeholder)
- Source: `./content/opinions/*.md`
- Empty at launch
- Used in: opinion section pages (phase 2)

## Frontmatter reference

Every briefing in `./content/briefings/` has YAML frontmatter following this schema:

```yaml
---
title: "Headline of the briefing"
slug: "url-slug-kebab-case"
date: 2026-05-19
generated_at: 2026-05-19T07:00:00Z
type: briefing
summary: "Two or three sentence TL;DR that stands alone."
tags: [regulation, utah, 7oh]
entities: ["FDA", "Utah", "American Kratom Association"]
sources:
  - title: "Source article title"
    url: "https://example.com/article"
    publisher: "Publication name"
    published: 2026-05-18
    excerpt: "Brief excerpt or summary"
related_briefings:
  - 2026-05-08-utah-court-ruling-kratom
  - 2026-04-22-utah-kratom-bill-signed
layout: briefing
herald_version: "v2.1"
herald_options_snapshot:
  model: sonar-pro
  time_window_hours: 24
  source_count_target: 8
  embedding_model: text-embedding-3-small
---
```

The first beat in `tags` is treated as the primary beat for routing and display.
