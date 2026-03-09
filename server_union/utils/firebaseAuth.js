const axios = require("axios");
const { getFirebaseAuth } = require("./firebaseAdmin");

const FIREBASE_AUTH_MODE_VALUES = new Set(["firebase", "hybrid", "jwt"]);

function getAuthMode() {
  if (process.env.NODE_ENV === "test") {
    return String(process.env.AUTH_MODE || "jwt").toLowerCase();
  }
  const mode = String(process.env.AUTH_MODE || "firebase").toLowerCase();
  return FIREBASE_AUTH_MODE_VALUES.has(mode) ? mode : "firebase";
}

function getFirebaseWebApiKey() {
  const key = String(process.env.FIREBASE_WEB_API_KEY || "").trim();
  if (!key) {
    throw new Error(
      "FIREBASE_WEB_API_KEY is required to exchange custom tokens for ID tokens."
    );
  }
  return key;
}

function normalizeUid(uid) {
  const value = String(uid || "").trim();
  if (!value) throw new Error("uid is required to issue Firebase tokens.");
  if (value.length > 128) {
    throw new Error("uid must be <= 128 characters for Firebase Auth.");
  }
  return value;
}

function normalizeLocalUserId(localUserId) {
  if (!localUserId) return null;
  const value = String(localUserId).trim();
  return value || null;
}

function normalizeEmail(email) {
  if (!email) return null;
  const value = String(email).trim().toLowerCase();
  return value || null;
}

function normalizePhone(phone) {
  if (!phone) return null;
  const value = String(phone).trim();
  return value || null;
}

function normalizeDisplayName(name) {
  if (!name) return null;
  const value = String(name).trim();
  return value || null;
}

function firebaseUserPatch(current, target) {
  const patch = {};

  if (target.email && current.email !== target.email) {
    patch.email = target.email;
    patch.emailVerified = Boolean(current.emailVerified);
  }
  if (target.phoneNumber && current.phoneNumber !== target.phoneNumber) {
    patch.phoneNumber = target.phoneNumber;
  }
  if (target.displayName && current.displayName !== target.displayName) {
    patch.displayName = target.displayName;
  }

  return patch;
}

async function ensureFirebaseUser({
  uid,
  role = "user",
  localUserId,
  email,
  phone,
  name,
} = {}) {
  const auth = getFirebaseAuth();
  const normalizedUid = normalizeUid(uid);
  const desired = {
    email: normalizeEmail(email),
    phoneNumber: normalizePhone(phone),
    displayName: normalizeDisplayName(name),
  };

  let userRecord = null;
  try {
    userRecord = await auth.getUser(normalizedUid);
  } catch (err) {
    const code = err?.code || "";
    if (code !== "auth/user-not-found") {
      throw err;
    }
  }

  if (!userRecord) {
    userRecord = await auth.createUser({
      uid: normalizedUid,
      ...(desired.email ? { email: desired.email } : {}),
      ...(desired.phoneNumber ? { phoneNumber: desired.phoneNumber } : {}),
      ...(desired.displayName ? { displayName: desired.displayName } : {}),
    });
  } else {
    const patch = firebaseUserPatch(userRecord, desired);
    if (Object.keys(patch).length) {
      userRecord = await auth.updateUser(normalizedUid, patch);
    }
  }

  const normalizedLocalUserId = normalizeLocalUserId(localUserId);
  const currentClaims = userRecord.customClaims || {};
  const nextClaims = {
    ...currentClaims,
    role,
    ...(normalizedLocalUserId ? { localUserId: normalizedLocalUserId } : {}),
  };

  if (!normalizedLocalUserId && "localUserId" in nextClaims) {
    delete nextClaims.localUserId;
  }

  const claimsChanged =
    currentClaims.role !== nextClaims.role ||
    (currentClaims.localUserId || null) !== (nextClaims.localUserId || null);

  if (claimsChanged) {
    await auth.setCustomUserClaims(normalizedUid, nextClaims);
  }

  return userRecord;
}

async function exchangeCustomTokenForIdToken(customToken) {
  const apiKey = getFirebaseWebApiKey();
  const url = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${encodeURIComponent(
    apiKey
  )}`;

  const { data } = await axios.post(
    url,
    {
      token: customToken,
      returnSecureToken: true,
    },
    {
      timeout: 20000,
      headers: { "Content-Type": "application/json" },
    }
  );

  const idToken = data?.idToken ? String(data.idToken) : "";
  if (!idToken) {
    throw new Error("Failed to exchange Firebase custom token for ID token.");
  }

  return {
    idToken,
    refreshToken: data?.refreshToken ? String(data.refreshToken) : null,
    expiresIn: data?.expiresIn ? Number(data.expiresIn) : null,
  };
}

async function refreshFirebaseSession(refreshToken) {
  const token = String(refreshToken || "").trim();
  if (!token) {
    throw new Error("refreshToken is required.");
  }

  const apiKey = getFirebaseWebApiKey();
  const url = `https://securetoken.googleapis.com/v1/token?key=${encodeURIComponent(
    apiKey
  )}`;

  const body = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: token,
  });

  const { data } = await axios.post(url, body.toString(), {
    timeout: 20000,
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
  });

  const idToken = data?.id_token ? String(data.id_token) : "";
  const newRefreshToken = data?.refresh_token
    ? String(data.refresh_token)
    : token;

  if (!idToken) {
    throw new Error("Failed to refresh Firebase session.");
  }

  return {
    idToken,
    refreshToken: newRefreshToken,
    expiresIn: data?.expires_in ? Number(data.expires_in) : null,
    userId: data?.user_id ? String(data.user_id) : null,
  };
}

async function issueFirebaseSession({
  uid,
  role = "user",
  localUserId,
  email,
  phone,
  name,
} = {}) {
  const auth = getFirebaseAuth();
  const normalizedUid = normalizeUid(uid);
  const normalizedLocalUserId = normalizeLocalUserId(localUserId);
  await ensureFirebaseUser({
    uid: normalizedUid,
    role,
    localUserId: normalizedLocalUserId,
    email,
    phone,
    name,
  });

  const tokenClaims = {
    role,
    ...(normalizedLocalUserId
      ? { localUserId: normalizedLocalUserId }
      : {}),
  };
  const customToken = await auth.createCustomToken(normalizedUid, tokenClaims);
  return exchangeCustomTokenForIdToken(customToken);
}

async function verifyFirebaseIdToken(idToken) {
  const auth = getFirebaseAuth();
  const decoded = await auth.verifyIdToken(idToken, true);
  return {
    uid: String(decoded.uid),
    role: decoded.role || "user",
    localUserId: decoded.localUserId
      ? String(decoded.localUserId)
      : null,
    email: decoded.email || null,
    phone: decoded.phone_number || null,
    decoded,
  };
}

module.exports = {
  getAuthMode,
  issueFirebaseSession,
  refreshFirebaseSession,
  verifyFirebaseIdToken,
};
