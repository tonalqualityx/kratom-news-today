const fs = require('fs');
const path = require('path');
const matter = require('gray-matter');

const CONTENT_DIRS = [
  path.join(__dirname, '..', 'content', 'briefings'),
  path.join(__dirname, '..', 'content', 'reports'),
];
const OG_DIR = path.join(__dirname, '..', 'src', 'assets', 'og-images');
const generateOgImage = path.join(__dirname, 'generate-og-image.js');

if (!fs.existsSync(OG_DIR)) {
  fs.mkdirSync(OG_DIR, { recursive: true });
}

const files = CONTENT_DIRS.flatMap(dir =>
  fs.existsSync(dir)
    ? fs.readdirSync(dir).filter(f => f.endsWith('.md')).map(f => path.join(dir, f))
    : []
);
const BEAT_PRIORITY = ['regulation', 'business', 'science'];

let generated = 0;
let skipped = 0;

const { execFileSync } = require('child_process');

files.forEach(file => {
  const raw = fs.readFileSync(file, 'utf8');
  let parsed;
  try {
    parsed = matter(raw);
  } catch {
    console.warn(`Skipping ${file}: could not parse frontmatter`);
    return;
  }

  const { slug, title, tags, date } = parsed.data;
  if (!slug || !title) {
    console.warn(`Skipping ${file}: missing slug or title`);
    return;
  }

  const outPath = path.join(OG_DIR, `${slug}.png`);
  if (fs.existsSync(outPath)) {
    skipped++;
    return;
  }

  const beat = (tags || []).find(t => BEAT_PRIORITY.includes(t)) || '';
  const dateStr = date ? new Date(date).toLocaleDateString('en-US', {
    year: 'numeric', month: 'long', day: 'numeric', timeZone: 'UTC'
  }) : '';

  try {
    execFileSync('node', [
      generateOgImage,
      `--slug=${slug}`,
      `--title=${title}`,
      `--beat=${beat}`,
      `--date=${dateStr}`
    ], { stdio: 'pipe' });
    generated++;
  } catch (err) {
    console.error(`Failed to generate OG image for ${file}: ${err.message}`);
  }
});

console.log(`OG images: ${generated} generated, ${skipped} already existed.`);
