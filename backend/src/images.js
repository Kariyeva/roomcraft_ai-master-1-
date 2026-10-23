const sharp = require('sharp');
const { ApiError } = require('./errors');
const maxPixels = 24 * 1024 * 1024;
const pipeline = bytes => sharp(bytes, { limitInputPixels: maxPixels, failOn: 'warning', animated: false });
async function inputImage(file, kind = 'room') {
  if (!file) throw new ApiError(400, 'IMAGE_REQUIRED', 'Добавьте фотографию JPG или PNG.');
  try {
    const meta = await pipeline(file.buffer).metadata();
    if (!['jpeg', 'png'].includes(meta.format) || (meta.pages || 1) > 1) throw new Error('format');
    if (file.mimetype !== 'application/octet-stream' && file.mimetype !== `image/${meta.format}`) throw new Error('type');
    for (const side of [1600, 1200, 900, 600]) {
      let image = pipeline(file.buffer).rotate().resize({ width: side, height: side, fit: 'inside', withoutEnlargement: true });
      image = kind === 'background' ? image.png({ palette: true, quality: 85, compressionLevel: 6 }) : image.jpeg({ quality: 85 });
      const buffer = await image.toBuffer();
      if (buffer.length <= 750000) return `data:image/${kind === 'background' ? 'png' : 'jpeg'};base64,${buffer.toString('base64')}`;
    }
    throw new Error('size');
  } catch (_) { throw new ApiError(400, 'INVALID_IMAGE', 'Файл повреждён, имеет неподдерживаемый формат или разрешение больше 24 Мп.'); }
}
async function outputImage(buffer, kind) {
  for (const side of [1400, 1000, 700, 500, 350]) {
    let output = pipeline(buffer).rotate().resize({ width: side, height: side, fit: 'inside', withoutEnlargement: true });
    output = kind === 'background' ? output.png({ palette: true, quality: 85, compressionLevel: 9 }) : output.jpeg({ quality: 85 });
    const bytes = await output.toBuffer();
    if (bytes.length <= 400000) return { imageBase64: bytes.toString('base64'), mimeType: kind === 'background' ? 'image/png' : 'image/jpeg' };
  }
  throw new Error('Output too large');
}
module.exports = { inputImage, outputImage };
