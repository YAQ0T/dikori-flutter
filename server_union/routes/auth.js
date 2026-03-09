// server/routes/auth.js
const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const User = require("../models/User");
const { getJwtSecret } = require("../utils/config");
const { getFirebaseAuth, getFirebaseProjectId } = require("../utils/firebaseAdmin");
const {
  issueFirebaseSession,
  refreshFirebaseSession,
  getAuthMode,
} = require("../utils/firebaseAuth");
const { sendSMSHTD, normalizePhone } = require("../utils/smsHtd");
const { createRateLimiter } = require("../utils/rateLimit");
const { verifyToken } = require("../middleware/authMiddleware");
const { validateBody, z } = require("../utils/validate");

const router = express.Router();

const DEFAULT_RESET_PASSWORD_MAX_ATTEMPTS = 5;
const parsedResetAttempts = Number.parseInt(
  process.env.RESET_PASSWORD_MAX_ATTEMPTS,
  10
);
const RESET_PASSWORD_MAX_ATTEMPTS =
  Number.isInteger(parsedResetAttempts) && parsedResetAttempts > 0
    ? parsedResetAttempts
    : DEFAULT_RESET_PASSWORD_MAX_ATTEMPTS;

const RESET_PASSWORD_THROTTLE_MESSAGE =
  "تجاوزت الحد المسموح لمحاولات التحقق. اطلب رمزًا جديدًا.";

/* =========================
   ضبط بيئة/إعدادات
========================= */
const limiterSignup = createRateLimiter({
  windowMs: 10 * 60 * 1000,
  max: 20,
  message: "تجاوزت حد محاولات التسجيل، حاول لاحقًا.",
  name: "auth-signup",
});
const limiterLogin = createRateLimiter({
  windowMs: 10 * 60 * 1000,
  max: 40,
  message: "محاولات تسجيل دخول كثيرة. حاول بعد قليل.",
  name: "auth-login",
});
const limiterSendSms = createRateLimiter({
  windowMs: 10 * 60 * 1000,
  max: 5,
  message: "تجاوزت حد إرسال أكواد التحقق. حاول لاحقًا.",
  name: "auth-send-sms",
  keyGenerator: (req) => {
    const ip = req.ip || req.headers["x-forwarded-for"] || "ip";
    const normPhone = req.body?.phone ? normalizePhone(req.body.phone) : null;
    const userId = req.body?.userId ? String(req.body.userId) : "";
    return `${ip}:${normPhone || userId || "unknown"}`;
  },
});
const limiterPasswordRequest = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 8,
  message: "طلبات الاستعادة كثيرة. حاول لاحقًا.",
  name: "auth-password-request",
  keyGenerator: (req) => {
    const ip = req.ip || req.headers["x-forwarded-for"] || "ip";
    const normPhone = req.body?.phone ? normalizePhone(req.body.phone) : null;
    const normEmail = req.body?.email
      ? String(req.body.email).trim().toLowerCase()
      : "";
    return `${ip}:${normPhone || normEmail || "unknown"}`;
  },
});
const limiterPasswordReset = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 8,
  message: "محاولات إعادة التعيين كثيرة. حاول لاحقًا.",
  name: "auth-password-reset",
  keyGenerator: (req) => {
    const ip = req.ip || req.headers["x-forwarded-for"] || "ip";
    const normPhone = req.body?.phone ? normalizePhone(req.body.phone) : null;
    const normEmail = req.body?.email
      ? String(req.body.email).trim().toLowerCase()
      : "";
    return `${ip}:${normPhone || normEmail || "unknown"}`;
  },
});
const limiterVerifySms = createRateLimiter({
  windowMs: 10 * 60 * 1000,
  max: 10,
  message: "محاولات التحقق كثيرة. حاول لاحقًا.",
  name: "auth-verify-sms",
});

const signupSchema = z
  .object({
    name: z.string().trim().min(1),
    password: z.string().min(6),
    phone: z.coerce.string().optional(),
    email: z.string().email().optional(),
  })
  .refine((data) => data.phone || data.email, {
    message: "phone_or_email_required",
    path: ["phone"],
  });

