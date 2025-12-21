// server/scripts/fix-user-email-index.js
require("dotenv").config();
const mongoose = require("mongoose");

async function run() {
  try {
    const uri = process.env.MONGO_URI;
    if (!uri) throw new Error("MONGO_URI is missing");
    await mongoose.connect(uri);
    const db = mongoose.connection.db;
    const col = db.collection("users");

    console.log("🔎 إسقاط أي فهارس قديمة على email ...");
    try {
      // اسقاط الفهرس التقليدي لو كان موجودًا
      await col.dropIndex("email_1");
      console.log("✅ dropIndex email_1");
    } catch (e) {
      console.log("ℹ️ email_1 غير موجود أو تم إسقاطه سابقًا");
    }
    try {
      await col.dropIndex("uniq_email_when_string");
      console.log(
        "✅ dropIndex uniq_email_when_string (لو كان موجودًا سابقًا)"
      );
    } catch (e) {
      console.log("ℹ️ uniq_email_when_string غير موجود");
    }

    console.log("🧽 تنظيف المستندات التي تحتوي email=null أو email='' ...");
    await col.updateMany(
      { $or: [{ email: null }, { email: "" }] },
      { $unset: { email: "" } }
    );

    console.log("🧱 إنشاء فهرس فريد جزئي جديد على email ...");
    await col.createIndex(
      { email: 1 },
      {
        name: "uniq_email_when_string",
        unique: true,
        partialFilterExpression: { email: { $type: "string" } },
      }
    );

    console.log("✅ تم إصلاح الفهرس بنجاح");
    await mongoose.disconnect();
    process.exit(0);
  } catch (e) {
    console.error("❌ Migration error:", e);
    process.exit(1);
  }
}

run();
