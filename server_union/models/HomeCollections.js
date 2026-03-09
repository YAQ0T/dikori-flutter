const {
  createFirestoreModel,
} = require("../utils/firestoreModel");

const HOME_COLLECTIONS_DOC_ID = "main";

const HomeCollections = createFirestoreModel({
  modelName: "HomeCollections",
  collectionName: "home_collections",
  refs: {
    recommended: "Product",
    newArrivals: "Product",
  },
  defaults: () => ({
    recommended: [],
    newArrivals: [],
  }),
  beforeSave: (doc) => {
    const out = { ...doc };
    out.recommended = Array.isArray(out.recommended)
      ? out.recommended.map((value) => String(value || "").trim()).filter(Boolean)
      : [];
    out.newArrivals = Array.isArray(out.newArrivals)
      ? out.newArrivals.map((value) => String(value || "").trim()).filter(Boolean)
      : [];
    return out;
  },
  staticMethods: {
    async getSingleton() {
      let doc = await this.findById(HOME_COLLECTIONS_DOC_ID);
      if (!doc) {
        doc = await this.create({
          _id: HOME_COLLECTIONS_DOC_ID,
          recommended: [],
          newArrivals: [],
        });
      }
      return doc;
    },
  },
});

module.exports = HomeCollections;
