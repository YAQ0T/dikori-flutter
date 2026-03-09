const {
  createFirestoreModel,
} = require("../utils/firestoreModel");

const SITE_SETTINGS_DOC_ID = "main";

const defaultLocalized = () => ({ ar: "", he: "" });

const SiteSettings = createFirestoreModel({
  modelName: "SiteSettings",
  collectionName: "site_settings",
  defaults: () => ({
    seeded: false,
    hero: {
      kicker: defaultLocalized(),
      title: defaultLocalized(),
      subtitle: defaultLocalized(),
      imageUrl: "",
      calloutLabel: defaultLocalized(),
      calloutValue: defaultLocalized(),
      primaryCtaLabel: defaultLocalized(),
      secondaryCtaLabel: defaultLocalized(),
    },
    homeCategories: [],
    categoryMenu: {
      main: [],
      sub: [],
    },
    testimonialsTitle: defaultLocalized(),
    testimonials: [],
  }),
  beforeSave: (doc) => {
    const out = { ...doc };
    out.seeded = out.seeded === true;
    out.hero = out.hero && typeof out.hero === "object" ? out.hero : {};
    out.homeCategories = Array.isArray(out.homeCategories)
      ? out.homeCategories
      : [];
    out.categoryMenu = out.categoryMenu && typeof out.categoryMenu === "object"
      ? out.categoryMenu
      : { main: [], sub: [] };
    out.categoryMenu.main = Array.isArray(out.categoryMenu.main)
      ? out.categoryMenu.main
      : [];
    out.categoryMenu.sub = Array.isArray(out.categoryMenu.sub)
      ? out.categoryMenu.sub
      : [];
    out.testimonials = Array.isArray(out.testimonials) ? out.testimonials : [];
    return out;
  },
  staticMethods: {
    async getSingleton() {
      let doc = await this.findById(SITE_SETTINGS_DOC_ID);
      if (!doc) {
        doc = await this.create({ _id: SITE_SETTINGS_DOC_ID });
      }
      return doc;
    },
  },
});

module.exports = SiteSettings;
