"use strict";
// Build-time UTM stamping for every outbound link to the Herba store.
//
// Identical copies live in kratom-news-today/lib/ and herbaldream/lib/; change
// both together. Registered as an Eleventy transform in .eleventy.js, so it
// runs on every rendered HTML page, including posts the publishers write
// later. Nobody hand-writes utm_* on a store link: whatever is there is
// replaced with the one convention below so GA4 on herbapumps.com can tie a
// session (and its purchases) back to the site, page and placement.
//
//   utm_source   = the editorial site (passed in by .eleventy.js)
//   utm_medium   = referral                (GA4 channel group: Referral)
//   utm_campaign = the page URL as a slug  (home, kava-tea, briefings-foo)
//   utm_content  = data-utm-content on the <a>, else "in-article"
//
// Two retired store paths are rewritten to the kava category: /collections/kava
// and /kava both 301 to one sampler bundle on the store, not to the category.

const STORE_HOSTS = new Set(["herbapumps.com", "www.herbapumps.com"]);
const PATH_FIXES = {
  "/collections/kava": "/product-category/kava/",
  "/kava": "/product-category/kava/",
};
const DEFAULT_PLACEMENT = "in-article";

function campaignFromPage(page) {
  const url = (page && page.url) || "/";
  const slug = url.replace(/^\/+|\/+$/g, "").replace(/\//g, "-");
  return slug || "home";
}

function attr(tag, name) {
  const m = tag.match(new RegExp("\\b" + name + "\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)')", "i"));
  if (!m) return null;
  return { full: m[0], value: m[1] !== undefined ? m[1] : m[2] };
}

function stampStoreLink(tag, { source, campaign }) {
  const href = attr(tag, "href");
  if (!href) return tag;
  let u;
  try {
    u = new URL(href.value.replace(/&amp;/g, "&"));
  } catch {
    return tag; // relative, mailto:, tel:, anchors: not ours
  }
  if (!STORE_HOSTS.has(u.hostname.toLowerCase())) return tag;

  const bare = u.pathname.replace(/\/+$/, "");
  if (PATH_FIXES[bare]) u.pathname = PATH_FIXES[bare];

  const placement = attr(tag, "data-utm-content");
  u.searchParams.set("utm_source", source);
  u.searchParams.set("utm_medium", "referral");
  u.searchParams.set("utm_campaign", campaign);
  u.searchParams.set("utm_content", (placement && placement.value) || DEFAULT_PLACEMENT);

  const out = u.href.replace(/&/g, "&amp;");
  return tag.replace(href.full, `href="${out}"`);
}

/**
 * Returns an Eleventy transform. Usage in .eleventy.js:
 *   eleventyConfig.addTransform("utmLinks", require("./lib/utm-links")({ source: "kratomnewstoday" }));
 */
module.exports = function utmLinks({ source }) {
  if (!source) throw new Error("utm-links: source is required");
  return function (content) {
    const out = this.page && this.page.outputPath;
    if (typeof content !== "string" || !out || !out.endsWith(".html")) return content;
    const campaign = campaignFromPage(this.page);
    return content.replace(/<a\b[^>]*>/gi, (tag) => stampStoreLink(tag, { source, campaign }));
  };
};

module.exports.stampStoreLink = stampStoreLink;
module.exports.campaignFromPage = campaignFromPage;
