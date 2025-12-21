// server/routes/orders.js
const express = require("express");
const router = express.Router();
const mongoose = require("mongoose");
const axios = require("axios");
const nodemailer = require("nodemailer");

const {
  verifyToken,
  verifyTokenOptional,
  isAdmin,
} = require("../middleware/authMiddleware");

const Order = require("../models/Order");
const Product = require("../models/Product");
const Variant = require("../models/Variant");
const User = require("../models/User");
const DiscountRule = require("../models/DiscountRule");
const { verifyRecaptchaToken } = require("../utils/recaptcha");
const {
  ensureLocalizedObject,
  hasAnyTranslation,
  mapLocalizedForResponse,
} = require("../utils/localized");
const { queueOrderSummarySMS } = require("../utils/orderSms");
const { issuePaymentToken } = require("../utils/paymentTokens");
const DEFAULT_RECAPTCHA_ACTION = "checkout";
const ENV_MIN_SCORE = Number(process.env.RECAPTCHA_MIN_SCORE);
const DEFAULT_RECAPTCHA_MIN_SCORE = Number.isFinite(ENV_MIN_SCORE)
  ? ENV_MIN_SCORE
  : 0.5;

const isIOSAppRequest = (req) => {
  if (!req || typeof req.get !== "function") {
    return false;
  }

  const header = req.get("x-dikori-client") || req.get("x-app-client");
  if (!header) return false;

  return String(header).trim().toLowerCase() === "ios-app";
};

async function ensureRecaptcha(req, res) {
  if (
    process.env.NODE_ENV === "test" ||
    process.env.RECAPTCHA_TEST_BYPASS === "1"
  ) {
    return true;
  }

  if (isIOSAppRequest(req)) {
    return true;
  }

  const action = isNonEmpty(req.body?.recaptchaAction)
    ? String(req.body.recaptchaAction).trim()
    : DEFAULT_RECAPTCHA_ACTION;
  const requestedMinScore = Number(req.body?.recaptchaMinScore);
  const minScore =
    Number.isFinite(requestedMinScore) && requestedMinScore >= 0
      ? requestedMinScore
      : DEFAULT_RECAPTCHA_MIN_SCORE;

  try {
    await verifyRecaptchaToken({
      token: req.body?.recaptchaToken,
      expectedAction: action,
      minScore,
    });
    return true;
  } catch (err) {
    const status = err?.statusCode || 400;
    if (status >= 500) {
      console.error("reCAPTCHA verification error:", err);
      res.status(status).json({
        message: "خطأ في التحقق من reCAPTCHA",
        error: err?.code || "RECAPTCHA_FAILED",
      });
      return false;
    }

    res.status(400).json({
      message: "فشل التحقق من reCAPTCHA",
      error: err?.code || "RECAPTCHA_FAILED",
      ...(err?.details ? { details: err.details } : {}),
    });
    return false;
  }
}

/* =============== Helpers =============== */
const LAHZA_SECRET_KEY = process.env.LAHZA_SECRET_KEY || "";
const DEFAULT_PAY_CURRENCY = process.env.PAY_CURRENCY || "ILS";
// Minor-unit tolerance shared with webhook handler
const ENV_MINOR_TOLERANCE = Number(process.env.PAYMENT_MINOR_TOLERANCE);
const MINOR_AMOUNT_TOLERANCE = Number.isFinite(ENV_MINOR_TOLERANCE)
  ? Math.max(0, Math.round(ENV_MINOR_TOLERANCE))
  : 1;
const {
  normalizeMinorAmount,
  mapVerificationPayload,
  resolveMinorAmount,
  extractCardDetails,
} = require("../utils/lahza");

async function verifyLahzaCharge(reference) {
  if (!LAHZA_SECRET_KEY) {
    const err = new Error("LAHZA_SECRET_KEY is not configured");
    err.code = "NO_SECRET";
    throw err;
  }

  const url = `https://api.lahza.io/transaction/verify/${encodeURIComponent(
    reference
  )}`;

  const { data } = await axios.get(url, {
    headers: {
      Authorization: `Bearer ${LAHZA_SECRET_KEY}`,
      "Content-Type": "application/json",
    },
    timeout: 15000,
  });

  const payload = mapVerificationPayload(data?.data || {});
  return {
    status: payload.status,
    amountMinor: payload.amountMinor,
    amount: payload.amountMinor != null ? payload.amountMinor / 100 : null,
    currency: payload.currency,
    metadata: payload.metadata,
    transactionId: payload.transactionId,
    raw: data?.data || {},
  };
}