const loginSchema = z
  .object({
    password: z.string().min(1),
    phone: z.coerce.string().optional(),
    email: z.string().email().optional(),
  })
  .refine((data) => data.phone || data.email, {
    message: "phone_or_email_required",
    path: ["phone"],
  });

const sendSmsSchema = z
  .object({
    userId: z.string().optional(),
    phone: z.coerce.string().optional(),
  })
  .refine((data) => data.userId || data.phone, {
    message: "userId_or_phone_required",
    path: ["userId"],
  });

const verifySmsSchema = z.object({
  userId: z.string().min(1),
  code: z.coerce.string().min(4),
});

const passwordRequestSchema = z
  .object({
    phone: z.coerce.string().optional(),
    email: z.string().email().optional(),
  })
  .refine((data) => data.phone || data.email, {
    message: "phone_or_email_required",
    path: ["phone"],
  });

const passwordResetSchema = z
  .object({
    token: z.string().min(1),
    password: z.string().min(6),
    email: z.string().email().optional(),
    phone: z.coerce.string().optional(),
  })
  .refine((data) => data.email || data.phone, {
    message: "phone_or_email_required",
    path: ["phone"],
  });

const sessionRefreshSchema = z.object({
  refreshToken: z.string().min(1),
});

const socialAuthSchema = z.object({
  idToken: z.string().min(1),
});

function normalizeEmail(email) {
  if (!email) return null;
  const e = String(email).trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)) return null;
  return e;
}

function issueLegacyJwt(user) {
  const jwtSecret = getJwtSecret();
  return jwt.sign(
    { id: String(user._id), role: user.role || "user" },
    jwtSecret,
    { expiresIn: "90d" }
  );
}

async function issueAppSession(user) {
  const mode = getAuthMode();
  const legacyToken = issueLegacyJwt(user);
  const localUserId = String(user?._id || "").trim();
  const firebaseUid = String(user?.firebaseUid || "").trim() || localUserId;

  if (mode === "jwt") {
    return { token: legacyToken, authProvider: "jwt" };
  }

  if (mode === "hybrid") {
    try {
      const session = await issueFirebaseSession({
        uid: firebaseUid,
        localUserId,
        role: user.role || "user",
        email: user.email || null,
        phone: user.phone || null,
        name: user.name || "",
      });
      return {
        token: session.idToken,
        refreshToken: session.refreshToken || undefined,
        expiresIn: session.expiresIn || undefined,
        legacyToken,
        authProvider: "firebase",
      };
    } catch (err) {
      console.error("hybrid auth fallback to jwt:", err?.message || err);
      return {
        token: legacyToken,
        authProvider: "jwt-fallback",
      };
    }
  }

  const session = await issueFirebaseSession({
    uid: firebaseUid,
    localUserId,
    role: user.role || "user",
    email: user.email || null,
    phone: user.phone || null,
    name: user.name || "",
  });
  return {
    token: session.idToken,
    refreshToken: session.refreshToken || undefined,
    expiresIn: session.expiresIn || undefined,
    legacyToken,
    authProvider: "firebase",
  };
}

function getDisplayNameFromEmail(email) {
  const normalized = normalizeEmail(email);
  if (!normalized) return "Google User";
  const local = normalized.split("@")[0] || "";
  const safeLocal = local.replace(/[._-]+/g, " ").trim();
  return safeLocal || "Google User";
}

function decodeJwtPayloadUnsafe(jwtToken) {
  try {
    const parts = String(jwtToken || "").split(".");
    if (parts.length < 2) return null;
    const payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = payload.padEnd(Math.ceil(payload.length / 4) * 4, "=");
    const json = Buffer.from(padded, "base64").toString("utf8");
    const parsed = JSON.parse(json);
    return parsed && typeof parsed === "object" ? parsed : null;
  } catch {
    return null;
  }
}

async function verifyFirebaseIdTokenWithFallback(idToken) {
  const auth = getFirebaseAuth();
  let decoded = null;
  let verificationError = null;
  try {
    decoded = await auth.verifyIdToken(idToken, true);
  } catch (err) {
    verificationError = err;
    try {
      decoded = await auth.verifyIdToken(idToken, false);
      verificationError = null;
    } catch (err2) {
      verificationError = err2;
    }
  }
  return { decoded, verificationError };
}

