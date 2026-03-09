const crypto = require("crypto");
const {
  createFirestoreModel,
} = require("../utils/firestoreModel");

function normalizeEmail(email) {
  if (!email) return undefined;
  const value = String(email).trim().toLowerCase();
  return value || undefined;
}

const User = createFirestoreModel({
  modelName: "User",
  collectionName: "users",
  defaults: () => ({
    name: "",
    phone: "",
    email: undefined,
    password: "",
    authProvider: "local",
    firebaseUid: undefined,
    role: "user",
    address: {
      city: "",
      street: "",
      notes: "",
      lat: null,
      lng: null,
    },
    phoneVerified: false,
    phoneVerificationCodeHash: undefined,
    phoneVerificationExpires: undefined,
    phoneVerificationAttempts: 0,
    phoneVerificationResends: 0,
    resetPasswordCodeHash: undefined,
    resetPasswordExpires: undefined,
    resetPasswordAttempts: 0,
  }),
  beforeSave: (doc) => {
    const out = { ...doc };
    out.phone = String(out.phone || "").trim();
    out.name = String(out.name || "").trim();
    out.role = String(out.role || "user").trim() || "user";
    out.authProvider = String(out.authProvider || "local")
      .trim()
      .toLowerCase();
    if (!["local", "google", "facebook", "apple"].includes(out.authProvider)) {
      out.authProvider = "local";
    }

    const normalizedEmail = normalizeEmail(out.email);
    out.email = normalizedEmail;
    const normalizedFirebaseUid = out.firebaseUid
      ? String(out.firebaseUid).trim()
      : "";
    out.firebaseUid = normalizedFirebaseUid || undefined;

    if (!out.email || out.email === "null" || out.email === "undefined") {
      delete out.email;
    }

    if (!out.phone) {
      delete out.phone;
    }
    if (!out.phone && !out.email) {
      throw new Error("phone or email is required");
    }

    if (out.authProvider === "local" && !out.password) {
      throw new Error("password is required for local auth");
    }

    if (out.authProvider !== "local" && !out.password) {
      delete out.password;
    }

    return out;
  },
  instanceMethods: {
    setPhoneOTP(code, ttlMinutes = 10) {
      const hash = crypto
        .createHash("sha256")
        .update(String(code))
        .digest("hex");
      this.phoneVerificationCodeHash = hash;
      this.phoneVerificationExpires = new Date(
        Date.now() + Number(ttlMinutes || 10) * 60 * 1000
      );
      this.phoneVerificationAttempts = 0;
    },
    checkPhoneOTP(code) {
      if (!this.phoneVerificationCodeHash || !this.phoneVerificationExpires) {
        return false;
      }

      const expires =
        this.phoneVerificationExpires instanceof Date
          ? this.phoneVerificationExpires
          : new Date(this.phoneVerificationExpires);
      if (expires.getTime() < Date.now()) return false;

      const incoming = crypto
        .createHash("sha256")
        .update(String(code))
        .digest("hex");

      try {
        return crypto.timingSafeEqual(
          Buffer.from(incoming),
          Buffer.from(String(this.phoneVerificationCodeHash))
        );
      } catch {
        return false;
      }
    },
  },
});

module.exports = User;
