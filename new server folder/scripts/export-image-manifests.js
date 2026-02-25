// server/scripts/export-image-manifests.js
require("dotenv").config();
const fs = require("fs");
const path = require("path");

const {
  connectToDatabase,
  disconnectFromDatabase,
} = require("../utils/config");
const Product = require("../models/Product");
const Variant = require("../models/Variant");
const { sanitizeImageList } = require("./utils/image-helpers");

const DEFAULT_OUTPUT_DIR = path.join(
  __dirname,
  "..",
  "downloads",
  "manifests"
);
const DEFAULT_PRODUCT_OUT = path.join(DEFAULT_OUTPUT_DIR, "products.jsonl");
const DEFAULT_VARIANT_OUT = path.join(DEFAULT_OUTPUT_DIR, "variants.jsonl");

function printHelp() {
  console.log(
    `Usage: node scripts/export-image-manifests.js [options]\n\n` +
      `Options:\n` +
      `  --product-out <file>   Product manifest destination (default: ${DEFAULT_PRODUCT_OUT})\n` +
      `  --variant-out <file>   Variant manifest destination (default: ${DEFAULT_VARIANT_OUT})\n` +
      `  -h, --help             Show this message\n`
  );
}

function parseArgs() {
  const args = process.argv.slice(2);
  const options = {
    productOut: DEFAULT_PRODUCT_OUT,
    variantOut: DEFAULT_VARIANT_OUT,
  };

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (arg === "--product-out") {
      options.productOut = args[++i];
    } else if (arg.startsWith("--product-out=")) {
      options.productOut = arg.slice("--product-out=".length);
    } else if (arg === "--variant-out") {
      options.variantOut = args[++i];
    } else if (arg.startsWith("--variant-out=")) {
      options.variantOut = arg.slice("--variant-out=".length);
    } else if (arg === "--help" || arg === "-h") {
      printHelp();
      process.exit(0);
    } else {
      console.warn(`⚠️ Unknown argument ignored: ${arg}`);
    }
  }

  if (!options.productOut) options.productOut = DEFAULT_PRODUCT_OUT;
  if (!options.variantOut) options.variantOut = DEFAULT_VARIANT_OUT;

  options.productOut = path.resolve(process.cwd(), options.productOut);
  options.variantOut = path.resolve(process.cwd(), options.variantOut);

  return options;
}

function buildManifestEntries(docs, getImages) {
  return (docs || []).map((doc) => ({
    _id: String(doc._id),
    images: sanitizeImageList(getImages(doc)),
  }));
}

async function writeManifest(entries, filePath, label) {
  try {
    await fs.promises.mkdir(path.dirname(filePath), { recursive: true });
    const lines = entries.map((entry) => JSON.stringify(entry));
    const payload = lines.join("\n") + (lines.length ? "\n" : "");
    await fs.promises.writeFile(filePath, payload, "utf8");
    console.log(`✅ Wrote ${entries.length} ${label} entr${entries.length === 1 ? "y" : "ies"} to ${filePath}`);
    return true;
  } catch (error) {
    const message = error?.stack || error?.message || String(error);
    console.error(`❌ Failed to write ${label} manifest at ${filePath}: ${message}`);
    return false;
  }
}

async function main() {
  const options = parseArgs();
  await connectToDatabase();

  const [productDocs, variantDocs] = await Promise.all([
    Product.find({}, { images: 1 }).lean(),
    Variant.find({}, { product: 1, "color.images": 1 }).lean(),
  ]);

  const productEntries = buildManifestEntries(productDocs, (doc) => doc.images || []);
  const variantEntries = buildManifestEntries(variantDocs, (doc) => doc.color?.images || []);

  const productWriteOk = await writeManifest(productEntries, options.productOut, "product");
  const variantWriteOk = await writeManifest(variantEntries, options.variantOut, "variant");

  if (!productWriteOk || !variantWriteOk) {
    process.exitCode = 1;
  }
}

(async () => {
  try {
    await main();
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
  }
})();
