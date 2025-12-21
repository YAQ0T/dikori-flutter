require("dotenv").config();
const mongoose = require("mongoose");
const Product = require("./models/Product"); // نموذج المنتج

// 🔹 الاتصال بقاعدة البيانات من .env
mongoose
  .connect(process.env.MONGO_URI)
  .then(() => console.log("✅ MongoDB connected"))
  .catch((err) => console.error("❌ DB Error:", err));

(async () => {
  try {
    // تحديث كل المنتجات التي لا تحتوي على الحقول الجديدة
    const result = await Product.updateMany(
      {
        $or: [
          { discount: { $exists: false } },
          { tags: { $exists: false } },
          { measures: { $exists: false } },
          { colors: { $exists: false } },
          { "name.he": { $exists: false } },
          { "name.he": { $eq: null } },
          { "name.he": "" },
          { "description.he": { $exists: false } },
          { "description.he": { $eq: null } },
          { "description.he": "" },
        ],
      },
      [
        {
          $set: {
            name: {
              $cond: [
                { $eq: [{ $type: "$name" }, "object"] },
                "$name",
                {
                  ar: { $ifNull: ["$name", ""] },
                  he: "",
                },
              ],
            },
          },
        },
        {
          $set: {
            description: {
              $cond: [
                { $eq: [{ $type: "$description" }, "object"] },
                "$description",
                {
                  ar: { $ifNull: ["$description", ""] },
                  he: "",
                },
              ],
            },
          },
        },
        {
          $set: {
            discount: { $ifNull: ["$discount", 0] },
            tags: {
              $cond: [{ $isArray: "$tags" }, "$tags", []],
            },
            measures: {
              $cond: [{ $isArray: "$measures" }, "$measures", []],
            },
            colors: {
              $cond: [{ $isArray: "$colors" }, "$colors", []],
            },
            "name.he": { $ifNull: ["$name.he", ""] },
            "description.he": { $ifNull: ["$description.he", ""] },
          },
        },
      ]
    );

    console.log(`✅ Updated ${result.modifiedCount} products`);
  } catch (err) {
    console.error("❌ Error:", err);
  } finally {
    mongoose.connection.close();
  }
})();