function socialProviderDisplayName(provider) {
  if (provider === "google.com") return "Google";
  if (provider === "facebook.com") return "Facebook";
  return "social";
}

function isFirestoreQuotaError(err) {
  const code = String(err?.code || "");
  const details = String(err?.details || "");
  return (
    code === "8" ||
    code.toLowerCase() === "resource_exhausted" ||
    details.toLowerCase().includes("quota exceeded")
  );
}

async function sendOtpToUserPhone(user) {
  const code = Math.floor(100000 + Math.random() * 900000);
  if (typeof user.setPhoneOTP === "function") {
    user.setPhoneOTP(code);
  } else {
    await setPhoneOTPOnUser(user, code);
  }
  await user.save();
  if (user.phone) {
    await sendSMSHTD(user.phone, `رمز التحقق: ${code}`);
  }
}

async function handleSocialAuth(req, res, expectedProvider) {
  try {
    const idToken = String(req.body?.idToken || "").trim();
    if (!idToken) {
      return res.status(400).json({ message: "Social token is required." });
    }

    const { decoded, verificationError } =
      await verifyFirebaseIdTokenWithFallback(idToken);

    if (!decoded) {
      const code = String(verificationError?.code || "");
      if (process.env.NODE_ENV !== "production") {
        const payload = decodeJwtPayloadUnsafe(idToken);
        return res.status(401).json({
          message: "Invalid social token.",
          errorCode: code || "auth/invalid-id-token",
          tokenAud: payload?.aud || null,
          expectedProject: getFirebaseProjectId() || null,
        });
      }
      return res.status(401).json({ message: "Invalid social token." });
    }

    const provider = String(decoded?.firebase?.sign_in_provider || "");
    if (provider !== expectedProvider) {
      return res.status(400).json({
        message: `${socialProviderDisplayName(expectedProvider)} token is required.`,
      });
    }

    const firebaseUid = String(decoded?.uid || "").trim();
    const email = normalizeEmail(decoded?.email);
    const displayName = String(decoded?.name || "").trim();

    if (!firebaseUid) {
      return res.status(400).json({ message: "Invalid social account." });
    }

    let user = await User.findOne({ firebaseUid });
    if (!user && email) {
      user = await User.findOne({ email });
    }

    if (!user && !email) {
      return res.status(400).json({
        message:
          "Social account email is required. Please enable email access for this provider.",
      });
    }

    const mappedProvider =
      expectedProvider === "google.com" ? "google" : "facebook";

    if (!user) {
      user = new User({
        name: displayName || getDisplayNameFromEmail(email),
        email: email || undefined,
        role: "user",
        authProvider: mappedProvider,
        firebaseUid,
        phoneVerified: false,
      });
    } else {
      user.firebaseUid = firebaseUid;
      if (email && !user.email) user.email = email;
      if (!String(user.name || "").trim()) {
        user.name = displayName || getDisplayNameFromEmail(email);
      }
      if (user.authProvider !== "local") {
        user.authProvider = mappedProvider;
      }
    }

    if (!user.phone) {
      user.phoneVerified = false;
      user.phoneVerificationCodeHash = undefined;
      user.phoneVerificationExpires = undefined;
      user.phoneVerificationAttempts = 0;
      await user.save();
      return res.status(428).json({
        code: "PHONE_REQUIRED",
        userId: user._id,
        message: "يرجى إدخال رقم الجوال ثم التحقق بالرمز للمتابعة.",
      });
    }

    if (!user.phoneVerified) {
      try {
        await sendOtpToUserPhone(user);
      } catch (smsErr) {
        console.error("social auto-otp error:", smsErr);
      }

      return res.status(403).json({
        code: "NEEDS_VERIFICATION",
        message: "يجب توثيق رقم الجوال قبل تسجيل الدخول. أرسلنا رمز تحقق جديد.",
        userId: user._id,
        phone: user.phone || null,
      });
    }

    await user.save();

    const session = await issueAppSession(user);
    return res.json({
      token: session.token,
      refreshToken: session.refreshToken,
      expiresIn: session.expiresIn,
      legacyToken: session.legacyToken,
      authProvider: session.authProvider,
      user: {
        _id: user._id,
        name: user.name,
        email: user.email || null,
        role: user.role,
        phone: user.phone || null,
        phoneVerified: user.phoneVerified === true,
      },
    });
  } catch (err) {
    if (isFirestoreQuotaError(err)) {
      return res
        .status(503)
        .json({ message: "Firestore quota exceeded. Please try again later." });
    }
    const code = String(err?.code || "");
    if (code.startsWith("auth/")) {
      if (process.env.NODE_ENV !== "production") {
        const payload = decodeJwtPayloadUnsafe(req.body?.idToken);
        return res.status(401).json({
          message: "Invalid social token.",
          errorCode: code,
          tokenAud: payload?.aud || null,
          expectedProject: getFirebaseProjectId() || null,
        });
      }
      return res.status(401).json({ message: "Invalid social token." });
    }
    console.error("social auth error:", err);
    return res.status(500).json({ message: "Social auth failed." });
  }
}

