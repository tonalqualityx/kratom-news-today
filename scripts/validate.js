const fs = require('fs');
const path = require('path');
const matter = require('gray-matter');

const BRIEFINGS_DIR = path.join(__dirname, '..', 'content', 'briefings');
const REQUIRED_FIELDS = ['title', 'slug', 'date', 'summary', 'tags', 'sources', 'related_briefings'];
const VALID_BEATS = ['regulation', 'business', 'science'];

let errors = [];
let fileCount = 0;

// Check if briefings directory exists
if (!fs.existsSync(BRIEFINGS_DIR)) {
  console.log('No briefings directory found. Skipping validation.');
  process.exit(0);
}

const files = fs.readdirSync(BRIEFINGS_DIR).filter(f => f.endsWith('.md'));

if (files.length === 0) {
  console.log('No briefing files found. Skipping validation.');
  process.exit(0);
}

// Collect all slugs for cross-reference checking
const allSlugs = new Set();
const fileDataMap = new Map();

files.forEach(file => {
  const filePath = path.join(BRIEFINGS_DIR, file);
  const raw = fs.readFileSync(filePath, 'utf8');

  let parsed;
  try {
    parsed = matter(raw);
  } catch (e) {
    errors.push(`${file}: Failed to parse YAML frontmatter: ${e.message}`);
    return;
  }

  fileDataMap.set(file, parsed.data);
  if (parsed.data.slug) {
    allSlugs.add(parsed.data.slug);
  }
});

// Validate each file
fileDataMap.forEach((data, file) => {
  fileCount++;

  // Check required fields
  REQUIRED_FIELDS.forEach(field => {
    if (data[field] === undefined || data[field] === null || data[field] === '') {
      errors.push(`${file}: Missing required field "${field}"`);
    }
  });

  // Check slug matches filename
  if (data.slug) {
    const expectedSlug = file.replace(/^\d{4}-\d{2}-\d{2}-/, '').replace(/\.md$/, '');
    if (data.slug !== expectedSlug) {
      errors.push(`${file}: Slug "${data.slug}" does not match filename (expected "${expectedSlug}")`);
    }
  }

  // Check tags include at least one beat
  if (data.tags && Array.isArray(data.tags)) {
    const hasBeat = data.tags.some(t => VALID_BEATS.includes(t));
    if (!hasBeat) {
      errors.push(`${file}: Tags must include at least one beat (${VALID_BEATS.join(', ')})`);
    }
  }

  // Check sources
  if (data.sources && Array.isArray(data.sources)) {
    data.sources.forEach((source, i) => {
      if (!source.title) errors.push(`${file}: Source ${i + 1} missing "title"`);
      if (!source.url) errors.push(`${file}: Source ${i + 1} missing "url"`);
      if (!source.publisher) errors.push(`${file}: Source ${i + 1} missing "publisher"`);
    });
  }

  // Check related_briefings resolve
  if (data.related_briefings && Array.isArray(data.related_briefings)) {
    data.related_briefings.forEach(slug => {
      if (!allSlugs.has(slug)) {
        // Warn but don't fail — the related briefing might not exist yet
        console.warn(`${file}: Related briefing "${slug}" not found in current collection (may be published later)`);
      }
    });
  }

  // Check body is non-empty
  const parsed = matter(fs.readFileSync(path.join(BRIEFINGS_DIR, file), 'utf8'));
  if (!parsed.content || parsed.content.trim().length === 0) {
    errors.push(`${file}: Body content is empty`);
  }
});

console.log(`Validated ${fileCount} briefing file(s).`);

if (errors.length > 0) {
  console.error('\nValidation errors:');
  errors.forEach(e => console.error(`  - ${e}`));
  process.exit(1);
} else {
  console.log('All validations passed.');
  process.exit(0);
}
