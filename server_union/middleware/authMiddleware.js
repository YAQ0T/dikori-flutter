// server/middleware/authMiddleware.js
const jwt = require("jsonwebtoken");
const { getJwtSecret } = require("../utils/config");
const { getAuthMode, verifyFirebaseIdToken } = require("../utils/firebaseAuth");

function decodeLegacyJwt(token) {
  const secret = getJwtSecret();
  const decoded = jwt.verify(token, secret);
  return {
    id: decoded.id || decoded.uid || decoded.userId,
    role: decoded.role || "user",
    legacyJwt: true,
  };
}

async function decodeAccessToken(token) {
  const mode = getAuthMode();

  if (mode === "firebase") {
    const verified = await verifyFirebaseIdToken(token);
    return {
      id: verified.localUserId || verified.uid,
      role: verified.role || "user",
      firebaseUid: verified.uid,
      localUserId: verified.localUserId || null,
      email: verified.email,
      phone: verified.phone,
      firebase: true,
    };
  }

  if (mode === "jwt") {
    return decodeLegacyJwt(token);
  }

  // hybrid mode: prefer Firebase, fallback to legacy JWT
  try {
    const verified = await verifyFirebaseIdToken(token);
    return {
      id: verified.localUserId || verified.uid,
      role: verified.role || "user",
      firebaseUid: verified.uid,
      localUserId: verified.localUserId || null,
      email: verified.email,
      phone: verified.phone,
      firebase: true,
    };
  } catch {
    return decodeLegacyJwt(token);
  }
}

// ✅ يتحقق من التوكن ويوقف الطلب لو غير موجود/غير صالح
const verifyToken = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith("Bearer ")) {
    return res.status(401).json({ message: "توكن غير موجود" });
  }

  const token = authHeader.split(" ")[1];

  try {
    req.user = await decodeAccessToken(token);
    return next();
  } catch (_err) {
    return res.status(401).json({ message: "توكن غير صالح أو منتهي" });
  }
};

// ✅ يسمح بالمتابعة بدون توكن لكن يملأ req.user لو وُجد
const verifyTokenOptional = async (req, _res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith("Bearer ")) return next();

  const token = authHeader.split(" ")[1];

  try {
    req.user = await decodeAccessToken(token);
  } catch {
    // تجاهل الخطأ هنا لأن التوكن اختياري
  }
  return next();
};

// ✅ أدمن فقط
const isAdmin = (req, res, next) => {
  const role = req.user?.role;
  if (role !== "admin") {
    return res.status(403).json({ message: "غير مصرح، يتطلب أدمن" });
  }
  next();
};

// ✅ أدمن أو تاجر
const isDealerOrAdmin = (req, res, next) => {
  const role = req.user?.role;
  if (role !== "admin" && role !== "dealer") {
    return res.status(403).json({ message: "غير مصرح، يتطلب أدمن أو تاجر" });
  }
  next();
};

module.exports = { verifyToken, verifyTokenOptional, isAdmin, isDealerOrAdmin };
