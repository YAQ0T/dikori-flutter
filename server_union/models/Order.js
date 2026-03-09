const {
  createFirestoreModel,
} = require("../utils/firestoreModel");
const { ensureLocalizedObject } = require("../utils/localized");

const Order = createFirestoreModel({
  modelName: "Order",
  collectionName: "orders",
  defaults: () => ({
    user: undefined,
    guestInfo: {
      name: "",
      phone: "",
      email: "",
      address: "",
    },
    isGuest: false,
    items: [],
    subtotal: 0,
    discount: {
      applied: false,
      ruleId: null,
      type: null,
      value: 0,
      amount: 0,
      threshold: 0,
      name: "",
    },
    total: 0,
    address: "",
    status: "waiting_confirmation",
    deliveredAt: undefined,
    paymentMethod: "cod",
    paymentCurrency: process.env.PAY_CURRENCY || "ILS",
    paymentStatus: "unpaid",
    reference: null,
    paymentVerifiedAmount: null,
    paymentVerifiedCurrency: "",
    paymentTransactionId: "",
    paymentCardType: "",
    paymentCardLast4: "",
    paymentStatusNote: "",
    bankTransferStatus: "",
    notes: "",
  }),
  beforeSave: (doc) => {
    const out = { ...doc };

    out.items = Array.isArray(out.items)
      ? out.items.map((item) => ({
          productId: String(item?.productId || "").trim(),
          variantId: String(item?.variantId || "").trim(),
          name: ensureLocalizedObject(item?.name),
          quantity: Math.max(1, Number(item?.quantity || 1)),
          price: Math.max(0, Number(item?.price || 0)),
          color:
            typeof item?.color === "undefined"
              ? undefined
              : String(item.color || "").trim(),
          measure:
            typeof item?.measure === "undefined"
              ? undefined
              : String(item.measure || "").trim(),
          sku:
            typeof item?.sku === "undefined"
              ? undefined
              : String(item.sku || "").trim(),
          image:
            typeof item?.image === "undefined"
              ? undefined
              : String(item.image || "").trim(),
          trackQuantity: item?.trackQuantity === true,
        }))
      : [];

    out.address = String(out.address || "").trim();
    out.notes = String(out.notes || "").trim();

    if (out.user && typeof out.user === "object") {
      out.user = {
        _id: String(out.user._id || "").trim(),
        name: String(out.user.name || "").trim(),
        phone: String(out.user.phone || "").trim(),
        email: String(out.user.email || "").trim(),
      };
      if (!out.user._id) {
        delete out.user;
      }
    }

    out.guestInfo = {
      name: String(out.guestInfo?.name || "").trim(),
      phone: String(out.guestInfo?.phone || "").trim(),
      email: String(out.guestInfo?.email || "").trim(),
      address: String(out.guestInfo?.address || "").trim(),
    };

    out.isGuest = out.isGuest === true;
    out.subtotal = Math.max(0, Number(out.subtotal || 0));
    out.total = Math.max(0, Number(out.total || 0));

    const discount = out.discount && typeof out.discount === "object" ? out.discount : {};
    out.discount = {
      applied: discount.applied === true,
      ruleId: discount.ruleId ? String(discount.ruleId) : null,
      type: discount.type || null,
      value: Number.isFinite(Number(discount.value))
        ? Math.max(0, Number(discount.value))
        : 0,
      amount: Number.isFinite(Number(discount.amount))
        ? Math.max(0, Number(discount.amount))
        : 0,
      threshold: Number.isFinite(Number(discount.threshold))
        ? Math.max(0, Number(discount.threshold))
        : 0,
      name: String(discount.name || "").trim(),
    };

    out.paymentMethod = String(out.paymentMethod || "cod").trim().toLowerCase();
    out.paymentCurrency =
      String(out.paymentCurrency || process.env.PAY_CURRENCY || "ILS")
        .trim()
        .toUpperCase();
    out.paymentStatus = String(out.paymentStatus || "unpaid").trim().toLowerCase();
    out.reference = out.reference ? String(out.reference).trim() : null;
    out.paymentVerifiedAmount =
      out.paymentVerifiedAmount == null
        ? null
        : Math.max(0, Number(out.paymentVerifiedAmount || 0));
    out.paymentVerifiedCurrency = String(out.paymentVerifiedCurrency || "")
      .trim()
      .toUpperCase();
    out.paymentTransactionId = String(out.paymentTransactionId || "").trim();
    out.paymentCardType = String(out.paymentCardType || "").trim();
    out.paymentCardLast4 = String(out.paymentCardLast4 || "").trim();
    out.paymentStatusNote = String(out.paymentStatusNote || "").trim();
    out.bankTransferStatus = String(out.bankTransferStatus || "").trim();

    if (out.deliveredAt) out.deliveredAt = new Date(out.deliveredAt);

    return out;
  },
});

module.exports = Order;
