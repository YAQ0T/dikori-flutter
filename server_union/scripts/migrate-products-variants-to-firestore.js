require("dotenv").config();

const {
  connectToDatabase,
  disconnectFromDatabase,
} = require("../utils/config");
const { getFirestore } = require("../utils/firebaseAdmin");
const Product = require("../models/Product");
const Variant = require("../models/Variant");

const BATCH_LIMIT = 400;

function sanitizeForFirestore(value) {
  if (value === undefined) return undefined;

  if (Array.isArray(value)) {
    return value
      .map((item) => sanitizeForFirestore(item))
      .filter((item) => item !== undefined);
  }

  if (value && typeof value === "object" && !(value instanceof Date)) {
    const out = {};
    for (const [key, nested] of Object.entries(value)) {
      const cleaned = sanitizeForFirestore(nested);
      if (cleaned !== undefined) {
        out[key] = cleaned;
      }
    }
    return out;
  }

  return value;
}

function normalizeProductDoc(doc) {
  const id = String(doc._id);
  const payload = {
    ...doc,
    _id: id,
  };
  delete payload.__v;
  return sanitizeForFirestore(payload);
}

function normalizeVariantDoc(doc) {
  const id = String(doc._id);
  const productId = String(doc.product || doc.productId || "");
  const payload = {
    ...doc,
    _id: id,
    productId,
    product: productId,
  };
  delete payload.__v;
  return sanitizeForFirestore(payload);
}

async function writeBatchUpserts(collectionName, docs = []) {
  const db = getFirestore();
  let batch = db.batch();
  let currentBatchCount = 0;
  let totalCommitted = 0;

  for (const doc of docs) {
    const id = String(doc?._id || "").trim();
    if (!id) continue;

    batch.set(db.collection(collectionName).doc(id), doc, { merge: true });
    currentBatchCount += 1;

    if (currentBatchCount >= BATCH_LIMIT) {
      await batch.commit();
      totalCommitted += currentBatchCount;
      batch = db.batch();
      currentBatchCount = 0;
    }
  }

  if (currentBatchCount > 0) {
    await batch.commit();
    totalCommitted += currentBatchCount;
  }

  return totalCommitted;
}

async function migrate() {
  await connectToDatabase();

  const [products, variants] = await Promise.all([
    Product.find({}).lean(),
    Variant.find({}).lean(),
  ]);

  const normalizedProducts = products.map((doc) => normalizeProductDoc(doc));
  const normalizedVariants = variants
    .map((doc) => normalizeVariantDoc(doc))
    .filter((doc) => doc.productId);

  const [productsWritten, variantsWritten] = await Promise.all([
    writeBatchUpserts("products", normalizedProducts),
    writeBatchUpserts("variants", normalizedVariants),
  ]);

  console.log(
    JSON.stringify({
      ok: true,
      productsFetched: products.length,
      variantsFetched: variants.length,
      productsWritten,
      variantsWritten,
    })
  );
}

(async () => {
  try {
    await migrate();
  } catch (err) {
    console.error(
      "migrate-products-variants-to-firestore failed:",
      err?.stack || err?.message || err
    );
    process.exitCode = 1;
  } finally {
    try {
      await disconnectFromDatabase();
    } catch (err) {
      console.error(
        "Failed to disconnect MongoDB:",
        err?.stack || err?.message || err
      );
      if (!process.exitCode) process.exitCode = 1;
    }
  }
})();
