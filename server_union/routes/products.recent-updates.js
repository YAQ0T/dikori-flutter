const express = require("express");

const Product = require("../models/Product");
const Variant = require("../models/Variant");
const { mapLocalizedForResponse } = require("../utils/localized");
const { verifyTokenOptional } = require("../middleware/authMiddleware");

const router = express.Router();

/* ===== Helpers: نفس منطق الخصم الذي لديك ===== */
function isDiscountActive(discount = {}) {
  if (!discount || !discount.value) return false;
  const now = new Date();
  if (discount.startAt && now < discount.startAt) return false;
  if (discount.endAt && now > discount.endAt) return false;
  return true;
}

function chunkArray(values = [], size = 30) {
  const out = [];
  for (let i = 0; i < values.length; i += size) {
    out.push(values.slice(i, i + size));
  }
  return out;
}

router.get("/recent-updates", verifyTokenOptional, async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      days = 14,
      q,
      mainCategory,
      subCategory,
      ownership,
      tags,
      threshold,
    } = req.query;

    const p = Math.max(1, parseInt(page, 10) || 1);
    const l = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const daysNum = Math.max(1, parseInt(days, 10) || 14);

    const sinceDate = new Date(Date.now() - daysNum * 24 * 60 * 60 * 1000);
    const canViewHidden = req.user?.role === "admin" || req.user?.role === "dealer";
    const baseProductFilter = {};
    if (!canViewHidden) {
      baseProductFilter.isVisible = { $ne: false };
    }
    if (mainCategory) {
      baseProductFilter.mainCategory = String(mainCategory);
    }
    if (subCategory) {
      baseProductFilter.subCategory = String(subCategory);
    }
    if (ownership && ["ours", "local"].includes(String(ownership))) {
      baseProductFilter.ownershipType = String(ownership);
    }

    const productProjection =
      "_id name description images mainCategory subCategory ownershipType tags isVisible updatedAt createdAt";

    const [recentlyUpdatedProducts, recentlyCreatedProducts, recentVariants] =
      await Promise.all([
        Product.find({
          ...baseProductFilter,
          updatedAt: { $gte: sinceDate },
        })
          .select(productProjection)
          .lean(),
        Product.find({
          ...baseProductFilter,
          createdAt: { $gte: sinceDate },
        })
          .select(productProjection)
          .lean(),
        Variant.find({
          $or: [
            { updatedAt: { $gte: sinceDate } },
            { createdAt: { $gte: sinceDate } },
          ],
        })
          .select(
            "_id product productId price tags updatedAt createdAt stock measure color"
          )
          .lean(),
      ]);

    const productsById = new Map();
    const markProducts = (list = []) => {
      for (const item of list || []) {
        const id = String(item?._id || "").trim();
        if (!id) continue;
        if (!productsById.has(id)) {
          productsById.set(id, item);
        }
      }
    };
    markProducts(recentlyUpdatedProducts);
    markProducts(recentlyCreatedProducts);

    const recentVariantProductIds = Array.from(
      new Set(
        (recentVariants || [])
          .map((variant) =>
            String(variant?.productId || variant?.product || "").trim()
          )
          .filter(Boolean)
      )
    );

    const missingProductIds = recentVariantProductIds.filter(
      (id) => !productsById.has(id)
    );
    for (const chunk of chunkArray(missingProductIds, 30)) {
      const chunkProducts = await Product.find({
        ...baseProductFilter,
        _id: { $in: chunk },
      })
        .select(productProjection)
        .lean();
      markProducts(chunkProducts);
    }

    const products = Array.from(productsById.values());
    const productIds = products.map((product) => String(product?._id || "")).filter(Boolean);
    const variantsByProductId = new Map(productIds.map((id) => [id, []]));
    for (const chunk of chunkArray(productIds, 30)) {
      const chunkVariants = await Variant.find({ product: { $in: chunk } })
        .select("_id product productId price tags updatedAt createdAt stock measure color")
        .lean();
      for (const variant of chunkVariants || []) {
        const productId = String(variant?.productId || variant?.product || "").trim();
        if (!productId) continue;
        if (!variantsByProductId.has(productId)) {
          variantsByProductId.set(productId, []);
        }
        variantsByProductId.get(productId).push(variant);
      }
    }

    const recentVariantProductSet = new Set(recentVariantProductIds);

    const terms = String(q || "")
      .trim()
      .toLowerCase()
      .split(/\s+/)
      .filter(Boolean);
    const wantedTags =
      typeof tags === "string"
        ? tags
            .split(",")
            .map((t) => t.trim().toLowerCase())
            .filter(Boolean)
        : [];

    const includesSearchTerms = (doc) => {
      if (!terms.length) return true;
      const text = [
        doc?.name?.ar,
        doc?.name?.he,
        doc?.description?.ar,
        doc?.description?.he,
      ]
        .map((v) => String(v || "").toLowerCase())
        .join(" ");
      return terms.every((term) => text.includes(term));
    };

    const hasTagMatch = (doc) => {
      if (!wantedTags.length) return true;
      const docTags = Array.isArray(doc?.tags)
        ? doc.tags.map((v) => String(v || "").toLowerCase())
        : [];
      return wantedTags.some((tag) => docTags.includes(tag));
    };

    const shaped = [];
    for (const product of products || []) {
      if (!includesSearchTerms(product)) continue;
      if (!hasTagMatch(product)) continue;

      const relatedVariants =
        variantsByProductId.get(String(product?._id || "")) || [];

      const productUpdatedAt = product?.updatedAt ? new Date(product.updatedAt) : null;
      const productCreatedAt = product?.createdAt ? new Date(product.createdAt) : null;
      const productRecent =
        (productUpdatedAt && productUpdatedAt >= sinceDate) ||
        (productCreatedAt && productCreatedAt >= sinceDate);

      const variantRecent = recentVariantProductSet.has(
        String(product?._id || "")
      );

      if (!productRecent && !variantRecent) continue;

      let firstVariant = null;
      if (relatedVariants.length) {
        const [variant] = [...relatedVariants].sort((a, b) => {
          const aTs = new Date(a?.updatedAt || a?.createdAt || 0).getTime();
          const bTs = new Date(b?.updatedAt || b?.createdAt || 0).getTime();
          return bTs - aTs;
        });
        const discount = variant?.price?.discount || {};
        let finalPrice = variant?.price?.amount ?? null;
        if (variant && isDiscountActive(discount)) {
          finalPrice =
            discount.type === "percent"
              ? Math.max(
                  0,
                  Math.round(
                    (Number(variant?.price?.amount || 0) *
                      (100 - Number(discount.value || 0))) /
                      100
                  )
                )
              : Math.max(
                  0,
                  Number(variant?.price?.amount || 0) - Number(discount.value || 0)
                );
        }
        firstVariant = {
          _id: variant?._id || null,
          price: variant?.price || null,
          discount: discount || null,
          finalPrice,
        };
      }

      shaped.push({
        _id: product?._id,
        name: mapLocalizedForResponse(product?.name),
        images: Array.isArray(product?.images) ? product.images : [],
        mainCategory: product?.mainCategory || "",
        subCategory: product?.subCategory || "",
        ownershipType: product?.ownershipType || null,
        tags: Array.isArray(product?.tags) ? product.tags : [],
        updatedAt: product?.updatedAt || null,
        createdAt: product?.createdAt || null,
        firstVariant,
      });
    }

    shaped.sort((a, b) => {
      const aTs = new Date(a.updatedAt || a.createdAt || 0).getTime();
      const bTs = new Date(b.updatedAt || b.createdAt || 0).getTime();
      return bTs - aTs;
    });

    const total = shaped.length;
    const totalPages = Math.ceil(total / l);
    const paged = shaped.slice((p - 1) * l, (p - 1) * l + l);

    // threshold (min final price) optional filter
    let filtered = paged;
    const th = Number(threshold);
    if (!Number.isNaN(th)) {
      filtered = paged.filter(
        (p) => (p.firstVariant?.finalPrice ?? Infinity) >= th
      );
    }

    res.json({
      page: p,
      limit: l,
      items: filtered,
      data: filtered,
      totalPages,
      total,
      updatedSinceDays: daysNum,
      threshold,
    });
  } catch (err) {
    return res.status(500).json({
      error: "Server error in /recent-updates",
      message: err?.message || "Unknown error",
    });
  }
});

module.exports = router;
