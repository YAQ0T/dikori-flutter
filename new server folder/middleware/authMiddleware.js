// server/middleware/authMiddleware.js
const jwt = require("jsonwebtoken");
const { getJwtSecret } = require("../utils/config");

// ✅ وحّد السر هنا مع نفس السر في routes/auth.js
const JWT_SECRET = getJwtSecret();

// ✅ يتحقق من التوكن ويوقف الطلب لو غير موجود/غير صالح
const verifyToken = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith("Bearer ")) {
    return res.status(401).json({ message: "توكن غير موجود" });
  }

  const token = authHeader.split(" ")[1];

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded; // { id, role }
    next();
  } catch (err) {
    return res.status(401).json({ message: "توكن غير صالح أو منتهي" });
  }
};

// ✅ يسمح بالمتابعة بدون توكن لكن يملأ req.user لو وُجد
const verifyTokenOptional = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith("Bearer ")) return next();

  const token = authHeader.split(" ")[1];

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded; // { id, role }
  } catch {
    // تجاهل الخطأ هنا لأن التوكن اختياري
  }
  next();
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
