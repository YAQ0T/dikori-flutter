const {
  createFirestoreModel,
} = require("../utils/firestoreModel");

const SITE_AD_DOC_ID = "main";

const SiteAd = createFirestoreModel({
  modelName: "SiteAd",
  collectionName: "site_ad",
  defaults: () => ({
    enabled: false,
    title: { ar: "", he: "" },
    text: { ar: "", he: "" },
    imageUrl: "",
    targetType: "none",
    targetValue: "",
    showMode: "once_per_session",
  }),
  beforeSave: (doc) => {
    const out = { ...doc };
    out.enabled = out.enabled === true;
    out.title = out.title && typeof out.title === "object" ? out.title : { ar: "", he: "" };
    out.text = out.text && typeof out.text === "object" ? out.text : { ar: "", he: "" };
    out.imageUrl = String(out.imageUrl || "").trim();
    out.targetType = ["none", "product", "url"].includes(String(out.targetType || ""))
      ? String(out.targetType)
      : "none";
    out.targetValue = String(out.targetValue || "").trim();
    out.showMode = ["once_per_session", "always"].includes(String(out.showMode || ""))
      ? String(out.showMode)
      : "once_per_session";
    return out;
  },
  staticMethods: {
    async getSingleton() {
      let doc = await this.findById(SITE_AD_DOC_ID);
      if (!doc) {
        doc = await this.create({ _id: SITE_AD_DOC_ID });
      }
      return doc;
    },
  },
});

module.exports = SiteAd;
