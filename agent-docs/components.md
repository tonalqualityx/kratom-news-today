# Component Library — Kratom News Today

This document is the component library reference for any agent composing or maintaining content for this site. Components are organized into three groups: structural (page chrome), content (article body), and functional (interactive/ad surfaces).

Most components render automatically from frontmatter or template logic. Only two are invoked directly by the synthesis agent in article body markdown: `{% pullquote %}` and `{% update %}`.

## Structural components

These wrap or frame content. Page templates apply them automatically; the synthesis agent does not invoke them directly.

### Site header
- Publication wordmark linking to home
- Primary navigation: Home, Regulation, Business, Science, About
- Search affordance
- Mobile: collapsed nav, sticky header
- Implementation: `_includes/partials/header.njk`

### Site footer
- Publication wordmark and tagline
- Footer nav: About, Contact, Editorial Policy, Corrections, RSS
- Publisher disclosure: "Published by Herba Releaf · Operator of herbapumps.com"
- Copyright line
- Privacy and terms links
- Implementation: `_includes/partials/footer.njk`

### Article meta block
- Beat label (Regulation / Business / Science) — accent color, links to beat page
- Published date in "Month Day, Year" format
- Byline: "Kratom News Today Staff"
- Reading time estimate
- Mobile: stacks vertically
- Implementation: `_includes/components/article-meta.njk`

### Breadcrumbs
- Home > Beat > Article title
- Schema markup for breadcrumb structured data
- Mobile: simplifies to "← Back to [Beat]"
- Implementation: `_includes/components/breadcrumbs.njk`

### Pagination
- Used on beat archive pages and search results
- Previous / Next plus page numbers
- Mobile: prev/next only
- Implementation: `_includes/components/pagination.njk`

## Content components

These are part of the article body. Most are automatic.

### TL;DR block
- Renders automatically at the top of every briefing from the `summary` frontmatter field
- Visually distinct: light gray or accent-tinted background, different typography weight
- The synthesis agent does NOT invoke a shortcode for this — it populates `summary` in frontmatter and the template handles rendering
- Implementation: `_includes/components/tldr.njk`

### Sources section
- Renders automatically at the end of every briefing from the `sources` frontmatter array
- Each source: title (linked), publisher, publication date, short excerpt
- Visually distinct from body
- The synthesis agent populates the `sources` array; the template renders the section
- Implementation: `_includes/components/sources.njk`

### Related coverage rail
- Renders automatically at the end of articles (after Sources) from the `related_briefings` frontmatter array
- Each entry: headline (linked), date, beat label
- The synthesis agent populates `related_briefings`; the template renders the rail
- Implementation: `_includes/components/related-coverage.njk`

### Pull quote (synthesis shortcode)
- Used sparingly to emphasize a key quoted claim from a source
- Larger serif typography, indented, thin accent rule on the left
- Attribution required directly below the quote
- Usage in markdown body:
  ```
  {% pullquote attribution="Mac Haddow, AKA" %}
  The Utah framework is the model the industry needs.
  {% endpullquote %}
  ```
- Implementation: shortcode in `.eleventy.js`

### Update note (synthesis shortcode)
- Used when a briefing is updated after publish
- Appears at the top of the article body, below the TL;DR
- Format: "Updated [date]: [description of what changed]"
- Visually styled with subtle border or background
- Usage in markdown body:
  ```
  {% update date="May 19, 2026" %}
  Corrected the date of the Utah court ruling.
  {% endupdate %}
  ```
- Implementation: shortcode in `.eleventy.js`

### Section heading with rule
- Uses standard markdown H3 (`###`) headings
- CSS adds the thin accent rule and styling
- Used for longer briefings that benefit from internal structure
- Common labels: "What's Being Reported", "Reactions", "What to Watch"
- No shortcode needed — standard markdown works

### Inline source citation
- Uses standard markdown link syntax: `[source name](https://example.com/article)`
- CSS targets these to apply the source-link styling (accent color underline)
- Internal slug references use markdown reference-link syntax: `[link text][slug-of-target-briefing]`
- The build process generates reference link definitions from the `related_briefings` frontmatter array
- No shortcode needed — markdown handles both forms

