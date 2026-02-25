// server/utils/filters.js

/** slugify بسيط (يتناسب مع استخدامك) */
function slugify(s) {
  return (s || "").toString().trim().toLowerCase().replace(/\s+/g, "-");
}

/** بناء tags مطلوبة من الكويري */
function buildWantedTags(query = {}) {
  const wanted = [];

  // tags= "color:black,measure:42"
  if (query.tags) {
    const arr = String(query.tags)
      .split(",")
      .map((t) => t.trim().toLowerCase())
      .filter(Boolean);
    wanted.push(...arr);
  }

  // colorSlug / measureSlug
  if (query.colorSlug)
    wanted.push(`color:${String(query.colorSlug).toLowerCase()}`);
  if (query.measureSlug)
    wanted.push(`measure:${String(query.measureSlug).toLowerCase()}`);

  // color / measure (نحوّلهم إلى slug)
  if (query.color) wanted.push(`color:${slugify(query.color)}`);
  if (query.measure) wanted.push(`measure:${slugify(query.measure)}`);

  // إزالة التكرار
  return Array.from(new Set(wanted));
}

/** فلتر الملكية حسب الدور */
function readOwnershipFilterFromQuery(query = {}, canUseOwnership = false) {
  if (!canUseOwnership) return {};
  if (query.ownership && ["ours", "local"].includes(String(query.ownership))) {
    return { ownershipType: String(query.ownership) };
  }
  if (typeof query.isLocal !== "undefined") {
    const val = String(query.isLocal).toLowerCase();
    if (["true", "1", "yes"].includes(val)) return { ownershipType: "local" };
    if (["false", "0", "no"].includes(val)) return { ownershipType: "ours" };
  }
  return {};
}

module.exports = {
  slugify,
  buildWantedTags,
  readOwnershipFilterFromQuery,
};
