const trimOrEmpty = (value) => {
  if (value == null) return "";
  const str = String(value).trim();
  return str;
};

const ensureLocalizedObject = (raw) => {
  if (!raw || typeof raw === "undefined") {
    return { ar: "", he: "" };
  }

  if (typeof raw === "string") {
    const trimmed = raw.trim();
    return { ar: trimmed, he: "" };
  }

  if (typeof raw === "object") {
    const ar = trimOrEmpty(raw.ar);
    const he = trimOrEmpty(raw.he);
    return { ar, he };
  }

  return { ar: "", he: "" };
};

const hasArabicTranslation = (raw) => {
  const { ar } = ensureLocalizedObject(raw);
  return ar.length > 0;
};

const hasAnyTranslation = (raw) => {
  const { ar, he } = ensureLocalizedObject(raw);
  return ar.length > 0 || he.length > 0;
};

const parseLocalizedInput = (raw, options = {}) => {
  const {
    requireArabic = false,
    allowEmpty = false,
    arabicRequiredMessage = "الاسم العربي مطلوب",
  } = options;

  if (typeof raw === "undefined") {
    return { value: undefined };
  }

  if (raw === null) {
    return { value: null };
  }

  const normalized = ensureLocalizedObject(raw);

  if (requireArabic && !normalized.ar) {
    return { error: arabicRequiredMessage };
  }

  if (!allowEmpty && !normalized.ar && !normalized.he) {
    return { value: undefined };
  }

  return { value: normalized };
};

const mapLocalizedForResponse = (raw, { defaultEmpty = true } = {}) => {
  if (raw == null) {
    return defaultEmpty ? { ar: "", he: "" } : null;
  }

  return ensureLocalizedObject(raw);
};

module.exports = {
  ensureLocalizedObject,
  hasArabicTranslation,
  hasAnyTranslation,
  parseLocalizedInput,
  mapLocalizedForResponse,
};
