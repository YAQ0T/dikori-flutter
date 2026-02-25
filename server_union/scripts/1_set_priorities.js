// server/scripts/1_set_priorities.js
require("dotenv").config();
const mongoose = require("mongoose");
const Product = require("../models/Product");

const MONGO_URI = process.env.MONGO_URI;

// ✅ عدّل القيم حسب حاجتك
// وضع منتجات معيّنة إلى A/B/C عبر الـ IDs
const PRODUCT_IDS_A = [
  // "665a....", "665b...."
];
const PRODUCT_IDS_B = [
  // ...
];
const PRODUCT_IDS_C = [
  // ...
];

// أو وضع قواعد بحسب التصنيف الرئيسي/الفرعي
const CATEGORY_PRIORITY_RULES = [
  // { mainCategory: "العناية الشخصية", subCategory: "عطور", priority: "A" },
  // { mainCategory: "الأجهزة", subCategory: "سماعات", priority: "B" },
  // { mainCategory: "الأجهزة", priority: "C" }, // من دون subCategory
];

// لو أردت إعادة ضبط كل المنتجات التي بلا أولوية إلى "C"
const DEFAULT_PRIORITY_FOR_MISSING = "C"; // غيّرها أو اجعلها null لتعطيل

(async () => {
  try {
    mongoose.set("strictQuery", true);
    await mongoose.connect(MONGO_URI);
    console.log("✅ Connected");

    let modified = 0;

    // 1) عبر IDs
    if (PRODUCT_IDS_A.length) {
      const r = await Product.updateMany(
        { _id: { $in: PRODUCT_IDS_A } },
        { $set: { priority: "A" } }
      );
      modified += r.modifiedCount;
      console.log(`→ Set A for ${r.modifiedCount} products`);
    }
    if (PRODUCT_IDS_B.length) {
      const r = await Product.updateMany(
        { _id: { $in: PRODUCT_IDS_B } },
        { $set: { priority: "B" } }
      );
      modified += r.modifiedCount;
      console.log(`→ Set B for ${r.modifiedCount} products`);
    }
    if (PRODUCT_IDS_C.length) {
      const r = await Product.updateMany(
        { _id: { $in: PRODUCT_IDS_C } },
        { $set: { priority: "C" } }
      );
      modified += r.modifiedCount;
      console.log(`→ Set C for ${r.modifiedCount} products`);
    }

    // 2) عبر قواعد التصنيف
    for (const rule of CATEGORY_PRIORITY_RULES) {
      const { mainCategory, subCategory, priority } = rule;
      if (!["A", "B", "C"].includes(String(priority))) continue;

      const filter = {};
      if (mainCategory) filter.mainCategory = mainCategory;
      if (subCategory) filter.subCategory = subCategory;

      const r = await Product.updateMany(filter, { $set: { priority } });
      modified += r.modifiedCount;
      console.log(
        `→ Set ${priority} for ${r.modifiedCount} products (${
          mainCategory || "*"
        } / ${subCategory || "*"})`
      );
    }

    // 3) تعبئة الافتراضي لمن لا يملك قيمة
    if (DEFAULT_PRIORITY_FOR_MISSING) {
      const r = await Product.updateMany(
        { $or: [{ priority: { $exists: false } }, { priority: null }] },
        { $set: { priority: DEFAULT_PRIORITY_FOR_MISSING } }
      );
      modified += r.modifiedCount;
      console.log(
        `→ Defaulted ${r.modifiedCount} products to ${DEFAULT_PRIORITY_FOR_MISSING}`
      );
    }

    console.log(`✅ Done. Total modified: ${modified}`);
  } catch (e) {
    console.error("❌ Error:", e);
  } finally {
    await mongoose.connection.close();
    process.exit(0);
  }
})();
