const fs = require('fs');
const path = require('path');
const matter = require('gray-matter');

const BRIEFINGS_DIR = path.join(__dirname, '..', 'content', 'briefings');
const OG_DIR = path.join(__dirname, '..', 'src', 'assets', 'og-images');
const generateOgImage = path.join(__dirname, 'generate-og-image.js');

if (!fs.existsSync(BRIEFINGS_DIR)) {
  console.log('No briefings directory. Skipping OG image generation.');
  process.exit(0);
}

if (!fs.existsSync(OG_DIR)) {
  fs.mkdirSync(OG_DIR, { recursive: true });
}

const files = fs.readdirSync(BRIEFINGS_DIR).filter(f => f.endsWith('.md'));
const BEAT_PRIORITY = ['regulation', 'business', 'science'];

let generated = 0;
let skipped = 0;

const { execFileSync } = require('child_process');

files.forEach(file => {
  const raw = fs.readFileSync(path.join(BRIEFINGS_DIR, file), 'utf8');
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
