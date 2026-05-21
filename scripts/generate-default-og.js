const fs = require('fs');
const path = require('path');

async function generateDefaultOG() {
  let sharp;
  try {
    sharp = require('sharp');
  } catch (e) {
    console.error('Sharp not installed. Run npm install first.');
    process.exit(1);
  }

  const outputPath = path.join(__dirname, '..', 'src', 'assets', 'default-og.png');

  const svg = `
  <svg width="1200" height="630" xmlns="http://www.w3.org/2000/svg">
    <rect width="1200" height="630" fill="#1F5F3F"/>
    <rect x="0" y="0" width="1200" height="6" fill="#FFFFFF" opacity="0.3"/>

    <text x="600" y="260" font-family="Georgia, serif" font-size="52" font-weight="bold" fill="#FFFFFF" text-anchor="middle">Kratom News Today</text>

    <line x1="400" y1="300" x2="800" y2="300" stroke="#FFFFFF" stroke-width="2" opacity="0.4"/>

    <text x="600" y="360" font-family="Arial, sans-serif" font-size="22" fill="#FFFFFF" opacity="0.8" text-anchor="middle">The daily briefing on kratom</text>
    <text x="600" y="400" font-family="Arial, sans-serif" font-size="22" fill="#FFFFFF" opacity="0.8" text-anchor="middle">regulation, science, business</text>

    <text x="600" y="560" font-family="Arial, sans-serif" font-size="16" fill="#FFFFFF" opacity="0.5" text-anchor="middle">kratomnewstoday.com</text>
  </svg>`;

  try {
    await sharp(Buffer.from(svg)).png().toFile(outputPath);
    console.log('Default OG image generated: ' + outputPath);
  } catch (err) {
    console.error('Failed to generate default OG image:', err.message);
    process.exit(1);
  }
}

generateDefaultOG();
