// server/controllers/products.controller.js
const mongoose = require("mongoose");
const Product = require("../models/Product");
const Variant = require("../models/Variant");
const { getFirestore } = require("../utils/firebaseAdmin");
const {
  slugify,
  buildWantedTags,
  readOwnershipFilterFromQuery,
} = require("../utils/filters");
const {
  parseLocalizedInput,
  ensureLocalizedObject,
  mapLocalizedForResponse,
} = require("../utils/localized");

/** تحويل ترتيب الأولويات إلى رقم للفرز */
const priorityRankExpr = {
  $switch: {
    branches: [
      { case: { $eq: ["$priority", "A"] }, then: 1 },
      { case: { $eq: ["$priority", "B"] }, then: 2 },
      { case: { $eq: ["$priority", "C"] }, then: 3 },
    ],
    default: 4,
  },
};

/** حارس بسيط لفهم limit/page */
function parsePagination(q) {
  const pageNum = Math.max(parseInt(q.page, 10) || 1, 1);
  const limitNum = Math.max(parseInt(q.limit, 10) || 9, 1);
  const skip = (pageNum - 1) * limitNum;
  return { pageNum, limitNum, skip };
}

/** اختيار طريقة الفرز */
function resolveSort(sort, locale = "ar") {
  const nameField = locale === "he" ? "name.he" : "name.ar";
  if (sort === "priceAsc") return { minPrice: 1, createdAt: -1 };
  if (sort === "priceDesc") return { minPrice: -1, createdAt: -1 };
  if (sort === "nameAsc") return { [nameField]: 1, createdAt: -1 };
  if (sort === "nameDesc") return { [nameField]: -1, createdAt: -1 };
  return { priorityRank: 1, createdAt: -1 }; // الافتراضي: الأحدث مع احترام الأولوية
}

function escapeRegex(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function buildSearchMatch(q) {
  const term = String(q || "").trim();
  if (!term) return null;

  const quoted = term.match(/"([^"]+)"/g) || [];
  const phrases = quoted
    .map((p) => p.replace(/"/g, "").trim())
    .filter(Boolean);
  const remainder = term.replace(/"([^"]+)"/g, " ").trim();
  const tokens = remainder.split(/\s+/).filter(Boolean);
  const parts = Array.from(new Set([...phrases, ...tokens])).filter(Boolean);
  if (!parts.length) return null;

  const fields = ["name.ar", "name.he", "description.ar", "description.he"];
  const clauses = parts.map((part) => {
    const escaped = escapeRegex(part).replace(/\s+/g, "\\s+");
    return {
      $or: fields.map((field) => ({
        [field]: { $regex: escaped, $options: "i" },
      })),
    };
  });

  if (clauses.length === 1) return clauses[0];
  return { $and: clauses };
}

function toFiniteAmount(value) {
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  return Number(value.toFixed(2));
}

function computeVariantDisplayPrice(variant, now = new Date()) {
  const amount = Number(variant?.price?.amount);
  if (!Number.isFinite(amount) || amount < 0) {
    return { final: null, compare: null };
  }

  const discount = variant?.price?.discount || {};
  const discountValue = Number(discount.value || 0);
  const startAt = discount.startAt ? new Date(discount.startAt) : null;
  const endAt = discount.endAt ? new Date(discount.endAt) : null;

  const isDiscountActive =
    discountValue > 0 &&
    (!startAt || startAt <= now) &&
    (!endAt || endAt >= now);

  let final = amount;
  if (isDiscountActive) {
    if (discount.type === "amount") {
      final = Math.max(0, amount - discountValue);
    } else {
      final = Math.max(0, amount - (amount * discountValue) / 100);
    }
  }

  const compareAt = Number(variant?.price?.compareAt);
  const compareCandidate = Number.isFinite(compareAt) ? compareAt : amount;
  const compare = compareCandidate > final ? compareCandidate : null;

  return { final: toFiniteAmount(final), compare: toFiniteAmount(compare) };
}

function parseBooleanInput(value) {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value === 1 ? true : value === 0 ? false : null;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (["true", "1", "yes", "on"].includes(normalized)) return true;
    if (["false", "0", "no", "off"].includes(normalized)) return false;
  }
  return null;
}

function canViewHiddenProducts(role) {
  return role === "admin" || role === "dealer";
}

function shouldIncludeHidden(req) {
  const requested = parseBooleanInput(req?.query?.includeHidden);
  if (requested !== true) return false;
  return canViewHiddenProducts(req?.user?.role);
}

function applyVisibilityFilter(target, includeHidden = false) {
  if (!includeHidden) {
    target.isVisible = { $ne: false };
  }
}

