const {
  createFirestoreModel,
} = require("../utils/firestoreModel");
const {
  ensureLocalizedObject,
  hasArabicTranslation,
  hasAnyTranslation,
} = require("../utils/localized");

function normalizeLocalized(value, { requireArabic = false } = {}) {
  const normalized = ensureLocalizedObject(value);
  if (requireArabic && !hasArabicTranslation(normalized)) {
    throw new Error("الاسم العربي مطلوب");
  }
  return normalized;
}

const Product = createFirestoreModel({
  modelName: "Product",
  collectionName: "products",
  defaults: () => ({
    name: { ar: "", he: "" },
    description: undefined,
    category: "",
    mainCategory: "",
    subCategory: "",
    images: [],
    ownershipType: "ours",
    priority: "C",
    isVisible: true,
  }),
  beforeSave: (doc) => {
    const out = { ...doc };
    out.name = normalizeLocalized(out.name, { requireArabic: true });

    const normalizedDescription = out.description
      ? ensureLocalizedObject(out.description)
      : null;
    if (normalizedDescription && hasAnyTranslation(normalizedDescription)) {
      out.description = normalizedDescription;
    } else {
      delete out.description;
    }

    out.category = String(out.category || "").trim();
    out.mainCategory = String(out.mainCategory || "").trim();
    out.subCategory = String(out.subCategory || "").trim();
    out.images = Array.isArray(out.images)
      ? out.images.map((item) => String(item || "").trim()).filter(Boolean)
      : [];

    const ownershipType = String(out.ownershipType || "ours").trim();
    out.ownershipType = ["ours", "local"].includes(ownershipType)
      ? ownershipType
      : "ours";

    const priority = String(out.priority || "C").trim().toUpperCase();
    out.priority = ["A", "B", "C"].includes(priority) ? priority : "C";
    out.isVisible = out.isVisible !== false;

    if (!out.mainCategory || !out.subCategory) {
      throw new Error("mainCategory and subCategory are required");
    }

    return out;
  },
});

module.exports = Product;
