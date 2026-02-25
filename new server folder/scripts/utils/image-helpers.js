// server/scripts/utils/image-helpers.js
function sanitizeImageList(values) {
  if (!Array.isArray(values)) return [];

  const deduped = [];
  const seen = new Set();

  for (const value of values) {
    if (typeof value !== "string") continue;
    const trimmed = value.trim();
    if (!trimmed) continue;
    if (seen.has(trimmed)) continue;
    seen.add(trimmed);
    deduped.push(trimmed);
  }

  return deduped;
}

function extractImageUrls(documents, getter) {
  const urls = [];
  for (const doc of documents || []) {
    try {
      const images = getter(doc);
      for (const url of sanitizeImageList(images)) {
        urls.push(url);
      }
    } catch (error) {
      // Swallow getter errors so one malformed doc does not halt the process.
    }
  }
  return urls;
}

module.exports = {
  sanitizeImageList,
  extractImageUrls,
};