/** توحيد اسم وداتا المنتج قبل الإنشاء */
function prepareCreateData(body) {
  const {
    name,
    category,
    mainCategory,
    subCategory,
    description,
    images,
    ownershipType,
    priority,
    isVisible,
  } = body;

  const nameResult = parseLocalizedInput(name, {
    requireArabic: true,
    arabicRequiredMessage:
      "يرجى إدخال اسم المنتج باللغة العربية على الأقل",
  });
  if (nameResult.error) return { error: nameResult.error };
  const normalizedName = nameResult.value;

  if (!normalizedName) {
    return { error: "اسم المنتج مطلوب" };
  }

  if (
    !mainCategory ||
    !subCategory ||
    !Array.isArray(images) ||
    images.length === 0
  ) {
    return {
      error:
        "يرجى تعبئة الحقول الأساسية: name, mainCategory, subCategory, images[]",
    };
  }

  const data = {
    name: normalizedName,
    category: category ? String(category).trim() : undefined,
    mainCategory: String(mainCategory).trim(),
    subCategory: String(subCategory).trim(),
    images: images.map((u) => String(u)),
  };

  const descriptionResult = parseLocalizedInput(description, {
    allowEmpty: false,
    arabicRequiredMessage:
      "الوصف العربي مطلوب عند إضافة وصف جديد",
  });
  if (descriptionResult.error) return { error: descriptionResult.error };
  if (descriptionResult.value) {
    data.description = descriptionResult.value;
  }

  if (typeof ownershipType !== "undefined") {
    const v = String(ownershipType);
    if (!["ours", "local"].includes(v)) {
      return { error: "قيمة ownershipType غير صحيحة: ours | local" };
    }
    data.ownershipType = v;
  }

  if (typeof priority !== "undefined") {
    const pv = String(priority).toUpperCase();
    if (!["A", "B", "C"].includes(pv)) {
      return { error: "قيمة priority: A | B | C" };
    }
    data.priority = pv;
  }

  if (typeof isVisible !== "undefined") {
    const parsedVisibility = parseBooleanInput(isVisible);
    if (parsedVisibility === null) {
      return { error: "قيمة isVisible غير صحيحة: true | false" };
    }
    data.isVisible = parsedVisibility;
  }

  return { data };
}

function formatProduct(product) {
  if (!product) return product;
  const source =
    typeof product.toObject === "function" ? product.toObject() : product;
  return {
    ...source,
    name: mapLocalizedForResponse(source.name),
    description: mapLocalizedForResponse(source.description),
  };
}

function formatProducts(list = []) {
  return list.map((item) => formatProduct(item));
}

const FIRESTORE_PRODUCTS_READS_ENABLED =
  String(process.env.USE_FIRESTORE_PRODUCTS_READS || "false").toLowerCase() ===
  "true";
const FIRESTORE_IN_QUERY_LIMIT = 30;
const FIRESTORE_SUGGEST_CANDIDATE_LIMIT = Math.max(
  30,
  Math.min(
    Number.parseInt(process.env.FIRESTORE_SUGGEST_CANDIDATE_LIMIT || "120", 10) || 120,
    500
  )
);

function priorityRankFromValue(priority) {
  const p = String(priority || "").toUpperCase();
  if (p === "A") return 1;
  if (p === "B") return 2;
  if (p === "C") return 3;
  return 4;
}

function toTimestampMs(value) {
  if (!value) return 0;
  const date = value instanceof Date ? value : new Date(value);
  const ts = date.getTime();
  return Number.isFinite(ts) ? ts : 0;
}

function normalizeFirestoreValue(value) {
  if (Array.isArray(value)) {
    return value.map((item) => normalizeFirestoreValue(item));
  }
  if (value && typeof value.toDate === "function") {
    return value.toDate();
  }
  if (value && typeof value === "object") {
    const out = {};
    for (const [key, nested] of Object.entries(value)) {
      out[key] = normalizeFirestoreValue(nested);
    }
    return out;
  }
  return value;
}

function toFirestoreDoc(docSnap) {
  const raw = normalizeFirestoreValue(docSnap.data() || {});
  return {
    ...raw,
    _id: String(raw._id || docSnap.id),
  };
}

function buildSearchParts(q) {
  const term = String(q || "").trim();
  if (!term) return [];

  const quoted = term.match(/"([^"]+)"/g) || [];
  const phrases = quoted
    .map((p) => p.replace(/"/g, "").trim())
    .filter(Boolean);
  const remainder = term.replace(/"([^"]+)"/g, " ").trim();
  const tokens = remainder.split(/\s+/).filter(Boolean);

  return Array.from(new Set([...phrases, ...tokens]))
    .map((part) => part.toLowerCase())
    .filter(Boolean);
}

function collectSearchableTexts(product) {
  const localizedName = ensureLocalizedObject(product?.name);
  const localizedDescription = ensureLocalizedObject(product?.description);
  return [
    localizedName.ar,
    localizedName.he,
    localizedDescription.ar,
    localizedDescription.he,
  ]
    .map((v) => String(v || "").trim().toLowerCase())
    .filter(Boolean);
}

function matchesSearchParts(product, parts = []) {
  if (!parts.length) return true;
  const searchable = collectSearchableTexts(product);
  return parts.every((part) =>
    searchable.some((fieldValue) => fieldValue.includes(part))
  );
}

function includesWantedTags(variant, wantedTags = []) {
  if (!wantedTags.length) return true;
  const tags = Array.isArray(variant?.tags) ? variant.tags.map(String) : [];
  return wantedTags.every((wanted) => tags.includes(wanted));
}

function getPreferredLocalizedName(product, locale = "ar") {
  const localizedName = ensureLocalizedObject(product?.name);
  if (locale === "he") {
    return String(localizedName.he || localizedName.ar || "").trim();
  }
  return String(localizedName.ar || localizedName.he || "").trim();
}

