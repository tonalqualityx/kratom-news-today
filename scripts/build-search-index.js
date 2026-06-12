const fs = require('fs');
const path = require('path');
const matter = require('gray-matter');

// Each content type indexed for search: source directory + URL prefix.
const CONTENT_DIRS = [
  { dir: path.join(__dirname, '..', 'content', 'briefings'), urlPrefix: '/briefings/' },
  { dir: path.join(__dirname, '..', 'content', 'reports'), urlPrefix: '/reports/' },
];
const OUTPUT_PATH = path.join(__dirname, '..', '_site', 'search-index.json');

// Ensure output directory exists
const outputDir = path.dirname(OUTPUT_PATH);
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

const index = CONTENT_DIRS.flatMap(({ dir, urlPrefix }) => {
  if (!fs.existsSync(dir)) return [];
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.md'));

  return files.map(file => {
    const raw = fs.readFileSync(path.join(dir, file), 'utf8');
    const parsed = matter(raw);
    const data = parsed.data;
    const body = parsed.content || '';

    const VALID_BEATS = ['regulation', 'business', 'science'];
    const beat = (data.tags || []).find(t => VALID_BEATS.includes(t)) || '';

    return {
      slug: data.slug || '',
      url: urlPrefix + (data.slug || '') + '/',
      title: data.title || '',
      summary: data.summary || '',
      date: data.date ? new Date(data.date).toISOString().split('T')[0] : '',
      beat: beat,
      tags: data.tags || [],
      excerpt: body.replace(/[#*\[\]()>_`]/g, '').substring(0, 200)
    };
  });
}).sort((a, b) => b.date.localeCompare(a.date));

fs.writeFileSync(OUTPUT_PATH, JSON.stringify(index, null, 2));
console.log(`Search index built with ${index.length} entries.`);