const isNonEmpty = (s) => typeof s === "string" && s.trim().length > 0;
const toOid = (id) =>
  mongoose.isValidObjectId(id) ? new mongoose.Types.ObjectId(id) : null;
const slugify = (s) =>
  (s || "").toString().trim().toLowerCase().replace(/\s+/g, "-");

const toDisplayName = (raw) => {
  const normalized = ensureLocalizedObject(raw);
  return normalized.ar || normalized.he || "منتج";
};

function isOutOfStock(variantDoc) {
  const qty = Number(
    variantDoc?.stock && typeof variantDoc.stock.inStock !== "undefined"
      ? variantDoc.stock.inStock
      : 0
  );
  return !Number.isFinite(qty) || qty <= 0;
}

const resolveItemName = ({
  requestedName,
  productDoc,
}) => {
  const fromProduct = mapLocalizedForResponse(productDoc?.name, {
    defaultEmpty: false,
  });

  if (fromProduct && hasAnyTranslation(fromProduct)) {
    return fromProduct;
  }

  const fromRequest = ensureLocalizedObject(requestedName);
  if (hasAnyTranslation(fromRequest)) {
    return fromRequest;
  }

  return { ar: "منتج", he: "" };
};

function isDiscountActive(discount = {}) {
  if (!discount || !discount.value) return false;
  const now = new Date();
  if (discount.startAt && now < discount.startAt) return false;
  if (discount.endAt && now > discount.endAt) return false;
  return true;
}
function computeFinalAmount(price = {}) {
  const amount = typeof price.amount === "number" ? price.amount : 0;
  if (!amount) return 0;
  const discount = price.discount || {};
  if (!isDiscountActive(discount)) return amount;
  return discount.type === "amount"
    ? Math.max(0, amount - (discount.value || 0))
    : Math.max(0, amount - (amount * (discount.value || 0)) / 100);
}

async function resolveVariant({ productId, sku, measure, color }) {
  if (isNonEmpty(sku)) {
    const viaSku = await Variant.findOne({ "stock.sku": sku.trim() }).lean();
    if (viaSku) return viaSku;
  }
  const pid = toOid(productId);
  if (!pid) return null;

  const measureSlug = isNonEmpty(measure) ? slugify(measure) : null;
  const colorSlug = isNonEmpty(color) ? slugify(color) : null;

  const q = { product: pid };
  if (measureSlug) q.measureSlug = measureSlug;
  if (colorSlug) q.colorSlug = colorSlug;

  const viaDims = await Variant.findOne(q).lean();
  if (viaDims) return viaDims;

  const viaNames = await Variant.findOne({
    product: pid,
    ...(isNonEmpty(measure) ? { measure: measure } : {}),
    ...(isNonEmpty(color) ? { "color.name": color } : {}),
  }).lean();

  return viaNames || null;
}

const EMPTY_DISCOUNT = {
  applied: false,
  ruleId: null,
  type: null,
  value: 0,
  amount: 0,
  threshold: 0,
  name: "",
};

async function findBestDiscountRule(subtotal) {
  const now = new Date();
  const rule = await DiscountRule.findOne({
    isActive: true,
    threshold: { $lte: subtotal },
    $and: [
      {
        $or: [
          { startAt: null },
          { startAt: { $lte: now } },
          { startAt: { $exists: false } },
        ],
      },
      {
        $or: [
          { endAt: null },
          { endAt: { $gte: now } },
          { endAt: { $exists: false } },
        ],
      },
    ],
  })
    .sort({ threshold: -1, priority: -1, createdAt: -1 })
    .lean();

  return rule || null;
}

/* =============== Email helpers =============== */
let cachedMailTransport = null;
function createOrderMailTransport() {
  if (cachedMailTransport) return cachedMailTransport;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  if (!user || !pass) {
    throw new Error(
      "SMTP_USER/SMTP_PASS غير مهيأة في الخادم، تعذّر إرسال بريد الطلبات"
    );
  }
  cachedMailTransport = nodemailer.createTransport({
    host: process.env.SMTP_HOST || "smtp.gmail.com",
    port: Number(process.env.SMTP_PORT || 587),
    secure: String(process.env.SMTP_SECURE || "").toLowerCase() === "true",
    auth: { user, pass },
  });
  return cachedMailTransport;
}