function compareProductsBySort(a, b, { sort = "new", locale = "ar" } = {}) {
  if (sort === "priceAsc") {
    return (
      Number(a.minPrice || 0) - Number(b.minPrice || 0) ||
      toTimestampMs(b.createdAt) - toTimestampMs(a.createdAt)
    );
  }
  if (sort === "priceDesc") {
    return (
      Number(b.minPrice || 0) - Number(a.minPrice || 0) ||
      toTimestampMs(b.createdAt) - toTimestampMs(a.createdAt)
    );
  }
  if (sort === "nameAsc" || sort === "nameDesc") {
    const localeCode = locale === "he" ? "he" : "ar";
    const first = getPreferredLocalizedName(a, localeCode);
    const second = getPreferredLocalizedName(b, localeCode);
    const dir = sort === "nameAsc" ? 1 : -1;
    return (
      dir * first.localeCompare(second, localeCode, { sensitivity: "base" }) ||
      toTimestampMs(b.createdAt) - toTimestampMs(a.createdAt)
    );
  }

  return (
    priorityRankFromValue(a.priority) - priorityRankFromValue(b.priority) ||
    toTimestampMs(b.createdAt) - toTimestampMs(a.createdAt)
  );
}

function buildFirestoreProductsRef({
  mainCategory,
  subCategory,
  ownershipType,
  includeHidden = false,
}) {
  let ref = getFirestore().collection("products");
  if (ownershipType) {
    ref = ref.where("ownershipType", "==", String(ownershipType));
  }
  if (mainCategory) {
    ref = ref.where("mainCategory", "==", String(mainCategory));
  }
  if (subCategory) {
    ref = ref.where("subCategory", "==", String(subCategory));
  }
  if (!includeHidden) {
    ref = ref.where("isVisible", "==", true);
  }
  return ref;
}

async function queryFirestoreProducts({
  mainCategory,
  subCategory,
  ownershipType,
  includeHidden = false,
}) {
  const ref = buildFirestoreProductsRef({
    mainCategory,
    subCategory,
    ownershipType,
    includeHidden,
  });
  const snapshot = await ref.get();
  return snapshot.docs.map((doc) => toFirestoreDoc(doc));
}

function resolveFirestoreSortOrders(sort, locale = "ar") {
  if (sort === "nameAsc") {
    return [{ field: locale === "he" ? "name.he" : "name.ar", direction: "asc" }];
  }
  if (sort === "nameDesc") {
    return [{ field: locale === "he" ? "name.he" : "name.ar", direction: "desc" }];
  }
  // default: priority then newest first
  return [
    { field: "priority", direction: "asc" },
    { field: "createdAt", direction: "desc" },
  ];
}

function shouldUseFastFirestoreProductsPath({
  wantedTags = [],
  maxPrice,
  sort = "new",
  hasSearch = false,
}) {
  if (hasSearch) return false;
  if (Array.isArray(wantedTags) && wantedTags.length > 0) return false;
  if (typeof maxPrice !== "undefined" && maxPrice !== null && maxPrice !== "") {
    return false;
  }
  if (sort === "nameAsc" || sort === "nameDesc") return false;
  if (sort === "priceAsc" || sort === "priceDesc") return false;
  return true;
}

function chunkArray(values = [], size = 30) {
  const chunks = [];
  for (let i = 0; i < values.length; i += size) {
    chunks.push(values.slice(i, i + size));
  }
  return chunks;
}

async function loadFirestoreVariantsMap(productIds = []) {
  const ids = Array.from(
    new Set((productIds || []).map((id) => String(id || "")).filter(Boolean))
  );
  const result = new Map(ids.map((id) => [id, []]));
  if (!ids.length) return result;

  const db = getFirestore();
  const chunks = chunkArray(ids, FIRESTORE_IN_QUERY_LIMIT);
  for (const chunk of chunks) {
    const snap = await db
      .collection("variants")
      .where("productId", "in", chunk)
      .get();
    for (const doc of snap.docs) {
      const data = toFirestoreDoc(doc);
      const productId = String(data.productId || data.product || "");
      if (!productId) continue;
      if (!result.has(productId)) result.set(productId, []);
      result.get(productId).push({
        ...data,
        product: productId,
      });
    }
  }

  return result;
}

async function getFirestoreProductById(id) {
  const snap = await getFirestore().collection("products").doc(String(id)).get();
  if (!snap.exists) return null;
  return toFirestoreDoc(snap);
}

async function getFirestoreVariantsByProductId(productId) {
  const snap = await getFirestore()
    .collection("variants")
    .where("productId", "==", String(productId))
    .get();
  return snap.docs.map((doc) => {
    const data = toFirestoreDoc(doc);
    return {
      ...data,
      product: String(data.productId || data.product || productId),
    };
  });
}

