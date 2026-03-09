const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

let cachedApp = null;

function parseServiceAccountFromEnvJson() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object") {
      throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON must be a JSON object.");
    }
    return parsed;
  } catch (err) {
    throw new Error(
      `Invalid FIREBASE_SERVICE_ACCOUNT_JSON: ${err?.message || err}`
    );
  }
}

function parseServiceAccountFromEnvBase64() {
  const raw = String(process.env.FIREBASE_SERVICE_ACCOUNT_BASE64 || "").trim();
  if (!raw) return null;

  try {
    const decoded = Buffer.from(raw, "base64").toString("utf8");
    const parsed = JSON.parse(decoded);
    if (!parsed || typeof parsed !== "object") {
      throw new Error("FIREBASE_SERVICE_ACCOUNT_BASE64 must decode to JSON.");
    }
    return parsed;
  } catch (err) {
    throw new Error(
      `Invalid FIREBASE_SERVICE_ACCOUNT_BASE64: ${err?.message || err}`
    );
  }
}

function parseServiceAccountFromPath() {
  const rawPath = String(process.env.FIREBASE_SERVICE_ACCOUNT_PATH || "").trim();
  if (!rawPath) return null;

  const resolvedPath = path.resolve(rawPath);
  try {
    const json = fs.readFileSync(resolvedPath, "utf8");
    const parsed = JSON.parse(json);
    if (!parsed || typeof parsed !== "object") {
      throw new Error("FIREBASE_SERVICE_ACCOUNT_PATH file must contain JSON.");
    }
    return parsed;
  } catch (err) {
    throw new Error(
      `Invalid FIREBASE_SERVICE_ACCOUNT_PATH (${resolvedPath}): ${
        err?.message || err
      }`
    );
  }
}

function getFirebaseProjectId() {
  const projectId = process.env.FIREBASE_PROJECT_ID || "";
  return String(projectId).trim();
}

function getFirebaseAdminApp() {
  if (cachedApp) return cachedApp;
  if (admin.apps.length > 0) {
    cachedApp = admin.app();
    return cachedApp;
  }

  const projectId = getFirebaseProjectId();
  const serviceAccount =
    parseServiceAccountFromPath() ||
    parseServiceAccountFromEnvJson() ||
    parseServiceAccountFromEnvBase64();

  const options = {
    ...(projectId ? { projectId } : {}),
  };

  if (serviceAccount) {
    options.credential = admin.credential.cert(serviceAccount);
  } else {
    options.credential = admin.credential.applicationDefault();
  }

  cachedApp = admin.initializeApp(options);
  return cachedApp;
}

function getFirebaseAuth() {
  return getFirebaseAdminApp().auth();
}

function getFirestore() {
  return getFirebaseAdminApp().firestore();
}

module.exports = {
  getFirebaseAdminApp,
  getFirebaseAuth,
  getFirestore,
  getFirebaseProjectId,
};