/* =========================
   OTP Helpers
========================= */
function isBcryptHash(str) {
  return typeof str === "string" && /^\$2[aby]\$/.test(str);
}

async function verifyPhoneOTPHybrid(user, code) {
  if (!user.phoneVerificationCodeHash || !user.phoneVerificationExpires)
    return false;
  if (user.phoneVerificationExpires.getTime() < Date.now()) return false;

  const stored = user.phoneVerificationCodeHash;

  if (isBcryptHash(stored)) {
    try {
      const ok = await bcrypt.compare(String(code), stored);
      return !!ok;
    } catch {
      return false;
    }
  }

  const hash = crypto.createHash("sha256").update(String(code)).digest("hex");
  return hash === stored;
}

async function setPhoneOTPOnUser(user, code) {
  const hash = await bcrypt.hash(String(code), 10);
  user.phoneVerificationCodeHash = hash;
  user.phoneVerificationExpires = new Date(Date.now() + 5 * 60 * 1000); // 5 دقائق
  user.phoneVerificationAttempts = 0;
}

/* =========================
   تسجيل الدخول/إنشاء حساب عبر Social
========================= */
router.post(
  "/google",
  limiterLogin,
  validateBody(socialAuthSchema),
  async (req, res) => handleSocialAuth(req, res, "google.com")
);

router.post(
  "/facebook",
  limiterLogin,
  validateBody(socialAuthSchema),
  async (req, res) => handleSocialAuth(req, res, "facebook.com")
);

/* =========================
   إنشاء حساب
========================= */
router.post("/signup", limiterSignup, validateBody(signupSchema), async (req, res) => {
  try {
    const { name, phone, email, password } = req.body || {};

    const normPhone = phone ? normalizePhone(phone) : null;
    const normEmail = email ? normalizeEmail(email) : null;

    if ((!normPhone && !normEmail) || !password || !name) {
      return res.status(400).json({
        message:
          "أدخل جوالًا صحيحًا أو بريدًا إلكترونيًا صالحًا مع كلمة المرور والاسم",
      });
    }

    const or = [];
    if (normPhone) or.push({ phone: normPhone });
    if (normEmail) or.push({ email: normEmail });

    let existing = null;
    if (or.length > 0) {
      existing = await User.findOne({ $or: or }).lean();
    }

    if (existing) {
      return res
        .status(409)
        .json({ message: "الحساب موجود مسبقًا لهذا البريد/الجوال" });
    }

    const hash = await bcrypt.hash(String(password), 10);

    const user = new User({
      name: String(name || "").trim(),
      email: normEmail || undefined,
      phone: normPhone || undefined,
      password: hash,
      role: "user",
      phoneVerified: false,
      phoneVerificationAttempts: 0,
    });

    const code = Math.floor(100000 + Math.random() * 900000);

    if (typeof user.setPhoneOTP === "function") {
      user.setPhoneOTP(code); // قد تستخدم SHA-256 بناءً على الـ Model
    } else {
      await setPhoneOTPOnUser(user, code); // احتياطي (bcrypt)
    }

    await user.save();

    if (user.phone) {
      await sendSMSHTD(user.phone, `رمز التحقق: ${code}`);
    }

    return res.status(201).json({
      message: "تم إنشاء الحساب. أرسلنا رمز تحقق إلى جوالك (إن كان متاحًا).",
      userId: user._id,
      phone: user.phone || null,
    });
  } catch (err) {
    if (err && err.code === 11000) {
      const keys = Object.keys(err.keyPattern || {});
      const what = keys.length ? keys.join(", ") : "حقل فريد";
      return res.status(409).json({ message: `قيمة مكررة في ${what}` });
    }
    if (isFirestoreQuotaError(err)) {
      return res
        .status(503)
        .json({ message: "Firestore quota exceeded. Please try again later." });
    }
    console.error("signup error:", err);
    return res
      .status(500)
      .json({ message: err?.message || "حدث خطأ أثناء إنشاء الحساب" });
  }
});

