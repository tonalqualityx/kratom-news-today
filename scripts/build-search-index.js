const fs = require('fs');
const path = require('path');
const matter = require('gray-matter');

const BRIEFINGS_DIR = path.join(__dirname, '..', 'content', 'briefings');
const OUTPUT_PATH = path.join(__dirname, '..', '_site', 'search-index.json');

// Ensure output directory exists
const outputDir = path.dirname(OUTPUT_PATH);
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

if (!fs.existsSync(BRIEFINGS_DIR)) {
  fs.writeFileSync(OUTPUT_PATH, '[]');
  console.log('No briefings directory. Wrote empty search index.');
  process.exit(0);
}

const files = fs.readdirSync(BRIEFINGS_DIR).filter(f => f.endsWith('.md'));

const index = files.map(file => {
  const raw = fs.readFileSync(path.join(BRIEFINGS_DIR, file), 'utf8');
  const parsed = matter(raw);
  const data = parsed.data;
  const body = parsed.content || '';

  const VALID_BEATS = ['regulation', 'business', 'science'];
  const beat = (data.tags || []).find(t => VALID_BEATS.includes(t)) || '';

  return {
    slug: data.slug || '',
    url: '/briefings/' + (data.slug || '') + '/',
    title: data.title || '',
    summary: data.summary || '',
    date: data.date ? new Date(data.date).toISOString().split('T')[0] : '',
    beat: beat,
    tags: data.tags || [],
    excerpt: body.replace(/[#*\[\]()>_`]/g, '').substring(0, 200)
  };
}).sort((a, b) => b.date.localeCompare(a.date));

fs.writeFileSync(OUTPUT_PATH, JSON.stringify(index, null, 2));
console.log(`Search index built with ${index.length} entries.`);
