const fs = require('fs');
const path = require('path');

async function generateFavicons() {
  let sharp;
  try {
    sharp = require('sharp');
  } catch (e) {
    console.error('Sharp not installed. Run npm install first.');
    process.exit(1);
  }

  const assetsDir = path.join(__dirname, '..', 'src', 'assets');

  // Simple "K" favicon
  const faviconSvg = `
  <svg width="64" height="64" xmlns="http://www.w3.org/2000/svg">
    <rect width="64" height="64" rx="8" fill="#1F5F3F"/>
    <text x="32" y="46" font-family="Georgia, serif" font-size="40" font-weight="bold" fill="#FFFFFF" text-anchor="middle">K</text>
  </svg>`;

  // Generate favicon as PNG (browsers accept PNG favicons)
  await sharp(Buffer.from(faviconSvg)).resize(32, 32).png().toFile(path.join(assetsDir, 'favicon.ico'));
  console.log('Favicon generated.');

  // Apple touch icon (180x180)
  const appleSvg = `
  <svg width="180" height="180" xmlns="http://www.w3.org/2000/svg">
    <rect width="180" height="180" rx="36" fill="#1F5F3F"/>
    <text x="90" y="125" font-family="Georgia, serif" font-size="110" font-weight="bold" fill="#FFFFFF" text-anchor="middle">K</text>
  </svg>`;

  await sharp(Buffer.from(appleSvg)).png().toFile(path.join(assetsDir, 'apple-touch-icon.png'));
  console.log('Apple touch icon generated.');
}

generateFavicons();
