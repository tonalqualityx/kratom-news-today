// Preview builds only (KNT_PREVIEW=1): render unpublished drafts and put them in
// collections. Computed data beats front matter, so the draft lines in each
// article stay untouched. Without the flag this file adds nothing.
module.exports = process.env.KNT_PREVIEW === "1"
  ? {
      eleventyComputed: {
        draft: () => false,
        eleventyExcludeFromCollections: () => false,
        permalink: (data) => `/industry-perspective/${data.slug}/index.html`,
      },
    }
  : {};
