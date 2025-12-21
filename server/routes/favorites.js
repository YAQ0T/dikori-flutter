const express = require("express");
const mongoose = require("mongoose");

const User = require("../models/User");
const Product = require("../models/Product");
const Variant = require("../models/Variant");
const { verifyToken } = require("../middleware/authMiddleware");
const { mapLocalizedForResponse } = require("../utils/localized");

const router = express.Router();

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

function formatProduct(product, minPrice) {
  return {
    ...product,
    name: mapLocalizedForResponse(product.name),
    description: mapLocalizedForResponse(product.description),
    minPrice,
  };
}

async function buildFavoritesPayload(favoriteIds = []) {
  const ids = favoriteIds
    .map((id) => String(id))
    .filter((id) => mongoose.isValidObjectId(id));
  if (!ids.length) return [];

  const objectIds = ids.map((id) => new mongoose.Types.ObjectId(id));
  const [products, variants] = await Promise.all([
    Product.find({ _id: { $in: objectIds } }).lean(),
    Variant.find({ product: { $in: objectIds } }, { product: 1, price: 1 }).lean(),
  ]);

  const minPriceMap = new Map();
  for (const variant of variants) {
    const productId = String(variant.product);
    const amount = computeFinalAmount(variant.price || {});
    if (!minPriceMap.has(productId) || amount < minPriceMap.get(productId)) {
      minPriceMap.set(productId, amount);
    }
  }

  const productMap = new Map(
    products.map((product) => [String(product._id), product])
  );

  return ids
    .map((id) => {
      const product = productMap.get(id);
      if (!product) return null;
      return formatProduct(product, minPriceMap.get(id) ?? 0);
    })
    .filter(Boolean);
}

router.get("/", verifyToken, async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId || !mongoose.isValidObjectId(userId)) {
      return res.status(401).json({ message: "توكن غير صالح" });
    }

    const user = await User.findById(userId).select("favorites").lean();
    if (!user) {
      return res.status(404).json({ message: "المستخدم غير موجود" });
    }

    const favorites = await buildFavoritesPayload(user.favorites || []);
    return res.json({ favorites });
  } catch (err) {
    console.error("GET /api/favorites error:", err);
    return res.status(500).json({ message: "تعذّر جلب المفضلة" });
  }
});

router.post("/toggle/:productId", verifyToken, async (req, res) => {
  try {
    const userId = req.user?.id;
    const { productId } = req.params;

    if (!userId || !mongoose.isValidObjectId(userId)) {
      return res.status(401).json({ message: "توكن غير صالح" });
    }

    if (!mongoose.isValidObjectId(productId)) {
      return res.status(400).json({ message: "معرّف المنتج غير صالح" });
    }

    const productExists = await Product.exists({ _id: productId });
    if (!productExists) {
      return res.status(404).json({ message: "المنتج غير موجود" });
    }

    const user = await User.findById(userId).select("favorites").lean();
    if (!user) {
      return res.status(404).json({ message: "المستخدم غير موجود" });
    }

    const favorites = Array.isArray(user.favorites) ? user.favorites : [];
    const isFavorite = favorites.some((id) => String(id) === productId);
    const update = isFavorite
      ? { $pull: { favorites: productId } }
      : { $addToSet: { favorites: productId } };

    const updated = await User.findByIdAndUpdate(userId, update, {
      new: true,
    })
      .select("favorites")
      .lean();

    const payload = await buildFavoritesPayload(updated?.favorites || []);

    return res.json({
      favorites: payload,
      isFavorite: !isFavorite,
    });
  } catch (err) {
    console.error("POST /api/favorites/toggle error:", err);
    return res.status(500).json({ message: "تعذّر تحديث المفضلة" });
  }
});

module.exports = router;
