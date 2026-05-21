const pluginRss = require("@11ty/eleventy-plugin-rss");
const markdownIt = require("markdown-it");
const markdownItAttrs = require("markdown-it-attrs");

module.exports = function (eleventyConfig) {
  // ---------------------------------------------------------------------------
  // Plugins
  // ---------------------------------------------------------------------------
  eleventyConfig.addPlugin(pluginRss);

  // ---------------------------------------------------------------------------
  // Markdown library
  // ---------------------------------------------------------------------------
  const mdOptions = {
    html: true,
    breaks: false,
    linkify: true,
  };

  const mdLib = markdownIt(mdOptions).use(markdownItAttrs);
  eleventyConfig.setLibrary("md", mdLib);

  // ---------------------------------------------------------------------------
  // Preprocessor — internal link resolution
  // ---------------------------------------------------------------------------
  // Appends reference-style link definitions for every slug listed in
  // `related_briefings` frontmatter so authors can write [text][slug].
  try {
    eleventyConfig.addPreprocessor("internalLinks", "md", (data, content) => {
      if (data.related_briefings && Array.isArray(data.related_briefings)) {
        const linkDefs = data.related_briefings
          .map((slug) => `[${slug}]: /briefings/${slug}/`)
          .join("\n");
        return content + "\n\n" + linkDefs;
      }
      return content;
    });
  } catch {
    // Fallback for Eleventy versions that lack addPreprocessor —
    // use a transform on the rendered HTML to warn at build time.
    console.log(
      "[eleventy] addPreprocessor not available — internal link resolution disabled. Upgrade to Eleventy 3.x for full support."
    );
  }

  // ---------------------------------------------------------------------------
  // Collections
  // ---------------------------------------------------------------------------
  eleventyConfig.addCollection("briefings", (collectionApi) => {
    return collectionApi
      .getFilteredByGlob("./content/briefings/*.md")
      .sort((a, b) => b.date - a.date);
  });

  eleventyConfig.addCollection("regulation", (collectionApi) => {
    return collectionApi
      .getFilteredByGlob("./content/briefings/*.md")
      .filter(
        (item) => item.data.tags && item.data.tags.includes("regulation")
      )
      .sort((a, b) => b.date - a.date);
  });

  eleventyConfig.addCollection("business", (collectionApi) => {
    return collectionApi
      .getFilteredByGlob("./content/briefings/*.md")
      .filter((item) => item.data.tags && item.data.tags.includes("business"))
      .sort((a, b) => b.date - a.date);
  });

  eleventyConfig.addCollection("science", (collectionApi) => {
    return collectionApi
      .getFilteredByGlob("./content/briefings/*.md")
      .filter((item) => item.data.tags && item.data.tags.includes("science"))
      .sort((a, b) => b.date - a.date);
  });

  // ---------------------------------------------------------------------------
  // Shortcodes
  // ---------------------------------------------------------------------------
  eleventyConfig.addPairedShortcode("pullquote", (content, attribution) => {
    return `<aside class="pullquote"><blockquote>${content.trim()}</blockquote>${
      attribution ? `<cite>${attribution}</cite>` : ""
    }</aside>`;
  });

  eleventyConfig.addPairedShortcode("update", (content, date) => {
    return `<aside class="update-note"><strong>Updated ${date}:</strong> ${content.trim()}</aside>`;
  });

  // ---------------------------------------------------------------------------
  // Filters
  // ---------------------------------------------------------------------------

  // "May 19, 2026"
  eleventyConfig.addFilter("dateFormat", (dateObj) => {
    const d = dateObj instanceof Date ? dateObj : new Date(dateObj);
    return d.toLocaleDateString("en-US", {
      year: "numeric",
      month: "long",
      day: "numeric",
      timeZone: "UTC",
    });
  });

  // ISO 8601
  eleventyConfig.addFilter("dateISO", (dateObj) => {
    const d = dateObj instanceof Date ? dateObj : new Date(dateObj);
    return d.toISOString();
  });

  // Truncate to N characters with ellipsis
  eleventyConfig.addFilter("truncate", (str, len) => {
    if (!str) return "";
    if (str.length <= len) return str;
    return str.slice(0, len).trimEnd() + "\u2026";
  });

  // First 200 chars of content, HTML stripped
  eleventyConfig.addFilter("excerpt", (content) => {
    if (!content) return "";
    const stripped = content.replace(/<[^>]+>/g, "").trim();
    if (stripped.length <= 200) return stripped;
    return stripped.slice(0, 200).trimEnd() + "\u2026";
  });

  // Kebab-case slugify
  eleventyConfig.addFilter("slugify", (str) => {
    if (!str) return "";
    return str
      .toString()
      .toLowerCase()
      .trim()
      .replace(/[\s_]+/g, "-")
      .replace(/[^\w-]+/g, "")
      .replace(/--+/g, "-")
      .replace(/^-+|-+$/g, "");
  });

  // Reading time — words / 230, rounded up, minimum 1 min
  eleventyConfig.addFilter("readingTime", (content) => {
    if (!content) return "1 min read";
    const stripped = content.replace(/<[^>]+>/g, "");
    const words = stripped.split(/\s+/).filter(Boolean).length;
    const minutes = Math.max(1, Math.ceil(words / 230));
    return `${minutes} min read`;
  });

  // Extract first beat tag from a tags array
  eleventyConfig.addFilter("getBeat", (tags) => {
    if (!tags || !Array.isArray(tags)) return null;
    const beats = ["regulation", "business", "science"];
    return tags.find((t) => beats.includes(t)) || null;
  });

  // RFC 822 date format (for RSS feeds)
  eleventyConfig.addFilter("dateRfc822", (dateObj) => {
    const d = dateObj instanceof Date ? dateObj : new Date(dateObj);
    return d.toUTCString();
  });

  // Check if a date is within N days of now (for news sitemap)
  eleventyConfig.addFilter("isRecentDays", (dateObj, days) => {
    const d = dateObj instanceof Date ? dateObj : new Date(dateObj);
    const cutoff = Date.now() - (days * 24 * 60 * 60 * 1000);
    return d.getTime() >= cutoff;
  });

  // Nunjucks `head` filter — return first N items from array
  eleventyConfig.addFilter("head", (array, n) => {
    if (!array || !Array.isArray(array)) return [];
    return array.slice(0, n);
  });

  // Nunjucks `slice` filter (offset, count) — for skipping items
  eleventyConfig.addFilter("slice", (array, start, count) => {
    if (!array || !Array.isArray(array)) return [];
    return array.slice(start, count ? start + count : undefined);
  });

  // Prepend site URL to a relative path (for RSS)
  eleventyConfig.addFilter("absoluteUrl", (url, base) => {
    if (!url) return url;
    // If a base is provided use it; otherwise fall back to site metadata
    // The RSS plugin also provides this, but having our own is useful.
    try {
      return new URL(url, base).href;
    } catch {
      return (base || "") + url;
    }
  });

  // ---------------------------------------------------------------------------
  // Layout aliases — so frontmatter can use short names
  // ---------------------------------------------------------------------------
  eleventyConfig.addLayoutAlias("briefing", "layouts/briefing.njk");
  eleventyConfig.addLayoutAlias("opinion", "layouts/opinion.njk");
  eleventyConfig.addLayoutAlias("page", "layouts/page.njk");
  eleventyConfig.addLayoutAlias("home", "layouts/home.njk");
  eleventyConfig.addLayoutAlias("beat", "layouts/beat.njk");
  eleventyConfig.addLayoutAlias("archive", "layouts/archive.njk");
  eleventyConfig.addLayoutAlias("search", "layouts/search.njk");

  // ---------------------------------------------------------------------------
  // Passthrough copies
  // ---------------------------------------------------------------------------
  eleventyConfig.addPassthroughCopy("src/assets");

  // ---------------------------------------------------------------------------
  // Watch targets
  // ---------------------------------------------------------------------------
  eleventyConfig.addWatchTarget("./content/");

  // ---------------------------------------------------------------------------
  // Ignores
  // ---------------------------------------------------------------------------
  eleventyConfig.ignores.add("node_modules/**");
  eleventyConfig.ignores.add("scripts/**");
  eleventyConfig.ignores.add("drafts/**");
  eleventyConfig.ignores.add("agent-docs/**");
  eleventyConfig.ignores.add("README.md");

  // ---------------------------------------------------------------------------
  // Directory config
  // ---------------------------------------------------------------------------
  return {
    dir: {
      input: ".",
      includes: "_includes",
      data: "_data",
      output: "_site",
    },
    markdownTemplateEngine: "njk",
    htmlTemplateEngine: "njk",
  };
};
