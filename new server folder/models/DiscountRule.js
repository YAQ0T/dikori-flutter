// server/models/DiscountRule.js
const mongoose = require("mongoose");

/**
 * قاعدة خصم ديناميكية حسب مجموع الطلب (subtotal).
 * أمثلة:
 *  - threshold = 1000, type=percent, value=5   => خصم 5% إذا subtotal >= 1000
 *  - threshold = 2000, type=percent, value=10  => خصم 10% إذا subtotal >= 2000
 * يدعم تفعيل/تعطيل وفترة زمنية اختيارية.
 */

const DiscountRuleSchema = new mongoose.Schema(
  {
    name: { type: String, default: "" }, // اسم وصفي اختياري
    threshold: { type: Number, required: true, min: 0 }, // أقل مجموع لتفعيل الخصم (بالشيكل)
    type: {
      type: String,
      enum: ["percent", "fixed"],
      default: "percent",
    }, // نوع الخصم: نسبة مئوية أو قيمة ثابتة
    value: { type: Number, required: true, min: 0 }, // قيمة الخصم: إن كانت percent -> % ، وإن كانت fixed -> شيكل
    isActive: { type: Boolean, default: true },
    startAt: { type: Date, default: null }, // اختياري
    endAt: { type: Date, default: null }, // اختياري
    priority: { type: Number, default: 0 }, // لتقديم قاعدة على أخرى عند نفس الـ threshold
  },
  { timestamps: true }
);

// للاستعلام السريع: فعّالة + حد أدنى
DiscountRuleSchema.index({
  isActive: 1,
  threshold: 1,
  startAt: 1,
  endAt: 1,
  priority: -1,
});

module.exports =
  mongoose.models.DiscountRule ||
  mongoose.model("DiscountRule", DiscountRuleSchema);