const ProductsController = {
  /* =========================
   * CREATE
   * ========================= */
  async create(req, res) {
    try {
      const prepared = prepareCreateData(req.body);
      if (prepared.error)
        return res.status(400).json({ error: prepared.error });

      const product = await Product.create(prepared.data);
      return res.status(201).json(product);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  },

  /* =========================
   * READ with-stats
   * ========================= */
  async getWithStats(req, res) {
    try {
      const {
        mainCategory,
        subCategory,
        q,
        maxPrice,
        sort = "new",
        locale,
      } = req.query;

      // فلترة المُلصقات المطلوبة (tags) من كويري
      const wantedTags = buildWantedTags(req.query);

      // صلاحية رؤية المِلكية
      const role = req.user?.role;
      const canUseOwnership = role === "admin" || role === "dealer";
      const includeHidden = shouldIncludeHidden(req);
      const ownershipFilter = readOwnershipFilterFromQuery(
        req.query,
        canUseOwnership
      );

      if (FIRESTORE_PRODUCTS_READS_ENABLED) {
        const { pageNum, limitNum, skip } = parsePagination(req.query);
        const searchParts = buildSearchParts(q);
        const useFastPath = shouldUseFastFirestoreProductsPath({
          wantedTags,
          maxPrice,
          sort,
          hasSearch: searchParts.length > 0,
        });

        if (useFastPath) {
          const baseRef = buildFirestoreProductsRef({
            mainCategory,
            subCategory,
            ownershipType: ownershipFilter.ownershipType,
            includeHidden,
          });

          let pagedRef = baseRef;
          const sortOrders = resolveFirestoreSortOrders(sort, locale);
          for (const order of sortOrders) {
            pagedRef = pagedRef.orderBy(order.field, order.direction);
          }
          pagedRef = pagedRef.offset(skip).limit(limitNum);

          const countPromise =
            typeof baseRef.count === "function"
              ? baseRef.count().get()
              : baseRef.get().then((snap) => ({
                  data: () => ({ count: snap.size || 0 }),
                }));

          const [countSnap, pagedSnap] = await Promise.all([
            countPromise,
            pagedRef.get(),
          ]);

          const total = Number(countSnap?.data?.()?.count || 0);
          const totalPages = Math.ceil(total / limitNum);
          const pagedProducts = pagedSnap.docs.map((doc) => toFirestoreDoc(doc));
          const variantsMap = await loadFirestoreVariantsMap(
            pagedProducts.map((product) => product._id)
          );

          const now = new Date();
          const withStats = pagedProducts.map((product) => {
            const variants = variantsMap.get(String(product._id)) || [];
            let minPrice = null;
            let totalStock = 0;

            for (const variant of variants) {
              const stock = Number(variant?.stock?.inStock);
              if (Number.isFinite(stock)) {
                totalStock += stock;
              }

              const displayPrice = computeVariantDisplayPrice(variant, now);
              if (displayPrice.final === null) continue;
              if (minPrice === null || displayPrice.final < minPrice) {
                minPrice = displayPrice.final;
              }
            }

            return {
              ...product,
              minPrice: minPrice === null ? 0 : minPrice,
              totalStock,
            };
          });

          return res.json({
            items: formatProducts(withStats),
            total,
            totalPages,
            page: pageNum,
            limit: limitNum,
          });
        }

        const products = await queryFirestoreProducts({
          mainCategory,
          subCategory,
          ownershipType: ownershipFilter.ownershipType,
          includeHidden,
        });

        const visibleFiltered = products.filter((product) => {
          return matchesSearchParts(product, searchParts);
        });

        const variantsMap = await loadFirestoreVariantsMap(
          visibleFiltered.map((product) => product._id)
        );

        const now = new Date();
        const withStats = [];
        for (const product of visibleFiltered) {
          const variants = variantsMap.get(String(product._id)) || [];
          let minPrice = null;
          let totalStock = 0;
          let hasTagMatch = wantedTags.length === 0;

          for (const variant of variants) {
            if (!includesWantedTags(variant, wantedTags)) continue;
            hasTagMatch = true;

            const stock = Number(variant?.stock?.inStock);
            if (Number.isFinite(stock)) {
              totalStock += stock;
            }

            const displayPrice = computeVariantDisplayPrice(variant, now);
            if (displayPrice.final === null) continue;
            if (minPrice === null || displayPrice.final < minPrice) {
              minPrice = displayPrice.final;
            }
          }

          if (!hasTagMatch) continue;

          const normalizedPrice = minPrice === null ? 0 : minPrice;
          if (maxPrice && normalizedPrice > Number(maxPrice)) {
            continue;
          }

          withStats.push({
            ...product,
            minPrice: normalizedPrice,
            totalStock,
          });
        }

        withStats.sort((a, b) => compareProductsBySort(a, b, { sort, locale }));

        const paged = withStats.slice(skip, skip + limitNum);
        const total = withStats.length;
        const totalPages = Math.ceil(total / limitNum);

        return res.json({
          items: formatProducts(paged),
          total,
          totalPages,
          page: pageNum,
          limit: limitNum,
        });
      }

      // فلاتر البحث الأساسية
      const $match = { ...ownershipFilter };
      applyVisibilityFilter($match, includeHidden);
      if (mainCategory) $match.mainCategory = String(mainCategory);
      if (subCategory) $match.subCategory = String(subCategory);
      const searchMatch = buildSearchMatch(q);
      if (searchMatch) Object.assign($match, searchMatch);

      // صفحة وحدّ
      const { pageNum, limitNum, skip } = parsePagination(req.query);

      // ترتيب
      const $sortStage = resolveSort(sort, locale);

      // لحساب الخصومات المفعلة الآن
      const now = new Date();

      const pipeline = [
        { $match },
        { $addFields: { priorityRank: priorityRankExpr } },

        // احضار الفيريانتس
        {
          $lookup: {
            from: "variants",
            localField: "_id",
            foreignField: "product",
            as: "vars",
          },
        },

        // حقن wantedTags في الوثيقة
        { $addFields: { _wantedTags: wantedTags } },

        // فلترة الـvariants حسب التاغات المطلوبة إن وُجدت
        {
          $addFields: {
            vars: {
              $cond: [
                { $gt: [{ $size: "$_wantedTags" }, 0] },
                {
                  $filter: {
                    input: "$vars",
                    as: "v",
                    cond: { $setIsSubset: ["$_wantedTags", "$$v.tags"] },
                  },
                },
                "$vars",
              ],
            },
          },
        },

        // لو فيه tags مطلوبة، لازم يكون فيه على الأقل variant واحد بعد الفلترة
        ...(wantedTags.length
          ? [{ $match: { "vars.0": { $exists: true } } }]
          : []),

        // حساب السعر النهائي لكل variant بناءً على نافذة الخصم
        {
          $addFields: {
            _finalPrices: {
              $map: {
                input: "$vars",
                as: "v",
                in: {
                  $let: {
                    vars: {
                      amount: { $ifNull: ["$$v.price.amount", 0] },
                      dType: "$$v.price.discount.type",
                      dValue: { $ifNull: ["$$v.price.discount.value", 0] },
                      dStart: "$$v.price.discount.startAt",
                      dEnd: "$$v.price.discount.endAt",
                    },
                    in: {
                      $let: {
                        vars: {
                          isActive: {
                            $and: [
                              { $gt: ["$$dValue", 0] },
                              {
                                $or: [
                                  { $eq: ["$$dStart", null] },
                                  { $lte: ["$$dStart", now] },
                                ],
                              },
                              {
                                $or: [
                                  { $eq: ["$$dEnd", null] },
                                  { $gte: ["$$dEnd", now] },
                                ],
                              },
                            ],
                          },
                        },
                        in: {
                          $cond: [
                            "$$isActive",
                            {
                              $cond: [
                                { $eq: ["$$dType", "amount"] },
                                {
                                  $max: [
                                    0,
                                    { $subtract: ["$$amount", "$$dValue"] },
                                  ],
                                },
                                {
                                  $max: [
                                    0,
                                    {
                                      $subtract: [
                                        "$$amount",
                                        {
                                          $divide: [
                                            {
                                              $multiply: [
                                                "$$amount",
                                                "$$dValue",
                                              ],
                                            },
                                            100,
                                          ],
                                        },
                                      ],
                                    },
                                  ],
                                },
                              ],
                            },
                            "$$amount",
                          ],
                        },
                      },
                    },
                  },
                },
              },
            },
            _stocks: {
              $map: {
                input: "$vars",
                as: "v",
                in: { $ifNull: ["$$v.stock.inStock", 0] },
              },
            },
          },
        },

        // تنظيف الأسعار النهائية (إزالة null والسالب)
        {
          $addFields: {
            _finalPricesClean: {
              $filter: {
                input: "$_finalPrices",
                as: "p",
                cond: { $and: [{ $ne: ["$$p", null] }, { $gte: ["$$p", 0] }] },
              },
            },
          },
        },

        // حساب minPrice و totalStock
        {
          $addFields: {
            minPrice: {
              $cond: [
                { $gt: [{ $size: "$_finalPricesClean" }, 0] },
                { $min: "$_finalPricesClean" },
                0,
              ],
            },
            totalStock: { $sum: "$_stocks" },
          },
        },

        // فلترة بـ maxPrice إن وُجد
        ...(req.query.maxPrice
          ? [{ $match: { minPrice: { $lte: Number(maxPrice) } } }]
          : []),

        // Facet للعدّ والعناصر مع الصفحات
        {
          $facet: {
            meta: [{ $count: "total" }],
            items: [
              { $sort: $sortStage },
              { $skip: skip },
              { $limit: limitNum },
              {
                $project: {
                  name: 1,
                  description: 1,
                  images: 1,
                  mainCategory: 1,
                  subCategory: 1,
                  createdAt: 1,
                  minPrice: 1,
                  totalStock: 1,
                  ownershipType: 1,
                  priority: 1,
                  isVisible: 1,
                },
              },
            ],
          },
        },

        // إخراج نهائي أنظف
        {
          $project: {
            items: 1,
            total: { $ifNull: [{ $arrayElemAt: ["$meta.total", 0] }, 0] },
          },
        },
      ];

      const agg = Product.aggregate(pipeline);
      if (sort === "nameAsc" || sort === "nameDesc") {
        agg.collation({
          locale: locale === "he" ? "he" : "ar",
          strength: 2,
        });
      }
      const [result] = await agg;
      const total = result?.total || 0;
      const items = formatProducts(result?.items || []);
      const totalPages = Math.ceil(total / limitNum);

      return res.json({
        items,
        total,
        totalPages,
        page: pageNum,
        limit: limitNum,
      });
    } catch (err) {
      console.error("with-stats error:", err && err.stack ? err.stack : err);
      return res.status(500).json({ error: "Server error in /with-stats" });
    }
  },

  /* =========================
   * READ facets (بدون $replaceAll)
   * ========================= */
  async getFacets(req, res) {
    try {
      const { mainCategory, subCategory, q } = req.query;

      const role = req.user?.role;
      const canUseOwnership = role === "admin" || role === "dealer";
      const includeHidden = shouldIncludeHidden(req);
      const ownershipFilter = readOwnershipFilterFromQuery(
        req.query,
        canUseOwnership
      );

      if (FIRESTORE_PRODUCTS_READS_ENABLED) {
        const products = await queryFirestoreProducts({
          mainCategory,
          subCategory,
          ownershipType: ownershipFilter.ownershipType,
          includeHidden,
        });
        const searchParts = buildSearchParts(q);

        const visibleFiltered = products.filter((product) => {
          if (!includeHidden && product.isVisible === false) return false;
          return matchesSearchParts(product, searchParts);
        });

        const variantsMap = await loadFirestoreVariantsMap(
          visibleFiltered.map((product) => product._id)
        );

        const colorSlugs = new Set();
        const measureSlugs = new Set();

        for (const variants of variantsMap.values()) {
          for (const variant of variants) {
            const tags = Array.isArray(variant?.tags)
              ? variant.tags.map(String)
              : [];
            for (const tag of tags) {
              if (tag.startsWith("color:")) {
                colorSlugs.add(tag.slice(6));
              } else if (tag.startsWith("measure:")) {
                measureSlugs.add(tag.slice(8));
              }
            }
          }
        }

        const toName = (slug) =>
          String(slug || "")
            .replace(/[-_]+/g, " ")
            .trim();

        return res.json({
          colors: Array.from(colorSlugs).map((slug) => ({
            slug,
            name: toName(slug),
          })),
          measures: Array.from(measureSlugs).map((slug) => ({
            slug,
            name: toName(slug),
          })),
        });
      }

      const $match = { ...ownershipFilter };
      applyVisibilityFilter($match, includeHidden);
      if (mainCategory) $match.mainCategory = String(mainCategory);
      if (subCategory) $match.subCategory = String(subCategory);
      const searchMatch = buildSearchMatch(q);
      if (searchMatch) Object.assign($match, searchMatch);

      const pipeline = [
        { $match },
        {
          $lookup: {
            from: "variants",
            localField: "_id",
            foreignField: "product",
            as: "vars",
          },
        },
        { $unwind: "$vars" },
        { $unwind: "$vars.tags" },
        {
          $group: {
            _id: null,
            colorSlugs: {
              $addToSet: {
                $cond: [
                  { $regexMatch: { input: "$vars.tags", regex: /^color:/ } },
                  {
                    $substrBytes: [
                      "$vars.tags",
                      6, // بعد "color:"
                      { $subtract: [{ $strLenBytes: "$vars.tags" }, 6] },
                    ],
                  },
                  "$$REMOVE",
                ],
              },
            },
            measureSlugs: {
              $addToSet: {
                $cond: [
                  { $regexMatch: { input: "$vars.tags", regex: /^measure:/ } },
                  {
                    $substrBytes: [
                      "$vars.tags",
                      8, // بعد "measure:"
                      { $subtract: [{ $strLenBytes: "$vars.tags" }, 8] },
                    ],
                  },
                  "$$REMOVE",
                ],
              },
            },
          },
        },
      ];

      const [agg] = await Product.aggregate(pipeline);

      // تجهيز الإخراج في Node لتفادي $replaceAll (تشتغل على كل نسخ Mongo)
      const toName = (slug) =>
        String(slug || "")
          .replace(/[-_]+/g, " ")
          .trim();

      const colors =
        agg?.colorSlugs?.map((s) => ({ slug: s, name: toName(s) })) || [];
      const measures =
        agg?.measureSlugs?.map((s) => ({ slug: s, name: toName(s) })) || [];

      return res.json({ colors, measures });
    } catch (err) {
      console.error("facets error:", err && err.stack ? err.stack : err);
      return res.status(500).json({ error: "Server error in /facets" });
    }
  },

  /* =========================
   * READ suggestions (خفيف)
   * ========================= */
  async suggest(req, res) {
    try {
      const q = String(req.query.q || "").trim();
      if (!q || q.length < 2) {
        return res.json({ items: [] });
      }

      const limitNum = Math.max(
        1,
        Math.min(parseInt(req.query.limit, 10) || 8, 20)
      );
      const role = req.user?.role;
      const canUseOwnership = role === "admin" || role === "dealer";
      const includeHidden = shouldIncludeHidden(req);
      const ownershipFilter = readOwnershipFilterFromQuery(
        req.query,
        canUseOwnership
      );

      if (FIRESTORE_PRODUCTS_READS_ENABLED) {
        const searchParts = buildSearchParts(q);
        const baseRef = buildFirestoreProductsRef({
          ownershipType: ownershipFilter.ownershipType,
          includeHidden,
        });
        const productsSnap = await baseRef
          .orderBy("priority", "asc")
          .orderBy("createdAt", "desc")
          .limit(FIRESTORE_SUGGEST_CANDIDATE_LIMIT)
          .get();
        const products = productsSnap.docs.map((doc) => toFirestoreDoc(doc));

        const filtered = products.filter((product) => {
          return matchesSearchParts(product, searchParts);
        });

        filtered.sort((a, b) => compareProductsBySort(a, b, { sort: "new" }));
        const items = filtered.slice(0, limitNum);

        const variantsMap = await loadFirestoreVariantsMap(
          items.map((item) => item._id)
        );
        const now = new Date();
        const minPriceByProduct = new Map();

        for (const [productId, variants] of variantsMap.entries()) {
          for (const variant of variants) {
            const price = computeVariantDisplayPrice(variant, now);
            if (price.final === null) continue;

            const current = minPriceByProduct.get(productId);
            if (!current || price.final < current.price) {
              minPriceByProduct.set(productId, {
                price: price.final,
                comparePrice: price.compare,
              });
            }
          }
        }

        return res.json({
          items: (items || []).map((p) => ({
            _id: p._id,
            name: mapLocalizedForResponse(p.name),
            image: Array.isArray(p.images) ? p.images[0] || null : null,
            price: minPriceByProduct.get(String(p._id))?.price ?? null,
            comparePrice:
              minPriceByProduct.get(String(p._id))?.comparePrice ?? null,
          })),
        });
      }

      const searchMatch = buildSearchMatch(q);
      const filter = { ...ownershipFilter, ...(searchMatch || {}) };
      applyVisibilityFilter(filter, includeHidden);

      const items = await Product.find(filter, { name: 1, images: 1, price: 1 })
        .sort({ priority: 1, createdAt: -1 })
        .limit(limitNum)
        .lean();

      const productIds = items.map((item) => item._id);
      const variants = productIds.length
        ? await Variant.find(
            { product: { $in: productIds } },
            {
              product: 1,
              "price.amount": 1,
              "price.compareAt": 1,
              "price.discount": 1,
            }
          ).lean()
        : [];

      const now = new Date();
      const minPriceByProduct = new Map();
      for (const variant of variants) {
        const productId = String(variant.product || "");
        if (!productId) continue;

        const price = computeVariantDisplayPrice(variant, now);
        if (price.final === null) continue;

        const current = minPriceByProduct.get(productId);
        if (!current || price.final < current.price) {
          minPriceByProduct.set(productId, {
            price: price.final,
            comparePrice: price.compare,
          });
        }
      }

      return res.json({
        items: (items || []).map((p) => ({
          _id: p._id,
          name: mapLocalizedForResponse(p.name),
          image: Array.isArray(p.images) ? p.images[0] || null : null,
          price:
            minPriceByProduct.get(String(p._id))?.price ??
            toFiniteAmount(p.price),
          comparePrice:
            minPriceByProduct.get(String(p._id))?.comparePrice ?? null,
        })),
      });
    } catch (err) {
      console.error("suggest error:", err && err.stack ? err.stack : err);
      return res.status(500).json({ error: "Server error in /suggest" });
    }
  },

  /* =========================
   * READ all (يحترم priority)
   * ========================= */
  async list(req, res) {
    try {
      const { mainCategory, subCategory, q } = req.query;

      const role = req.user?.role;
      const canUseOwnership = role === "admin" || role === "dealer";
      const includeHidden = shouldIncludeHidden(req);
      const ownershipFilter = readOwnershipFilterFromQuery(
        req.query,
        canUseOwnership
      );

      if (FIRESTORE_PRODUCTS_READS_ENABLED) {
        const { limitNum, skip } = parsePagination({
          page: req.query.page || 1,
          limit: req.query.limit || 50,
        });
        const searchParts = buildSearchParts(q);

        if (!searchParts.length) {
          const pagedSnap = await buildFirestoreProductsRef({
            mainCategory,
            subCategory,
            ownershipType: ownershipFilter.ownershipType,
            includeHidden,
          })
            .orderBy("priority", "asc")
            .orderBy("createdAt", "desc")
            .offset(skip)
            .limit(limitNum)
            .get();
          const items = pagedSnap.docs.map((doc) => toFirestoreDoc(doc));
          return res.status(200).json(formatProducts(items));
        }

        const products = await queryFirestoreProducts({
          mainCategory,
          subCategory,
          ownershipType: ownershipFilter.ownershipType,
          includeHidden,
        });

        const filtered = products.filter((product) =>
          matchesSearchParts(product, searchParts)
        );

        filtered.sort((a, b) => compareProductsBySort(a, b, { sort: "new" }));

        return res.status(200).json(
          formatProducts(filtered.slice(skip, skip + limitNum))
        );
      }

      const filter = { ...ownershipFilter };
      applyVisibilityFilter(filter, includeHidden);
      if (mainCategory) filter.mainCategory = String(mainCategory);
      if (subCategory) filter.subCategory = String(subCategory);
      const searchMatch = buildSearchMatch(q);
      if (searchMatch) Object.assign(filter, searchMatch);

      const { pageNum, limitNum, skip } = parsePagination({
        page: req.query.page || 1,
        limit: req.query.limit || 50,
      });

      const products = await Product.find(filter)
        .sort({ priority: 1, createdAt: -1 })
        .skip(skip)
        .limit(limitNum)
        .lean();

      return res.status(200).json(formatProducts(products));
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  },

  /* =========================
   * READ one
   * ========================= */
  async getOne(req, res) {
    try {
      const withVariants = req.query.withVariants === "1";
      const { id } = req.params;
      const includeHidden = shouldIncludeHidden(req);

      if (!id || !String(id).trim()) {
        return res.status(400).json({ error: "معرّف غير صالح" });
      }

      if (FIRESTORE_PRODUCTS_READS_ENABLED) {
        const product = await getFirestoreProductById(id);
        if (!product)
          return res.status(404).json({ message: "المنتج غير موجود" });
        if (!includeHidden && product.isVisible === false) {
          return res.status(404).json({ message: "المنتج غير موجود" });
        }

        const normalizedProduct = formatProduct(product);
        if (!withVariants) return res.json(normalizedProduct);

        const variants = await getFirestoreVariantsByProductId(product._id);
        return res.json({ ...normalizedProduct, variants });
      }

      if (!mongoose.isValidObjectId(id)) {
        return res.status(400).json({ error: "معرّف غير صالح" });
      }

      const product = await Product.findById(id).lean();
      if (!product)
        return res.status(404).json({ message: "المنتج غير موجود" });
      if (!includeHidden && product.isVisible === false) {
        return res.status(404).json({ message: "المنتج غير موجود" });
      }

      const normalizedProduct = formatProduct(product);

      if (!withVariants) return res.json(normalizedProduct);

      const variants = await Variant.find({ product: product._id }).lean();
      return res.json({ ...normalizedProduct, variants });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  },

  /* =========================
   * UPDATE (يشمل priority)
   * ========================= */
  async update(req, res) {
    try {
      const { id } = req.params;

      if (!mongoose.isValidObjectId(id)) {
        return res.status(400).json({ error: "معرّف غير صالح" });
      }

      const {
        name,
        category,
        mainCategory,
        subCategory,
        description,
        images,
        ownershipType,
        priority,
        isVisible,
      } = req.body;

      const updateData = {};
      if (typeof name !== "undefined") {
        const nameResult = parseLocalizedInput(name, {
          requireArabic: true,
          arabicRequiredMessage:
            "يرجى إدخال اسم المنتج باللغة العربية على الأقل",
        });
        if (nameResult.error)
          return res.status(400).json({ error: nameResult.error });
        if (!nameResult.value)
          return res.status(400).json({ error: "اسم المنتج مطلوب" });
        updateData.name = nameResult.value;
      }
      if (typeof category !== "undefined")
        updateData.category = String(category).trim();
      if (typeof mainCategory !== "undefined")
        updateData.mainCategory = String(mainCategory).trim();
      if (typeof subCategory !== "undefined")
        updateData.subCategory = String(subCategory).trim();
      if (typeof description !== "undefined") {
        const descriptionResult = parseLocalizedInput(description, {
          allowEmpty: true,
          arabicRequiredMessage: "الوصف العربي مطلوب عند إضافة وصف جديد",
        });
        if (descriptionResult.error)
          return res.status(400).json({ error: descriptionResult.error });
        if (descriptionResult.value === undefined || descriptionResult.value === null) {
          updateData.description = { ar: "", he: "" };
        } else {
          updateData.description = descriptionResult.value;
        }
      }

      if (typeof images !== "undefined") {
        if (!Array.isArray(images))
          return res
            .status(400)
            .json({ error: "images يجب أن تكون مصفوفة سلاسل" });
        updateData.images = images.map((u) => String(u));
      }

      if (typeof ownershipType !== "undefined") {
        const v = String(ownershipType);
        if (!["ours", "local"].includes(v)) {
          return res
            .status(400)
            .json({ error: "قيمة ownershipType غير صحيحة: ours | local" });
        }
        updateData.ownershipType = v;
      }

      if (typeof priority !== "undefined") {
        const pv = String(priority).toUpperCase();
        if (!["A", "B", "C"].includes(pv)) {
          return res.status(400).json({ error: "قيمة priority: A | B | C" });
        }
        updateData.priority = pv;
      }

      if (typeof isVisible !== "undefined") {
        const parsedVisibility = parseBooleanInput(isVisible);
        if (parsedVisibility === null) {
          return res
            .status(400)
            .json({ error: "قيمة isVisible غير صحيحة: true | false" });
        }
        updateData.isVisible = parsedVisibility;
      }

      const updated = await Product.findByIdAndUpdate(id, updateData, {
        new: true,
        runValidators: true,
      }).lean();

      if (!updated) return res.status(404).json({ error: "المنتج غير موجود" });

      return res.json(formatProduct(updated));
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  },

  /* =========================
   * PATCH priority فقط
   * ========================= */
  async patchPriority(req, res) {
    try {
      const { id } = req.params;
      const { priority } = req.body;

      if (!mongoose.isValidObjectId(id)) {
        return res.status(400).json({ error: "معرّف غير صالح" });
      }

      const pv = String(priority || "C").toUpperCase();
      if (!["A", "B", "C"].includes(pv)) {
        return res.status(400).json({ error: "قيمة priority: A | B | C" });
      }

      const updated = await Product.findByIdAndUpdate(
        id,
        { priority: pv },
        { new: true, runValidators: true }
      ).lean();

      if (!updated) return res.status(404).json({ error: "المنتج غير موجود" });

      return res.json(formatProduct(updated));
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  },

  /* =========================
   * DELETE
   * ========================= */
  async remove(req, res) {
    try {
      const { id } = req.params;

      if (!mongoose.isValidObjectId(id)) {
        return res.status(400).json({ error: "معرّف غير صالح" });
      }

      const deleted = await Product.findByIdAndDelete(id).lean();
      if (!deleted) return res.status(404).json({ error: "المنتج غير موجود" });

      await Variant.deleteMany({ product: id });

      return res.json({ success: true });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  },
};

module.exports = ProductsController;
