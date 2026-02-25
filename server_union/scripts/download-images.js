// server/scripts/download-images.js
require("dotenv").config();
const fs = require("fs");
const path = require("path");
const { pipeline } = require("stream/promises");
const axios = require("axios");

const {
  connectToDatabase,
  disconnectFromDatabase,
} = require("../utils/config");
const Product = require("../models/Product");
const Variant = require("../models/Variant");
const { extractImageUrls } = require("./utils/image-helpers");

const DEFAULT_OUTPUT = path.join(__dirname, "..", "downloads", "images");
const DEFAULT_CONCURRENCY = 4;

function printHelp() {
  console.log(`Usage: node scripts/download-images.js [options]\n\n` +
    `Options:\n` +
    `  --out <dir>           Destination directory (default: ${DEFAULT_OUTPUT})\n` +
    `  --concurrency <num>   Parallel downloads (default: ${DEFAULT_CONCURRENCY})\n` +
    `  -h, --help            Show this message\n`);
}

function parseArgs() {
  const args = process.argv.slice(2);
  const options = {
    out: DEFAULT_OUTPUT,
    concurrency: DEFAULT_CONCURRENCY,
  };

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (arg === "--out" || arg === "-o") {
      options.out = args[++i];
    } else if (arg.startsWith("--out=")) {
      options.out = arg.slice("--out=".length);
    } else if (arg === "--concurrency" || arg === "-c") {
      options.concurrency = Number(args[++i]);
    } else if (arg.startsWith("--concurrency=")) {
      options.concurrency = Number(arg.slice("--concurrency=".length));
    } else if (arg === "--help" || arg === "-h") {
      printHelp();
      process.exit(0);
    } else {
      console.warn(`⚠️ Unknown argument ignored: ${arg}`);
    }
  }

  if (!options.out) options.out = DEFAULT_OUTPUT;
  const parsedConcurrency = Number(options.concurrency);
  options.concurrency = Number.isFinite(parsedConcurrency) && parsedConcurrency > 0
    ? Math.floor(parsedConcurrency)
    : DEFAULT_CONCURRENCY;

  options.out = path.resolve(process.cwd(), options.out);
  return options;
}

function slugFromUrl(url) {
  try {
    const { pathname } = new URL(url);
    const lastSegment = pathname.split("/").filter(Boolean).pop() || "image";
    const ext = path.extname(lastSegment) || ".jpg";
    const base = lastSegment.slice(0, lastSegment.length - ext.length) || "image";
    const slug = base
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 60);
    return { slug: slug || "image", ext };
  } catch (e) {
    return { slug: "image", ext: ".jpg" };
  }
}

function buildFilename(url, index) {
  const { slug, ext } = slugFromUrl(url);
  const padded = String(index + 1).padStart(4, "0");
  return `${padded}-${slug}${ext}`;
}

async function fetchImage(url, index, outDir) {
  const filename = buildFilename(url, index);
  const outputPath = path.join(outDir, filename);
  try {
    const response = await axios.get(url, {
      responseType: "stream",
      timeout: 30000,
      maxRedirects: 5,
    });

    await pipeline(response.data, fs.createWriteStream(outputPath));
    console.log(`✅ Downloaded [${index + 1}] ${url} → ${filename}`);
    return true;
  } catch (error) {
    const message = error?.message || error?.toString() || "Unknown error";
    console.error(`❌ Failed [${index + 1}] ${url} :: ${message}`);
    return false;
  }
}

async function main() {
  const options = parseArgs();
  await fs.promises.mkdir(options.out, { recursive: true });

  await connectToDatabase();

  const [productDocs, variantDocs] = await Promise.all([
    Product.find({}, { images: 1 }).lean(),
    Variant.find({}, { "color.images": 1 }).lean(),
  ]);

  const productUrls = extractImageUrls(productDocs, (doc) => doc.images || []);
  const variantUrls = extractImageUrls(variantDocs, (doc) => doc.color?.images || []);

  const uniqueUrls = Array.from(new Set([...productUrls, ...variantUrls]));
  console.log(`🧮 Found ${uniqueUrls.length} unique image URL(s).`);

  if (uniqueUrls.length === 0) {
    console.log("ℹ️ No image URLs found. Nothing to download.");
    return { failures: 0 };
  }

  let cursor = 0;
  let failures = 0;

  async function worker() {
    while (true) {
      const index = cursor;
      cursor += 1;
      if (index >= uniqueUrls.length) break;
      const url = uniqueUrls[index];
      const ok = await fetchImage(url, index, options.out);
      if (!ok) failures += 1;
    }
  }

  const concurrency = Math.max(1, Math.min(options.concurrency, uniqueUrls.length));
  const workers = Array.from({ length: concurrency }, worker);
  await Promise.all(workers);

  if (failures) {
    console.error(`⚠️ Completed with ${failures} failed download(s).`);
  } else {
    console.log("🎉 All downloads completed successfully.");
  }

  return { failures };
}

(async () => {
  let result = { failures: 0 };
  try {
    result = await main();
  } catch (error) {
    const message = error?.stack || error?.message || String(error);
    console.error(`❌ Unexpected error: ${message}`);
    process.exitCode = 1;
  } finally {
    try {
      await disconnectFromDatabase();
    } catch (err) {
      console.error(`⚠️ Failed to close Mongo connection: ${err?.message || err}`);
      if (!process.exitCode) process.exitCode = 1;
    }
    if (result.failures > 0 && !process.exitCode) {
      process.exitCode = 1;
    }
  }
})();
