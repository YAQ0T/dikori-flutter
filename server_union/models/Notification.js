const {
  createFirestoreModel,
} = require("../utils/firestoreModel");

const Notification = createFirestoreModel({
  modelName: "Notification",
  collectionName: "notifications",
  refs: {
    user: "User",
  },
  defaults: () => ({
    title: "",
    message: "",
    target: "all",
    user: undefined,
    readBy: [],
  }),
  beforeSave: (doc) => {
    const out = { ...doc };
    out.title = String(out.title || "").trim();
    out.message = String(out.message || "").trim();
    out.target = out.target === "user" ? "user" : "all";
    if (out.target === "user") {
      out.user = String(out.user || "").trim();
      if (!out.user) {
        throw new Error("user is required for target=user");
      }
    } else {
      delete out.user;
    }
    out.readBy = Array.isArray(out.readBy)
      ? out.readBy.map((value) => String(value || "").trim()).filter(Boolean)
      : [];
    if (!out.title) throw new Error("title is required");
    if (!out.message) throw new Error("message is required");
    return out;
  },
});

module.exports = Notification;
