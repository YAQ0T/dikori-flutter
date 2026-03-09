require("dotenv").config();

const mongoose = require("mongoose");
const { getFirestore } = require("../utils/firebaseAdmin");

const BATCH_LIMIT = 400;

function isObjectIdLike(value) {
  return (
    value &&
    typeof value === "object" &&
    (value._bsontype === "ObjectID" ||
      value._bsontype === "ObjectId" ||
      value.constructor?.name === "ObjectId" ||
      typeof value.toHexString === "function")
  );
}

function normalize(value) {
  if (value === undefined) return undefined;
  if (value === null) return null;
  if (value instanceof Date) return value;
  if (Array.isArray(value)) {
    return value
      .map((item) => normalize(item))
      .filter((item) => item !== undefined);
  }
  if (isObjectIdLike(value)) {
    if (typeof value.toHexString === "function") {
      return value.toHexString();
    }
    return String(value);
  }
  if (value && typeof value.toDate === "function") {
    return value.toDate();
  }
  if (value && typeof value === "object") {
    const out = {};
    for (const [key, nested] of Object.entries(value)) {
      const cleaned = normalize(nested);
      if (cleaned !== undefined) out[key] = cleaned;
    }
    return out;
  }
  return value;
}

function withId(doc) {
  const normalized = normalize(doc || {});
  const id = String(normalized?._id || "").trim();
  if (!id) return null;
  delete normalized.__v;
  normalized._id = id;
  return normalized;
}

async function writeBatchUpserts(collectionName, docs = []) {
  const db = getFirestore();
  let batch = db.batch();
  let inBatch = 0;
  let committed = 0;

  for (const doc of docs) {
    const id = String(doc?._id || "").trim();
    if (!id) continue;
    batch.set(db.collection(collectionName).doc(id), doc, { merge: true });
    inBatch += 1;

    if (inBatch >= BATCH_LIMIT) {
      await batch.commit();
      committed += inBatch;
      batch = db.batch();
      inBatch = 0;
    }
  }

  if (inBatch > 0) {
    await batch.commit();
    committed += inBatch;
  }

  return committed;
}

async function loadCollection(db, name) {
  try {
    return await db.collection(name).find({}).toArray();
  } catch {
    return [];
  }
}

function pickLatestSingleDoc(docs = [], singletonId = "main") {
  if (!Array.isArray(docs) || !docs.length) return null;
  const sorted = [...docs].sort((a, b) => {
    const aTs = new Date(a?.updatedAt || a?.createdAt || 0).getTime();
    const bTs = new Date(b?.updatedAt || b?.createdAt || 0).getTime();
    return bTs - aTs;
  });
  const picked = withId(sorted[0]);
  if (!picked) return null;
  picked._id = singletonId;
  return picked;
}

async function migrate() {
  const mongoUri = String(process.env.MONGO_URI || "").trim();
  if (!mongoUri) {
    throw new Error("MONGO_URI is required for migration.");
  }

  await mongoose.connect(mongoUri, {
    serverSelectionTimeoutMS: 15000,
    family: 4,
  });

  const db = mongoose.connection.db;

  const [
    users,
    orders,
    discountRules,
    notifications,
    siteAds,
    siteSettings,
    homeCollections,
  ] = await Promise.all([
    loadCollection(db, "users"),
    loadCollection(db, "orders"),
    loadCollection(db, "discountrules"),
    loadCollection(db, "notifications"),
    loadCollection(db, "siteads"),
    loadCollection(db, "sitesettings"),
    loadCollection(db, "homecollections"),
  ]);

  const normalizedUsers = users.map(withId).filter(Boolean);
  const normalizedOrders = orders.map(withId).filter(Boolean);
  const normalizedDiscountRules = discountRules.map(withId).filter(Boolean);
  const normalizedNotifications = notifications.map(withId).filter(Boolean);

  const singletonSiteAd = pickLatestSingleDoc(siteAds, "main");
  const singletonSiteSettings = pickLatestSingleDoc(siteSettings, "main");
  const singletonHomeCollections = pickLatestSingleDoc(homeCollections, "main");

  const [usersWritten, ordersWritten, discountRulesWritten, notificationsWritten] =
    await Promise.all([
      writeBatchUpserts("users", normalizedUsers),
      writeBatchUpserts("orders", normalizedOrders),
      writeBatchUpserts("discount_rules", normalizedDiscountRules),
      writeBatchUpserts("notifications", normalizedNotifications),
    ]);

  const [siteAdWritten, siteSettingsWritten, homeCollectionsWritten] =
    await Promise.all([
      singletonSiteAd ? writeBatchUpserts("site_ad", [singletonSiteAd]) : 0,
      singletonSiteSettings
        ? writeBatchUpserts("site_settings", [singletonSiteSettings])
        : 0,
      singletonHomeCollections
        ? writeBatchUpserts("home_collections", [singletonHomeCollections])
        : 0,
    ]);

  console.log(
    JSON.stringify({
      ok: true,
      usersFetched: users.length,
      ordersFetched: orders.length,
      discountRulesFetched: discountRules.length,
      notificationsFetched: notifications.length,
      siteAdsFetched: siteAds.length,
      siteSettingsFetched: siteSettings.length,
      homeCollectionsFetched: homeCollections.length,
      usersWritten,
      ordersWritten,
      discountRulesWritten,
      notificationsWritten,
      siteAdWritten,
      siteSettingsWritten,
      homeCollectionsWritten,
    })
  );
}

(async () => {
  try {
    await migrate();
  } catch (err) {
    console.error(
      "migrate-mongo-core-to-firestore failed:",
      err?.stack || err?.message || err
    );
    process.exitCode = 1;
  } finally {
    try {
      await mongoose.disconnect();
    } catch (err) {
      console.error(
        "Failed to disconnect MongoDB:",
        err?.stack || err?.message || err
      );
      if (!process.exitCode) process.exitCode = 1;
    }
  }
})();
