// server/routes/products.js
const express = require("express");
const router = express.Router();
const {
  verifyToken,
  isAdmin,
  verifyTokenOptional,
} = require("../middleware/authMiddleware");

const ProductsController = require("../controllers/products.controller");

// طبّق التحقق الاختياري على كل الراوتس (يعرف الدور إن وُجد)
router.use(verifyTokenOptional);

/* =========================
 * CREATE (يدعم priority)
 * ========================= */
router.post("/", verifyToken, isAdmin, ProductsController.create);

/* =========================
 * READ with-stats (يحترم priority + فلاتر + Pagination + Sorting)
 * ========================= */
router.get("/with-stats", ProductsController.getWithStats);

/* =========================
 * READ facets (colors & measures) من Variants.tags
 * (إرجاع الأسماء جاهزة بدون استخدام $replaceAll لتفادي مشاكل نسخة Mongo)
 * ========================= */
router.get("/facets", ProductsController.getFacets);

/* =========================
 * READ all (يحترم priority)
 * ========================= */
router.get("/", ProductsController.list);

/* =========================
 * READ one (withVariants=1 اختياري)
 * ========================= */
router.get("/:id", ProductsController.getOne);

/* =========================
 * UPDATE (يشمل priority)
 * ========================= */
router.put("/:id", verifyToken, isAdmin, ProductsController.update);

/* =========================
 * PATCH priority فقط
 * ========================= */
router.patch(
  "/:id/priority",
  verifyToken,
  isAdmin,
  ProductsController.patchPriority
);

/* =========================
 * DELETE (مع حذف الـVariants)
 * ========================= */
router.delete("/:id", verifyToken, isAdmin, ProductsController.remove);

module.exports = router;
