const fs = require('fs');
const path = require('path');

// Parse command line arguments
const args = {};
process.argv.slice(2).forEach(arg => {
  const [key, ...valueParts] = arg.replace(/^--/, '').split('=');
  args[key] = valueParts.join('=');
});

const { slug, title, beat, date } = args;

if (!slug || !title) {
  console.error('Usage: node generate-og-image.js --slug=<slug> --title="<title>" --beat=<beat> --date=<date>');
  process.exit(1);
}

async function generate() {
  let sharp;
  try {
    sharp = require('sharp');
  } catch (e) {
    console.error('Sharp not installed. Run npm install first.');
    process.exit(1);
  }

  const outputDir = path.join(__dirname, '..', 'src', 'assets', 'og-images');
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  const outputPath = path.join(outputDir, slug + '.png');

  // Wrap title text
  const maxCharsPerLine = 35;
  const words = title.split(' ');
  const lines = [];
  let currentLine = '';

  words.forEach(word => {
    if ((currentLine + ' ' + word).trim().length <= maxCharsPerLine) {
      currentLine = (currentLine + ' ' + word).trim();
    } else {
      if (currentLine) lines.push(currentLine);
      currentLine = word;
    }
  });
  if (currentLine) lines.push(currentLine);

  // Limit to 4 lines
  const displayLines = lines.slice(0, 4);
  if (lines.length > 4) {
    displayLines[3] = displayLines[3] + '...';
  }

  const titleY = 220;
  const lineHeight = 60;

  const titleTextSvg = displayLines.map((line, i) => {
    const escaped = line.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    return `<text x="60" y="${titleY + (i * lineHeight)}" font-family="Georgia, serif" font-size="44" font-weight="bold" fill="#FFFFFF">${escaped}</text>`;
  }).join('\n    ');

  const beatLabel = (beat || '').toUpperCase();
  const dateLabel = date || '';

  const svg = `
  <svg width="1200" height="630" xmlns="http://www.w3.org/2000/svg">
    <rect width="1200" height="630" fill="#1F5F3F"/>
    <rect x="0" y="0" width="1200" height="6" fill="#FFFFFF" opacity="0.3"/>

    <!-- Publication name -->
    <text x="60" y="80" font-family="Georgia, serif" font-size="24" fill="#FFFFFF" opacity="0.8">Kratom News Today</text>

    <!-- Divider -->
    <line x1="60" y1="110" x2="300" y2="110" stroke="#FFFFFF" stroke-width="2" opacity="0.4"/>

    <!-- Beat label -->
    <text x="60" y="160" font-family="Arial, sans-serif" font-size="16" font-weight="bold" fill="#FFFFFF" opacity="0.7" letter-spacing="3">${beatLabel}</text>

    <!-- Title -->
    ${titleTextSvg}

    <!-- Date -->
    <text x="60" y="580" font-family="Arial, sans-serif" font-size="18" fill="#FFFFFF" opacity="0.6">${dateLabel}</text>
  </svg>`;

  try {
    await sharp(Buffer.from(svg)).png().toFile(outputPath);
    console.log('OG image generated: ' + outputPath);
  } catch (err) {
    console.error('Failed to generate OG image:', err.message);
    process.exit(1);
  }
}

generate();