### Lists and blockquotes
- Standard markdown lists and blockquotes
- CSS handles visual treatment
- No shortcode needed

## Functional components

### Ad slot — sidebar rectangle
- 300x250 or 300x600 standard sizes
- Light gray background, "SPONSORED" label at top
- Used in the sidebar on article pages and beat archives
- Implementation: `_includes/components/ad-sidebar.njk`

### Ad slot — in-feed unit
- Inserted between articles on homepage and beat archive
- Visually distinct from editorial article cards
- "SPONSORED" label
- Implementation: `_includes/components/ad-in-feed.njk`

### Ad slot — end-of-article
- Rectangle ad below article body, before Sources
- "SPONSORED" label, contained styling
- Implementation: `_includes/components/ad-end-of-article.njk`

### Ad slot — header banner
- 1200x250 or similar
- Above the site header on home and major pages
- Hidden on mobile
- "SPONSORED" label
- Implementation: `_includes/components/ad-header.njk`

### Ad slot — footer banner
- 1200x250 or similar
- Above the site footer on all pages
- "SPONSORED" label
- Implementation: `_includes/components/ad-footer.njk`

### Newsletter signup form (custom Klaviyo integration)
- Appears in sidebar (desktop), bottom-sticky CTA (mobile), and end-of-article (all)
- Email input + submit button
- Brief value proposition: "Get the daily kratom industry briefing in your inbox."
- Custom form (not Klaviyo embedded) that POSTs to Klaviyo's API directly:
  ```
  POST https://a.klaviyo.com/client/subscriptions/?company_id=<KLAVIYO_PUBLIC_KEY>
  ```
- Returns confirmation message inline on success
- Implementation: `_includes/components/newsletter-signup.njk` + `src/assets/js/newsletter.js`

### Search interface
- Search input + button in the header
- Results page lists matching briefings with date, beat, headline, TL;DR snippet
- Powered by pre-built JSON search index at `/search-index.json`
- Client-side filtering with vanilla JS
- Implementation: `_includes/components/search-form.njk` + `src/assets/js/search.js`
- Build generates the search index from all briefings during Eleventy build

### Social share buttons
- Compact share affordances for X (Twitter), Facebook, LinkedIn, Reddit, plus copy-link
- Positioned at the end of articles (after body, before Sources)
- No share counts displayed
- No third-party tracking scripts; uses platform-specific share URL patterns
- Implementation: `_includes/components/share-buttons.njk`

### RSS feeds
- `/feed.xml` — full publication feed, all beats combined
- `/regulation/feed.xml` — Regulation beat only
- `/business/feed.xml` — Business beat only
- `/science/feed.xml` — Science beat only
- Formatted for Google News compatibility (includes `<news:news>` extension)
- Auto-discovery via `<link rel="alternate">` tags in head
- Implementation: Eleventy RSS plugin in `.eleventy.js` plus `src/feeds/*.njk` files

### OG image generation
- Per-article generated images at 1200x630
- Article headline rendered in publication's display serif
- Beat label and date in secondary typography
- Same color palette as the site
- Generated at publish time by `scripts/generate-og-image.js`
- Stored in `src/assets/og-images/<slug>.png` (or .jpg)
- Referenced in `og:image` and `twitter:image` meta tags

## Components NOT in the library

These were considered and explicitly rejected for the launch build:

- Featured/hero images (no image budget)
- Stock photography (would look worse than no images)
- Carousels, sliders, animation
- Magazine-style splashy layouts
- Article transitions or scroll effects
- Social-media-styled cards
- Decorative icons
- Dark mode toggle (can add later)
- Comments
- Author photos / author cards (one editor; About page handles bio)
- Topic tag cloud
- "Trending" or "Most read" widgets
- Print stylesheet

If a future need arises for any of these, document the use case and the component can be added. Resist additions that don't serve a clear editorial purpose.