/* =========================
   إرسال كود SMS (اختياري)
========================= */
router.post(
  "/send-sms-code",
  limiterSendSms,
  validateBody(sendSmsSchema),
  async (req, res) => {
  try {
    const { userId, phone } = req.body || {};

    let user = null;
    if (userId) {
      user = await User.findById(userId);
      if (!user) return res.status(404).json({ message: "المستخدم غير موجود" });

      if (phone) {
        const normalizedPhone = normalizePhone(phone);
        if (!normalizedPhone) {
          return res.status(400).json({ message: "رقم الجوال غير صالح" });
        }

        const existingByPhone = await User.findOne({ phone: normalizedPhone }).lean();
        if (existingByPhone && String(existingByPhone._id) !== String(user._id)) {
          return res.status(409).json({ message: "رقم الجوال مستخدم مسبقًا." });
        }

        user.phone = normalizedPhone;
        user.phoneVerified = false;
      }
    } else {
      const normalizedPhone = normalizePhone(phone);
      user = await User.findOne({ phone: normalizedPhone });
      if (!user) return res.status(404).json({ message: "المستخدم غير موجود" });
    }

    if (!user.phone) {
      return res.status(400).json({ message: "أدخل رقم جوال لإرسال الرمز." });
    }

    await sendOtpToUserPhone(user);

    return res.json({
      ok: true,
      userId: user._id,
      phone: user.phone || null,
      message:
        "إن كان الجوال مسجّلًا، فقد أرسلنا رمز تحقق جديد. صالح لمدة 5 دقائق.",
    });
  } catch (err) {
    if (isFirestoreQuotaError(err)) {
      return res
        .status(503)
        .json({ message: "Firestore quota exceeded. Please try again later." });
    }
    console.error("send-sms-code error:", err);
    res.status(500).json({ error: err.message });
  }
  }
);

/* =========================
   توثيق رمز الـ SMS
========================= */
router.post(
  "/verify-sms",
  limiterVerifySms,
  validateBody(verifySmsSchema),
  async (req, res) => {
  try {
    const { userId, code } = req.body || {};
    if (!userId || !code)
      return res.status(400).json({ message: "بيانات ناقصة" });

    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: "المستخدم غير موجود" });
    if (user.phoneVerified)
      return res.json({ ok: true, message: "الهاتف موثق مسبقًا" });

    if (user.phoneVerificationAttempts >= 6) {
      return res
        .status(429)
        .json({ message: "تجاوزت حد المحاولات. اطلب رمزًا جديدًا" });
    }

    user.phoneVerificationAttempts += 1;
    const ok = await verifyPhoneOTPHybrid(user, code);

    if (!ok) {
      await user.save();
      return res.status(400).json({ message: "رمز غير صحيح أو منتهي" });
    }

    user.phoneVerified = true;
    user.phoneVerificationCodeHash = undefined;
    user.phoneVerificationExpires = undefined;
    user.phoneVerificationAttempts = 0;
    await user.save();

    const session = await issueAppSession(user);

    return res.json({
      token: session.token,
      refreshToken: session.refreshToken,
      expiresIn: session.expiresIn,
      legacyToken: session.legacyToken,
      authProvider: session.authProvider,
      user: {
        _id: user._id,
        name: user.name,
        email: user.email || null,
        role: user.role,
        phone: user.phone,
        phoneVerified: user.phoneVerified,
      },
      message: "تم توثيق رقم الهاتف بنجاح",
    });
  } catch (err) {
    if (isFirestoreQuotaError(err)) {
      return res
        .status(503)
        .json({ message: "Firestore quota exceeded. Please try again later." });
    }
    console.error("verify-sms error:", err);
    res.status(500).json({ error: err.message });
  }
  }
);