function escapeHtml(value = "") {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function localizedToString(raw) {
  if (!raw) return "";
  if (typeof raw === "string") return raw;
  if (typeof raw === "object") {
    return raw.ar || raw.he || Object.values(raw).find(Boolean) || "";
  }
  return "";
}

function buildOrderEmailHtml(order = {}) {
  const currency = order.paymentCurrency || order.currency || "ILS";
  const fmt = (num) => `${Number(num || 0).toFixed(2)} ${currency}`;
  const customerName =
    order?.user?.name ||
    order?.guestInfo?.name ||
    (order?.isGuest ? "ضيف" : "مستخدم");
  const customerPhone = order?.user?.phone || order?.guestInfo?.phone || "";
  const customerEmail = order?.user?.email || order?.guestInfo?.email || "";
  const address = order?.address || order?.guestInfo?.address || "";
  const items = Array.isArray(order?.items) ? order.items : [];

  const rows = items
    .map((it, idx) => {
      const name = escapeHtml(localizedToString(it?.name) || "منتج");
      const color = escapeHtml(it?.color || "");
      const measure = escapeHtml(it?.measure || "");
      const sku = escapeHtml(it?.sku || "");
      const qty = Number(it?.quantity || 0);
      const unit = fmt(it?.price || 0);
      const total = fmt((it?.price || 0) * qty);
      return `<tr>
        <td>${idx + 1}</td>
        <td>${name}</td>
        <td>${color || "-"}</td>
        <td>${measure || "-"}</td>
        <td>${sku || "-"}</td>
        <td>${qty}</td>
        <td>${unit}</td>
        <td>${total}</td>
      </tr>`;
    })
    .join("\n");

  const discountAmount = order?.discount?.amount || 0;
  const createdAt = order?.createdAt
    ? new Date(order.createdAt).toLocaleString("en-GB", { hour12: false })
    : "";

  return `
    <h2>طلب جديد من المتجر</h2>
    <p>رقم الطلب: <strong>${escapeHtml(order?._id || "")}</strong></p>
    <p>الإنشاء: ${escapeHtml(createdAt)}</p>
    <p>طريقة الدفع: ${escapeHtml(order?.paymentMethod || "cod")}</p>
    <p>حالة الدفع: ${escapeHtml(order?.paymentStatus || "unpaid")}</p>
    <p>الاسم: ${escapeHtml(customerName)}</p>
    <p>الجوال: ${escapeHtml(customerPhone)}</p>
    <p>البريد: ${escapeHtml(customerEmail)}</p>
    <p>العنوان: ${escapeHtml(address)}</p>
    <p>ملاحظات: ${escapeHtml(order?.notes || "لا توجد")}</p>
    <h3>العناصر</h3>
    <table border="1" cellspacing="0" cellpadding="6" style="border-collapse:collapse;">
      <thead>
        <tr>
          <th>#</th><th>المنتج</th><th>اللون</th><th>المقاس</th><th>SKU</th><th>الكمية</th><th>السعر</th><th>الإجمالي</th>
        </tr>
      </thead>
      <tbody>
        ${rows}
      </tbody>
    </table>
    <h3>الإجماليات</h3>
    <p>المجموع قبل الخصم: ${fmt(order?.subtotal || 0)}</p>
    <p>الخصم: ${fmt(discountAmount)}</p>
    <p><strong>الإجمالي المطلوب: ${fmt(order?.total || 0)}</strong></p>
  `;
}

async function sendNewOrderEmail(orderDoc) {
  const order =
    typeof orderDoc?.toObject === "function" ? orderDoc.toObject() : orderDoc;

  const to = process.env.ORDERS_EMAIL_TO || "ama.co.12.2025@gmail.com";
  const from =
    process.env.ORDERS_EMAIL_FROM ||
    process.env.CONTACT_FROM ||
    process.env.SMTP_USER ||
    "no-reply@dikori.app";
  const subject = `طلب جديد #${order?._id || ""}`.trim();
  const html = buildOrderEmailHtml(order);

  const transport = createOrderMailTransport();
  await transport.sendMail({
    from: `"Dikori Orders" <${from}>`,
    to,
    subject,
    html,
    text: `طلب جديد من ${localizedToString(order?.user?.name) ||
      localizedToString(order?.guestInfo?.name) ||
      "عميل"}\nالإجمالي: ${order?.total}\nالمرجع: ${order?.reference || "—"}`,
  });
}

async function findEligibleRuleById(ruleId, subtotal) {
  if (!ruleId) return null;
  const now = new Date();
  const rule = await DiscountRule.findOne({
    _id: ruleId,
    isActive: true,
    threshold: { $lte: subtotal },
    $and: [
      {
        $or: [
          { startAt: null },
          { startAt: { $lte: now } },
          { startAt: { $exists: false } },
        ],
      },
      {
        $or: [
          { endAt: null },
          { endAt: { $gte: now } },
          { endAt: { $exists: false } },
        ],
      },
    ],
  }).lean();

  return rule || null;
}

function buildDiscountFromRule(rule, subtotal) {
  if (!rule) return { ...EMPTY_DISCOUNT };
  const value = Number(rule.value || 0) || 0;
  let amount = 0;

  if (rule.type === "percent") {
    amount = Math.max(0, (subtotal * value) / 100);
  } else if (rule.type === "fixed") {
    amount = Math.max(0, Math.min(value, subtotal));
  }

  return {
    applied: amount > 0,
    ruleId: rule._id || null,
    type: rule.type || null,
    value,
    amount,
    threshold: Number(rule.threshold || 0) || 0,
    name: rule.name || "",
  };
}

async function computeOrderTotals(items, incomingDiscount) {
  const subtotal = items.reduce((s, it) => s + it.price * it.quantity, 0);

  if (!subtotal) {
    return { subtotal, discount: { ...EMPTY_DISCOUNT }, total: 0 };
  }
  const maybeRuleId = toOid(incomingDiscount?.ruleId);
  const verifiedRule =
    (await findEligibleRuleById(maybeRuleId, subtotal)) ||
    (await findBestDiscountRule(subtotal));

  const discount = buildDiscountFromRule(verifiedRule, subtotal);
  const total = Math.max(0, subtotal - discount.amount);

  return { subtotal, discount, total };
}

/* ======================= إنشاء طلب COD ======================= */
router.post("/", verifyTokenOptional, async (req, res) => {
  try {
    const recaptchaOk = await ensureRecaptcha(req, res);
    if (!recaptchaOk) return;

    const {
      address,
      notes,
      items: rawItems,
      paymentMethod = "cod",
      status = "waiting_confirmation",
      discount: incomingDiscount,
    } = req.body || {};

    if (!isNonEmpty(address)) {
      return res.status(400).json({ message: "العنوان مطلوب" });
    }
    if (!Array.isArray(rawItems) || rawItems.length === 0) {
      return res.status(400).json({ message: "قائمة العناصر مطلوبة" });
    }
    if (paymentMethod !== "cod") {
      return res
        .status(400)
        .json({ message: "طريقة الدفع لهذا المسار يجب أن تكون cod" });
    }

    let userObj = undefined;
    if (req.user?.id) {
      const u = await User.findById(req.user.id).lean();
      if (u) {
        userObj = {
          _id: u._id,
          name: u.name || "",
          phone: u.phone || "",
          email: u.email || "",
        };
      }
    }

    const productCache = new Map();
    const cleanItems = [];
    for (const it of rawItems) {
      const pid = toOid(it?.productId);
      const qty = Math.max(1, parseInt(it?.quantity, 10) || 0);
      if (!pid || !qty) continue;

      let variant = null;
      if (it?.variantId && toOid(it.variantId)) {
        variant = await Variant.findOne({
          _id: toOid(it.variantId),
          product: pid,
        }).lean();
      }
      if (!variant) {
        variant = await resolveVariant({
          productId: pid,
          sku: it?.sku,
          measure: it?.measure,
          color: it?.color,
        });
      }
      if (!variant) {
        return res.status(400).json({
          message: `تعذّر إيجاد المتغيّر لعنصر: ${toDisplayName(it?.name)}`,
        });
      }

      if (isOutOfStock(variant)) {
        return res.status(409).json({
          message: `المتغيّر غير متوفر حاليًا لعنصر: ${toDisplayName(
            it?.name
          )}`,
        });
      }

      const price = computeFinalAmount(variant.price || { amount: 0 });

      let productDoc = productCache.get(String(pid));
      if (!productDoc) {
        productDoc = await Product.findById(pid, { name: 1, images: 1 }).lean();
        if (productDoc) {
          productCache.set(String(pid), productDoc);
        }
      }

      const localizedName = resolveItemName({
        requestedName: it?.name,
        productDoc,
      });

      let image = it?.image || "";
      if (!image) {
        const vcImgs = Array.isArray(variant?.color?.images)
          ? variant.color.images.filter(Boolean)
          : [];
        if (vcImgs.length) image = vcImgs[0];
        else {
          if (productDoc?.images?.length) image = productDoc.images[0];
        }
      }

      cleanItems.push({
        productId: pid,
        variantId: variant._id,
        name: localizedName,
        quantity: qty,
        price,
        color: isNonEmpty(it?.color) ? String(it.color).trim() : undefined,
        measure: isNonEmpty(it?.measure)
          ? String(it.measure).trim()
          : undefined,
        sku: isNonEmpty(it?.sku)
          ? String(it.sku).trim()
          : variant?.stock?.sku || undefined,
        image: image || undefined,
      });
    }

    if (cleanItems.length === 0) {
      return res
        .status(400)
        .json({ message: "لم يتمكّن الخادم من بناء عناصر صالحة للطلب" });
    }

    const { subtotal, discount, total } = await computeOrderTotals(
      cleanItems,
      incomingDiscount
    );

    const doc = await Order.create({
      user: userObj,
      guestInfo: { name: "", phone: "", email: "", address: "" },
      isGuest: !userObj,
      items: cleanItems,
      subtotal,
      discount,
      total,
      address: String(address).trim(),
      status: [
        "pending",
        "waiting_confirmation",
        "on_the_way",
        "delivered",
        "cancelled",
      ].includes(status)
        ? status
        : "waiting_confirmation",
      paymentMethod: "cod",
      paymentCurrency: DEFAULT_PAY_CURRENCY,
      paymentStatus: "unpaid",

      reference: null,
      notes: isNonEmpty(notes) ? String(notes).trim() : "",
    });

    queueOrderSummarySMS({
      order: doc,
      cardType: "الدفع عند الاستلام",
    });

    try {
      await sendNewOrderEmail(doc);
    } catch (err) {
      console.error("فشل إرسال بريد إشعار الطلب:", err?.message || err);
    }

    return res.status(201).json(doc);
  } catch (err) {
    console.error("POST /api/orders error:", err);
    return res.status(500).json({ message: "فشل إنشاء طلب COD" });
  }
});

/* ==================== تحضير طلب للبطاقة ==================== */
router.post("/prepare-card", verifyTokenOptional, async (req, res) => {
  try {
    const recaptchaOk = await ensureRecaptcha(req, res);
    if (!recaptchaOk) return;

    const {
      address,
      notes,
      items: rawItems,
      guestInfo,
      discount: incomingDiscount,
    } = req.body || {};

    if (!isNonEmpty(address)) {
      return res.status(400).json({ message: "العنوان مطلوب" });
    }
    if (!Array.isArray(rawItems) || rawItems.length === 0) {
      return res.status(400).json({ message: "قائمة العناصر مطلوبة" });
    }

    let userObj = undefined;
    let guestObj = { name: "", phone: "", email: "", address: "" };

    if (req.user?.id) {
      const u = await User.findById(req.user.id).lean();
      if (u) {
        userObj = {
          _id: u._id,
          name: u.name || "",
          phone: u.phone || "",
          email: u.email || "",
        };
      }
    } else if (guestInfo && typeof guestInfo === "object") {
      guestObj = {
        name: isNonEmpty(guestInfo.name) ? guestInfo.name.trim() : "",
        phone: isNonEmpty(guestInfo.phone) ? guestInfo.phone.trim() : "",
        email: isNonEmpty(guestInfo.email) ? guestInfo.email.trim() : "",
        address: isNonEmpty(guestInfo.address) ? guestInfo.address.trim() : "",
      };
    }

    const productCache = new Map();
    const cleanItems = [];
    for (const it of rawItems) {
      const pid = toOid(it?.productId);
      const qty = Math.max(1, parseInt(it?.quantity, 10) || 0);
      if (!pid || !qty) continue;

      let variant = null;
      if (it?.variantId && toOid(it.variantId)) {
        variant = await Variant.findOne({
          _id: toOid(it.variantId),
          product: pid,
        }).lean();
      }
      if (!variant) {
        variant = await resolveVariant({
          productId: pid,
          sku: it?.sku,
          measure: it?.measure,
          color: it?.color,
        });
      }
      if (!variant) {
        return res
          .status(400)
          .json({
            message: `تعذّر إيجاد المتغيّر لعنصر: ${toDisplayName(it?.name)}`,
          });
      }

      if (isOutOfStock(variant)) {
        return res.status(409).json({
          message: `المتغيّر غير متوفر حاليًا لعنصر: ${toDisplayName(
            it?.name
          )}`,
        });
      }

      const price = computeFinalAmount(variant.price || { amount: 0 });

      let productDoc = productCache.get(String(pid));
      if (!productDoc) {
        productDoc = await Product.findById(pid, { name: 1, images: 1 }).lean();
        if (productDoc) {
          productCache.set(String(pid), productDoc);
        }
      }

      const localizedName = resolveItemName({
        requestedName: it?.name,
        productDoc,
      });

      let image = it?.image || "";
      if (!image) {
        const vcImgs = Array.isArray(variant?.color?.images)
          ? variant.color.images.filter(Boolean)
          : [];
        if (vcImgs.length) image = vcImgs[0];
        else {
          if (productDoc?.images?.length) image = productDoc.images[0];
        }
      }

      cleanItems.push({
        productId: pid,
        variantId: variant._id,
        name: localizedName,
        quantity: qty,
        price,
        color: isNonEmpty(it?.color) ? String(it.color).trim() : undefined,
        measure: isNonEmpty(it?.measure)
          ? String(it.measure).trim()
          : undefined,
        sku: isNonEmpty(it?.sku)
          ? String(it.sku).trim()
          : variant?.stock?.sku || undefined,
        image: image || undefined,
      });
    }

    if (cleanItems.length === 0) {
      return res
        .status(400)
        .json({ message: "لم يتمكّن الخادم من بناء عناصر صالحة للطلب" });
    }

    const { subtotal, discount, total } = await computeOrderTotals(
      cleanItems,
      incomingDiscount
    );

    const doc = await Order.create({
      user: userObj,
      guestInfo: userObj
        ? { name: "", phone: "", email: "", address: "" }
        : guestObj,
      isGuest: !userObj,
      items: cleanItems,
      subtotal,
      discount,
      total,
      address: String(address).trim(),
      status: "waiting_confirmation",
      paymentMethod: "card",
      paymentCurrency: DEFAULT_PAY_CURRENCY,
      paymentStatus: "unpaid",
      reference: null,
      notes: isNonEmpty(notes) ? String(notes).trim() : "",
    });

    const paymentToken = issuePaymentToken(doc._id);

    try {
      await sendNewOrderEmail(doc);
    } catch (err) {
      console.error("فشل إرسال بريد إشعار الطلب:", err?.message || err);
    }

    return res
      .status(201)
      .json({ _id: doc._id, total: doc.total, paymentToken });
  } catch (err) {
    console.error("POST /api/orders/prepare-card error:", err);
    return res.status(500).json({ message: "فشل تحضير طلب البطاقة" });
  }
});

/* =========== وسم الطلب مدفوعًا بالمرجع =========== */
router.patch(
  "/by-reference/:reference/pay",
  verifyToken,
  isAdmin,
  async (req, res) => {
    try {
      const reference = String(req.params.reference || "").trim();
      if (!reference)
        return res.status(400).json({ message: "reference مطلوب" });

      const order = await Order.findOne({ reference }).lean();
      if (!order) {
        return res.status(404).json({ message: "طلب غير موجود لهذا المرجع" });
      }

      let verification;
      try {
        verification = await verifyLahzaCharge(reference);
        if (!verification || verification.status !== "success") {
          return res
            .status(400)
            .json({ message: "فشل تأكيد الدفع من لحظة لهذا المرجع" });
        }
      } catch (err) {
        if (err?.code === "NO_SECRET") {
          console.error("LAHZA_SECRET_KEY is missing when verifying payment");
          return res.status(500).json({ message: "مفتاح لحظة غير مهيأ" });
        }
        console.error("Error verifying Lahza payment:", err?.message || err);
        return res
          .status(502)
          .json({ message: "تعذر التحقق من الدفع من لحظة، حاول لاحقًا" });
      }

      const cardDetails = extractCardDetails({ verification });
      const metadataExpected = resolveMinorAmount({
        candidates: [
          verification.metadata?.expectedAmountMinor,
          verification.metadata?.amountMinor,
        ],
      });
      const fallbackExpected = Math.round(Number(order.total || 0) * 100);
      const amountMinor = resolveMinorAmount({
        candidates: [
          verification.amountMinor,
          verification.raw?.amount_minor,
          verification.raw?.amountMinor,
          verification.raw?.amount,
          verification.metadata?.amountMinor,
          verification.metadata?.expectedAmountMinor,
        ],
        expectedMinor:
          metadataExpected !== null && Number.isFinite(metadataExpected)
            ? metadataExpected
            : fallbackExpected,
      });
      const expectedMinor = Math.round(Number(order.total || 0) * 100);
      const amountDelta =
        typeof amountMinor === "number" && Number.isFinite(amountMinor)
          ? Math.abs(amountMinor - expectedMinor)
          : null;
      const amountMatches =
        typeof amountMinor === "number" && Number.isFinite(amountMinor)
          ? amountDelta <= MINOR_AMOUNT_TOLERANCE
          : false;

      const actualCurrency = (verification.currency || "")
        .toString()
        .trim()
        .toUpperCase();
      const expectedCurrency = (order.paymentCurrency || DEFAULT_PAY_CURRENCY || "")
        .toString()
        .trim()
        .toUpperCase();
      const currencyMatches = expectedCurrency
        ? actualCurrency && actualCurrency === expectedCurrency
        : true;

      const amountForStorage =
        typeof amountMinor === "number" && Number.isFinite(amountMinor)
          ? Number((amountMinor / 100).toFixed(2))
          : null;
      const transactionId = verification.transactionId || null;

      const paymentDetailsUpdate = {};
      if (amountForStorage !== null)
        paymentDetailsUpdate.paymentVerifiedAmount = amountForStorage;
      if (actualCurrency)
        paymentDetailsUpdate.paymentVerifiedCurrency = actualCurrency;
      if (transactionId)
        paymentDetailsUpdate.paymentTransactionId = String(transactionId);

      if (!amountMatches || !currencyMatches) {
        console.error("🚫 Admin pay: تعارض في مبلغ/عملة الدفع", {
          reference,
          amountMinor,
          expectedMinor,
          amountDelta,
          toleranceMinor: MINOR_AMOUNT_TOLERANCE,
          actualCurrency,
          expectedCurrency,
        });

        if (Object.keys(paymentDetailsUpdate).length) {
          await Order.updateOne({ _id: order._id }, { $set: paymentDetailsUpdate });
        }

        return res.status(400).json({
          message: "مبلغ أو عملة الدفع لا تطابق الطلب",
          details: {
            expectedAmountMinor: expectedMinor,
            actualAmountMinor: amountMinor ?? null,
            amountDelta: amountDelta ?? null,
            toleranceMinor: MINOR_AMOUNT_TOLERANCE,
            expectedCurrency,
            actualCurrency: actualCurrency || null,
          },
        });
      }

      const updateSet = {
        paymentStatus: "paid",
        status: "waiting_confirmation",
        ...paymentDetailsUpdate,
      };
      if (!order.paymentCurrency && actualCurrency) {
        updateSet.paymentCurrency = actualCurrency;
      }
      if (cardDetails.cardType) {
        updateSet.paymentCardType = cardDetails.cardType;
      }
      if (cardDetails.last4) {
        updateSet.paymentCardLast4 = cardDetails.last4;
      }

      const updated = await Order.findOneAndUpdate(
        { _id: order._id, paymentStatus: { $ne: "paid" } },
        { $set: updateSet },
        { new: true }
      ).lean();

      if (!updated) {
        await Order.updateOne({ _id: order._id }, { $set: updateSet });
        const existing = await Order.findOne({ _id: order._id }).lean();
        return res.json({ message: "الطلب مدفوع مسبقًا", order: existing });
      }

      queueOrderSummarySMS({
        order: updated,
        cardType: cardDetails.cardType,
        cardLast4: cardDetails.last4,
      });

      return res.json(updated);
    } catch (err) {
      console.error("Error marking order paid:", err);
      res.status(500).json({ message: "فشل وسم الطلب مدفوع" });
    }
  }
);
/* ==================== تفاصيل طلب بالمرجع (قراءة فقط) ==================== */
router.get("/by-reference/:reference", verifyToken, async (req, res) => {
  try {
    const reference = String(req.params.reference || "").trim();
    if (!reference) {
      return res.status(400).json({ message: "reference مطلوب" });
    }

    const order = await Order.findOne({ reference }).lean();
    if (!order) {
      return res.status(404).json({ message: "الطلب غير موجود" });
    }

    const isOwner =
      order?.user?._id && String(order.user._id) === String(req.user?.id);
    const isAdminUser = req.user?.role === "admin";

    if (!isOwner && !isAdminUser) {
      return res.status(403).json({ message: "غير مصرح" });
    }

    return res.json(order);
  } catch (err) {
    console.error("GET /api/orders/by-reference/:reference error:", err);
    return res.status(500).json({ message: "فشل في جلب تفاصيل الطلب" });
  }
});

/* ======================= طلباتي (قائمة) ======================= */
router.get("/mine", verifyToken, async (req, res) => {
  try {
    const uid = req.user?.id;
    if (!uid || !mongoose.isValidObjectId(uid)) {
      return res.status(401).json({ message: "توكن غير صالح" });
    }

    const orders = await Order.find({ "user._id": uid })
      .sort({ createdAt: -1 })
      .lean();

    return res.json(orders || []);
  } catch (err) {
    console.error("GET /api/orders/mine error:", err);
    return res.status(500).json({ message: "فشل في جلب الطلبات" });
  }
});

/* ======================= طلبات مستخدم معين (قائمة) ======================= */
router.get("/user/:id", verifyToken, async (req, res) => {
  try {
    const { id } = req.params;

    if (!mongoose.isValidObjectId(id)) {
      return res.status(400).json({ message: "معرّف المستخدم غير صالح" });
    }

    const isOwner = String(req.user?.id) === String(id);
    const isAdminUser = req.user?.role === "admin";

    if (!isOwner && !isAdminUser) {
      return res.status(403).json({ message: "غير مصرح" });
    }

    const orders = await Order.find({ "user._id": id })
      .sort({ createdAt: -1 })
      .lean();

    return res.json(orders || []);
  } catch (err) {
    console.error("GET /api/orders/user/:id error:", err);
    return res.status(500).json({ message: "فشل في جلب الطلبات" });
  }
});

/* ======================= تفاصيل طلب واحد (بالمسار الأبسط) ======================= */
router.get("/:id", verifyToken, async (req, res) => {
  try {
    const { id } = req.params;

    if (!mongoose.isValidObjectId(id)) {
      return res.status(400).json({ message: "معرّف الطلب غير صالح" });
    }

    const order = await Order.findById(id).lean();
    if (!order) return res.status(404).json({ message: "الطلب غير موجود" });

    const isOwner =
      order?.user?._id && String(order.user._id) === String(req.user?.id);
    const isAdminUser = req.user?.role === "admin";

    if (!isOwner && !isAdminUser) {
      return res.status(403).json({ message: "غير مصرح" });
    }

    return res.json(order);
  } catch (err) {
    console.error("GET /api/orders/:id error:", err);
    return res.status(500).json({ message: "فشل في جلب تفاصيل الطلب" });
  }
});

/* ======================= تفاصيل طلب واحد (يطابق مسارك الحالي) =======================
   GET /api/orders/user/:userId/order/:orderId
   - يبقي الواجهة كما هي بدون تعديل
==================================================================================== */
router.get("/user/:userId/order/:orderId", verifyToken, async (req, res) => {
  try {
    const { userId, orderId } = req.params;

    if (
      !mongoose.isValidObjectId(userId) ||
      !mongoose.isValidObjectId(orderId)
    ) {
      return res.status(400).json({ message: "معرّفات غير صالحة" });
    }

    const order = await Order.findOne({
      _id: orderId,
      "user._id": userId,
    }).lean();

    if (!order) return res.status(404).json({ message: "الطلب غير موجود" });

    const isOwner = String(req.user?.id) === String(userId);
    const isAdminUser = req.user?.role === "admin";
    if (!isOwner && !isAdminUser) {
      return res.status(403).json({ message: "غير مصرح" });
    }

    return res.json(order);
  } catch (err) {
    console.error("GET /api/orders/user/:userId/order/:orderId error:", err);
    return res.status(500).json({ message: "فشل في جلب تفاصيل الطلب" });
  }
});

/* ======================= حذف طلب (أدمن) ======================= */
router.delete("/:id", verifyToken, isAdmin, async (req, res) => {
  try {
    const { id } = req.params;

    if (!mongoose.isValidObjectId(id)) {
      return res.status(400).json({ message: "معرّف الطلب غير صالح" });
    }

    const deleted = await Order.findByIdAndDelete(id).lean();

    if (!deleted) {
      return res.status(404).json({ message: "الطلب غير موجود" });
    }

    return res.json({ message: "تم حذف الطلب", order: deleted });
  } catch (err) {
    console.error("DELETE /api/orders/:id error:", err);
    return res.status(500).json({ message: "فشل حذف الطلب" });
  }
});

/* ======================= كل الطلبات (أدمن) ======================= */
router.get("/", verifyToken, isAdmin, async (_req, res) => {
  try {
    const orders = await Order.find().sort({ createdAt: -1 }).lean();
    res.json(orders);
  } catch (err) {
    console.error("Error fetching orders:", err);
    res.status(500).json({ message: "فشل في جلب الطلبات" });
  }
});

module.exports = router;
