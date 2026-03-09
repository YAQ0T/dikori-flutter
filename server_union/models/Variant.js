const {
  createFirestoreModel,
} = require("../utils/firestoreModel");

function slugify(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "-");
}

const Variant = createFirestoreModel({
  modelName: "Variant",
  collectionName: "variants",
  defaults: () => ({
    product: "",
    productId: "",
    measure: "",
    measureUnit: "",
    measureSlug: "",
    color: {
      name: "",
      code: "",
      images: [],
    },
    colorSlug: "",
    price: {
      currency: "USD",
      amount: 0,
      compareAt: 0,
      discount: {
        type: "percent",
        value: 0,
        startAt: undefined,
        endAt: undefined,
      },
    },
    stock: {
      inStock: 0,
      sku: "",
    },
    trackQuantity: false,
    tags: [],
  }),
  beforeSave: (doc) => {
    const out = { ...doc };

    const productId = String(out.productId || out.product || "").trim();
    if (!productId) {
      throw new Error("product is required");
    }
    out.product = productId;
    out.productId = productId;

    out.measure = String(out.measure || "").trim();
    out.measureUnit = String(out.measureUnit || "").trim();
    out.measureSlug = slugify(out.measure);

    const color = out.color && typeof out.color === "object" ? out.color : {};
    out.color = {
      name: String(color.name || "").trim(),
      code: String(color.code || "").trim(),
      images: Array.isArray(color.images)
        ? color.images.map((item) => String(item || "").trim()).filter(Boolean)
        : [],
    };
    out.colorSlug = slugify(out.color.name);

    const price = out.price && typeof out.price === "object" ? out.price : {};
    const discount =
      price.discount && typeof price.discount === "object" ? price.discount : {};

    const amount = Number(price.amount || 0);
    const compareAtRaw = price.compareAt;
    const compareAt =
      compareAtRaw == null || compareAtRaw === ""
        ? amount
        : Number(compareAtRaw || 0);

    out.price = {
      currency: String(price.currency || "USD").trim() || "USD",
      amount: Number.isFinite(amount) ? Math.max(0, amount) : 0,
      compareAt: Number.isFinite(compareAt) ? Math.max(0, compareAt) : 0,
      discount: {
        type: ["percent", "amount"].includes(String(discount.type || ""))
          ? String(discount.type)
          : "percent",
        value: Number.isFinite(Number(discount.value))
          ? Math.max(0, Number(discount.value))
          : 0,
        startAt: discount.startAt ? new Date(discount.startAt) : undefined,
        endAt: discount.endAt ? new Date(discount.endAt) : undefined,
      },
    };

    const stock = out.stock && typeof out.stock === "object" ? out.stock : {};
    out.stock = {
      inStock: Number.isFinite(Number(stock.inStock))
        ? Math.max(0, Number(stock.inStock))
        : 0,
      sku: String(stock.sku || "").trim(),
    };

    out.trackQuantity = out.trackQuantity === true;

    const baseTags = Array.isArray(out.tags)
      ? out.tags.map((item) => String(item || "").trim()).filter(Boolean)
      : [];
    const tagSet = new Set(baseTags);
    if (out.measureSlug) tagSet.add(`measure:${out.measureSlug}`);
    if (out.colorSlug) tagSet.add(`color:${out.colorSlug}`);
    if (out.color.code) {
      tagSet.add(`color_code:${String(out.color.code).toLowerCase()}`);
    }
    out.tags = Array.from(tagSet);

    if (!out.measure) {
      throw new Error("measure is required");
    }
    if (!out.color.name) {
      throw new Error("color.name is required");
    }
    if (!out.stock.sku) {
      throw new Error("stock.sku is required");
    }

    return out;
  },
});

module.exports = Variant;