/* =========================
   تسجيل الدخول
========================= */
router.post("/login", limiterLogin, validateBody(loginSchema), async (req, res) => {
  try {
    const { phone, email, password } = req.body || {};
    if ((!phone && !email) || !password) {
      return res
        .status(400)
        .json({ message: "أدخل رقم الجوال أو البريد مع كلمة المرور" });
    }

    const query = phone
      ? { phone: normalizePhone(phone) }
      : { email: String(email).toLowerCase() };
    const user = await User.findOne(query);
    if (!user)
      return res.status(400).json({ message: "بيانات الدخول غير صحيحة" });

    if (!user.password) {
      return res.status(400).json({
        message:
          "هذا الحساب مسجل عبر تسجيل اجتماعي. استخدم Google أو Facebook.",
      });
    }

    const match = await bcrypt.compare(password, user.password);
    if (!match) return res.status(401).json({ message: "كلمة المرور خاطئة" });

    if (!user.phoneVerified) {
      try {
        const code = Math.floor(100000 + Math.random() * 900000);
        if (typeof user.setPhoneOTP === "function") {
          user.setPhoneOTP(code);
        } else {
          await setPhoneOTPOnUser(user, code);
        }
        await user.save();

        if (user.phone) {
          await sendSMSHTD(user.phone, `رمز التحقق: ${code}`);
        }
      } catch (e) {
        console.error("auto-otp-on-login error:", e);
      }

      return res.status(403).json({
        message: "يجب توثيق رقم الجوال قبل تسجيل الدخول. أرسلنا رمز تحقق جديد.",
        userId: user._id,
        phone: user.phone || null,
      });
    }

    const session = await issueAppSession(user);

    res.json({
      token: session.token,
      refreshToken: session.refreshToken,
      expiresIn: session.expiresIn,
      legacyToken: session.legacyToken,
      authProvider: session.authProvider,
      user: {
        _id: user._id,
        name: user.name,
        email: user.email || null,
        role: user.role,
        phone: user.phone,
        phoneVerified: user.phoneVerified,
      },
    });
  } catch (err) {
    if (isFirestoreQuotaError(err)) {
      return res
        .status(503)
        .json({ message: "Firestore quota exceeded. Please try again later." });
    }
    console.error("login error:", err);
    res.status(500).json({ error: err.message });
  }
});

/* =========================
   تجديد Firebase session
========================= */
router.post(
  "/session/refresh",
  validateBody(sessionRefreshSchema),
  async (req, res) => {
    try {
      const mode = getAuthMode();
      if (mode === "jwt") {
        return res.status(400).json({
          message: "Session refresh is not available in JWT-only mode.",
        });
      }

      const { refreshToken } = req.body || {};
      const session = await refreshFirebaseSession(refreshToken);
      return res.json({
        token: session.idToken,
        refreshToken: session.refreshToken,
        expiresIn: session.expiresIn,
        userId: session.userId,
      });
    } catch (err) {
      console.error("session refresh error:", err?.message || err);
      return res.status(401).json({ message: "تعذر تجديد الجلسة" });
    }
  }
);

/* =========================
   جلب المستخدم الحالي
========================= */
router.get("/me", verifyToken, async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ message: "توكن غير صالح أو منتهي" });
    }

    const user = await User.findById(userId)
      .select("_id name email phone role phoneVerified")
      .lean();

    if (!user) {
      return res.status(404).json({ message: "المستخدم غير موجود" });
    }

    return res.json({
      _id: user._id,
      name: user.name,
      email: user.email || null,
      phone: user.phone || null,
      role: user.role || "user",
      phoneVerified: user.phoneVerified === true,
    });
  } catch (err) {
    if (isFirestoreQuotaError(err)) {
      return res
        .status(503)
        .json({ message: "Firestore quota exceeded. Please try again later." });
    }
    console.error("auth/me error:", err);
    return res.status(500).json({ message: "تعذر جلب بيانات المستخدم" });
  }
});

