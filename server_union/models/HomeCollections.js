// server/models/HomeCollections.js
const mongoose = require("mongoose");

const HomeCollectionsSchema = new mongoose.Schema(
  {
    recommended: [{ type: mongoose.Schema.Types.ObjectId, ref: "Product" }],
    newArrivals: [{ type: mongoose.Schema.Types.ObjectId, ref: "Product" }],
  },
  { timestamps: true }
);

// نضمن وجود وثيقة واحدة فقط (Singleton)
HomeCollectionsSchema.statics.getSingleton = async function () {
  let doc = await this.findOne();
  if (!doc) {
    doc = await this.create({ recommended: [], newArrivals: [] });
  }
  return doc;
};

module.exports = mongoose.model("HomeCollections", HomeCollectionsSchema);
