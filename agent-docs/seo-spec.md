# SEO / AEO / GEO Spec — Kratom News Today

This document specifies the search, answer engine, and generative engine optimization requirements baked into the site. All requirements should hold by default through the templates and build process; this doc exists so any agent maintaining the site knows what NOT to break.

## What we're optimizing for

**SEO (traditional search):** Google ranking on kratom-related queries, particularly regulation-related and news-related queries where freshness is rewarded. Long-term goal: rank as a credible source on the topic.

**AEO (answer engine optimization):** Being cited as a source by Perplexity, ChatGPT search, Google AI Overviews, Claude, and other generative answer engines. Requires clear factual claims with attribution, well-structured content, citation markup, content that's easy to extract and attribute.

**GEO (generative engine optimization):** Closely related to AEO. Emphasis on being a quotable, attributable source — clean factual statements, named entities marked up, source authority signals.

The publication's overall positioning ("report what is being reported, attribute everything, link to primary sources") aligns naturally with AEO/GEO requirements. The technical work is mostly making sure that positioning is also machine-readable.

## On-page requirements (per briefing)

### Headline
- Front-loads the news. "FDA Recommends Schedule I Classification for 7-Hydroxymitragynine" not "What FDA's Move Means."
- Specific, factual, no clickbait.
- 50-70 characters target (mobile-friendly, fits in search snippets).

### TL;DR / Summary
- 2-3 sentences. Standalone. Quotable.
- Becomes the `og:description` and `twitter:description`.
- Becomes the `description` field in NewsArticle schema.
- Optimized for being pulled by AI answer engines as a quotable summary.

### Body structure
- Clear lead paragraph (the news, with attribution).
- Logical progression: what happened, why it matters, reactions, what's next.
- Section headings (H3) for longer briefings.
- Attribution density throughout — every factual claim sourced.

### Internal linking
- Reference-style markdown links to other briefings using slugs as keys.
- Resolved at build time from the `related_briefings` frontmatter array.
- Builds topical authority by showing Google we have substantive coverage of related stories.

### External linking
- Primary sources linked at first mention.
- Authoritative sources preferred (.gov, peer-reviewed journals, established journalism).
- `rel="noopener"` on all external links (standard practice).
- Internal links no rel attributes.

## Schema markup

### Per-briefing schema (NewsArticle)

Every briefing renders a JSON-LD `NewsArticle` block in the head:

```json
{
  "@context": "https://schema.org",
  "@type": "NewsArticle",
  "headline": "<title>",
  "description": "<summary>",
  "image": "<og:image url>",
  "datePublished": "<ISO 8601 date>",
  "dateModified": "<ISO 8601 date or datePublished if no update>",
  "author": {
    "@type": "Organization",
    "name": "Kratom News Today Staff",
    "url": "https://kratomnewstoday.com"
  },
  "publisher": {
    "@type": "Organization",
    "name": "Kratom News Today",
    "logo": {
      "@type": "ImageObject",
      "url": "https://kratomnewstoday.com/assets/logo.png"
    }
  },
  "mainEntityOfPage": {
    "@type": "WebPage",
    "@id": "<canonical URL>"
  },
  "articleSection": "<primary beat>",
  "keywords": "<comma-separated tags>",
  "citation": [
    // Array of CreativeWork or NewsArticle objects, one per source
    {
      "@type": "CreativeWork",
      "name": "<source title>",
      "url": "<source url>",
      "publisher": "<source publisher>",
      "datePublished": "<source published date>"
    }
  ]
}
```

### Site-wide schema (Organization)

Renders once on every page. Establishes the publisher:

```json
{
  "@context": "https://schema.org",
  "@type": "Organization",
  "name": "Kratom News Today",
  "url": "https://kratomnewstoday.com",
  "logo": "https://kratomnewstoday.com/assets/logo.png",
  "publishingPrinciples": "https://kratomnewstoday.com/about",
  "parentOrganization": {
    "@type": "Organization",
    "name": "Herba Releaf",
    "url": "https://herbapumps.com"
  }
}
```