/* =========================
   نسيت كلمة المرور — طلب كود
========================= */
router.post(
  "/password/request-reset",
  limiterPasswordRequest,
  validateBody(passwordRequestSchema),
  async (req, res) => {
  try {
    const { phone, email } = req.body || {};
    if (!phone && !email) {
      return res
        .status(400)
        .json({ message: "أدخل رقم الجوال أو البريد لإرسال رمز الاستعادة" });
    }

    const user = phone
      ? await User.findOne({ phone: normalizePhone(phone) })
      : await User.findOne({ email: String(email).toLowerCase() });

    if (!user) {
      return res.json({
        message: "إن كان الحساب موجودًا سنرسل رمز الاستعادة إلى بياناتك.",
      });
    }

    const code = Math.floor(100000 + Math.random() * 900000);

    const hash = await bcrypt.hash(String(code), 10);
    user.resetPasswordCodeHash = hash;
    user.resetPasswordExpires = new Date(Date.now() + 10 * 60 * 1000);
    user.resetPasswordAttempts = 0;
    await user.save();

    if (user.phone) {
      await sendSMSHTD(user.phone, `رمز الاستعادة: ${code}`);
    }

    return res.json({
      message: "إن كان الحساب موجودًا سنرسل لك رمز الاستعادة (صالح 10 دقائق).",
    });
  } catch (err) {
    if (isFirestoreQuotaError(err)) {
      return res
        .status(503)
        .json({ message: "Firestore quota exceeded. Please try again later." });
    }
    console.error("password-request error:", err);
    res.status(500).json({ error: err.message });
  }
  }
);

/* =========================
   استكمال إعادة التعيين
========================= */
router.post(
  "/password/reset",
  limiterPasswordReset,
  validateBody(passwordResetSchema),
  async (req, res) => {
  try {
    const { token, password, email, phone } = req.body || {};
    if (!token || !password || (!email && !phone)) {
      return res.status(400).json({ message: "بيانات ناقصة" });
    }

    const normalizedEmail = normalizeEmail(email);
    const normalizedPhone = phone ? normalizePhone(phone) : null;

    const user = normalizedEmail
      ? await User.findOne({ email: normalizedEmail })
      : await User.findOne({ phone: normalizedPhone });

    if (!user) {
      return res.status(400).json({ message: "رمز غير صحيح أو منتهي" });
    }

    if (
      !user.resetPasswordCodeHash ||
      !user.resetPasswordExpires ||
      user.resetPasswordExpires.getTime() < Date.now()
    ) {
      return res.status(400).json({ message: "رمز غير صحيح أو منتهي" });
    }

    const attempts = Number.isFinite(Number(user.resetPasswordAttempts))
      ? Number(user.resetPasswordAttempts)
      : 0;
    if (attempts >= RESET_PASSWORD_MAX_ATTEMPTS) {
      return res
        .status(429)
        .json({ message: RESET_PASSWORD_THROTTLE_MESSAGE });
    }

    const ok = await bcrypt.compare(String(token), user.resetPasswordCodeHash);
    if (!ok) {
      user.resetPasswordAttempts = attempts + 1;
      await user.save();
      if (user.resetPasswordAttempts >= RESET_PASSWORD_MAX_ATTEMPTS) {
        return res
          .status(429)
          .json({ message: RESET_PASSWORD_THROTTLE_MESSAGE });
      }
      return res.status(400).json({ message: "رمز غير صحيح أو منتهي" });
    }

    const newPassword = String(password);
    if (newPassword.length < 6) {
      return res
        .status(400)
        .json({ message: "كلمة المرور يجب أن تكون 6 أحرف على الأقل" });
    }

    user.password = await bcrypt.hash(String(newPassword), 10);
    user.resetPasswordCodeHash = undefined;
    user.resetPasswordExpires = undefined;
    user.resetPasswordAttempts = 0;

    await user.save();
    return res.json({ ok: true, message: "تم تحديث كلمة المرور بنجاح" });
  } catch (err) {
    if (isFirestoreQuotaError(err)) {
      return res
        .status(503)
        .json({ message: "Firestore quota exceeded. Please try again later." });
    }
    console.error("password-reset error:", err);
    res.status(500).json({ error: err.message });
  }
  }
);

module.exports = router;
