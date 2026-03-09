const {
  createFirestoreModel,
} = require("../utils/firestoreModel");

const DiscountRule = createFirestoreModel({
  modelName: "DiscountRule",
  collectionName: "discount_rules",
  defaults: () => ({
    name: "",
    threshold: 0,
    type: "percent",
    value: 0,
    isActive: true,
    startAt: null,
    endAt: null,
    priority: 0,
  }),
  beforeSave: (doc) => {
    const out = { ...doc };
    out.name = String(out.name || "").trim();
    out.threshold = Number.isFinite(Number(out.threshold))
      ? Math.max(0, Number(out.threshold))
      : 0;
    out.type = ["percent", "fixed"].includes(String(out.type || ""))
      ? String(out.type)
      : "percent";
    out.value = Number.isFinite(Number(out.value))
      ? Math.max(0, Number(out.value))
      : 0;
    out.isActive = out.isActive !== false;
    out.startAt = out.startAt ? new Date(out.startAt) : null;
    out.endAt = out.endAt ? new Date(out.endAt) : null;
    out.priority = Number.isFinite(Number(out.priority))
      ? Number(out.priority)
      : 0;
    return out;
  },
});

module.exports = DiscountRule;