### Per-page schema (BreadcrumbList)

Renders on briefing pages with the breadcrumb trail:

```json
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    {"@type": "ListItem", "position": 1, "name": "Home", "item": "<home url>"},
    {"@type": "ListItem", "position": 2, "name": "<beat>", "item": "<beat url>"},
    {"@type": "ListItem", "position": 3, "name": "<title>", "item": "<canonical>"}
  ]
}
```

## Meta tags (head)

Every page:
- `<title>` — page title, includes site name
- `<meta name="description">` — page-specific description
- `<link rel="canonical">` — canonical URL
- `<link rel="alternate" type="application/rss+xml" href="/feed.xml">`
- Beat pages also include `<link rel="alternate">` for the beat-specific feed
- `<meta name="robots" content="index, follow">` — default; suppressed for utility pages

OpenGraph:
- `og:type` — `article` for briefings, `website` for other pages
- `og:title`
- `og:description`
- `og:url`
- `og:image` — the generated per-article OG image, 1200x630
- `og:site_name` — "Kratom News Today"

Twitter Card:
- `twitter:card` — `summary_large_image`
- `twitter:title`
- `twitter:description`
- `twitter:image`
- `twitter:site` — Twitter handle if/when the publication has one

NewsArticle specifics:
- `article:published_time`
- `article:modified_time`
- `article:section` — primary beat
- `article:tag` — one tag per `<meta>` element

## Sitemaps

### Main sitemap
At `/sitemap.xml`. Lists all pages: home, beats, archive, about, all briefings. Updated on every build.

### News sitemap
At `/news-sitemap.xml`. Lists only briefings published in the last 2 days (Google News requirement — older content shouldn't appear in news sitemap). Uses the `<news:news>` extension. Critical for Google News inclusion.

```xml
<url>
  <loc>https://kratomnewstoday.com/briefings/2026-05-19-fda-7oh-decision/</loc>
  <news:news>
    <news:publication>
      <news:name>Kratom News Today</news:name>
      <news:language>en</news:language>
    </news:publication>
    <news:publication_date>2026-05-19T07:00:00Z</news:publication_date>
    <news:title>FDA Recommends Schedule I Classification for 7-Hydroxymitragynine</news:title>
  </news:news>
</url>
```

### robots.txt
Standard robots.txt at `/robots.txt`:

```
User-agent: *
Allow: /

Sitemap: https://kratomnewstoday.com/sitemap.xml
Sitemap: https://kratomnewstoday.com/news-sitemap.xml
```

No paths blocked. The site is fully crawlable.

## RSS feeds

Both for general syndication and for Google News compatibility.

### Full feed
At `/feed.xml`. All briefings, newest first, limited to most recent 50.

### Beat feeds
At `/regulation/feed.xml`, `/business/feed.xml`, `/science/feed.xml`. Filtered to the beat, same format and limits.

All feeds:
- Include full content of each briefing (not just summaries) — better for syndication
- Include media:content for the OG image where available
- Conform to RSS 2.0 spec
- Include `<atom:link>` self-reference

## Performance requirements

Static HTML with Cloudflare in front. The site should be very fast by default. Specific requirements:

- LCP (Largest Contentful Paint) under 2 seconds
- CLS (Cumulative Layout Shift) effectively zero (text-based layouts are easy here)
- INP (Interaction to Next Paint) under 200ms
- Total page weight under 200KB excluding the OG image (which is per-article)

Cloudflare cache settings:
- Cache HTML pages for short windows (5-15 minutes) so new briefings appear quickly
- Cache static assets (CSS, JS, fonts, images) aggressively (months)
- Use Cloudflare's automatic minification

## What's intentionally not optimized

- **No social media buttons triggering iframe loads.** The share buttons are simple anchors to platform URLs; no embedded SDK weight.
- **No Google Analytics by default.** Will add if/when Mike provides credentials. Privacy-friendly analytics is preferred (Plausible, Fathom) if budget allows.
- **No A/B testing framework.** Not needed at this scale.
- **No real-time updates.** Static site rebuilds on every push.
