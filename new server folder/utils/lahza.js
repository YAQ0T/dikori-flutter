// server/utils/lahza.js
const axios = require("axios");

const LAHZA_SECRET_KEY = process.env.LAHZA_SECRET_KEY || "";
// Minor-unit tolerance (e.g., 1 = allow 0.01 currency unit difference)
const ENV_MINOR_TOLERANCE = Number(process.env.PAYMENT_MINOR_TOLERANCE);
const MINOR_AMOUNT_TOLERANCE = Number.isFinite(ENV_MINOR_TOLERANCE)
  ? Math.max(0, Math.round(ENV_MINOR_TOLERANCE))
  : 1;

function toNumber(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (!trimmed) return null;
    const parsed = Number(trimmed);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return null;
}

function normalizeMinorAmount(...candidates) {
  return resolveMinorAmount({ candidates });
}

function resolveMinorAmount({ candidates = [], expectedMinor = null } = {}) {
  const normalizedCandidates = [];
  for (const candidate of candidates) {
    const num = toNumber(candidate);
    if (num === null) continue;
    normalizedCandidates.push(num);
  }

  const expectedValue = toNumber(expectedMinor);
  const normalizedExpected =
    expectedValue !== null && Number.isFinite(expectedValue)
      ? Math.round(expectedValue)
      : null;

  if (normalizedExpected !== null) {
    for (const num of normalizedCandidates) {
      if (Math.round(num) === normalizedExpected) {
        return normalizedExpected;
      }
    }

    for (const num of normalizedCandidates) {
      const scaledUp = Math.round(num * 100);
      if (scaledUp === normalizedExpected) {
        return scaledUp;
      }
    }

    for (const num of normalizedCandidates) {
      const scaledDown = Math.round(num / 100);
      if (scaledDown === normalizedExpected) {
        return normalizedExpected;
      }
    }
  }

  if (normalizedCandidates.length) {
    return Math.round(normalizedCandidates[0]);
  }

  return normalizedExpected;
}

function parseMetadata(raw) {
  if (!raw) return {};
  if (typeof raw === "object") {
    return raw;
  }
  if (typeof raw === "string") {
    try {
      return JSON.parse(raw);
    } catch {
      return { raw };
    }
  }
  return {};
}

function extractCurrency(data = {}, metadata = {}) {
  const value =
    data.currency ||
    data.currency_code ||
    data.currencyCode ||
    metadata.currency ||
    metadata.expectedCurrency ||
    "";
  return typeof value === "string" ? value.trim() : "";
}

function extractTransactionId(data = {}) {
  return (
    data.id ||
    data.transaction_id ||
    data.transactionId ||
    data.txn_id ||
    data.reference ||
    data.ref ||
    null
  );
}

function mapAuthorizationDetails(raw = {}) {
  if (!raw || typeof raw !== "object") return { cardType: "", last4: "" };
  const cardType =
    raw.card_type ||
    raw.cardType ||
    raw.brand ||
    raw.card_brand ||
    raw.bank ||
    "";
  const last4 =
    raw.last4 ||
    raw.last_4 ||
    raw.lastDigits ||
    raw.last_digits ||
    raw.last ||
    "";

  const normalizedType = typeof cardType === "string" ? cardType.trim() : "";
  const normalizedLast4 = typeof last4 === "string" || typeof last4 === "number"
    ? String(last4).replace(/\D+/g, "").slice(-4)
    : "";

  return {
    cardType: normalizedType || "",
    last4: normalizedLast4 || "",
  };
}

function extractCardDetails({ verification = {}, eventPayload = {} } = {}) {
  const candidates = [];
  if (verification?.raw?.authorization) {
    candidates.push(verification.raw.authorization);
  }
  if (verification?.response?.data?.authorization) {
    candidates.push(verification.response.data.authorization);
  }
  if (verification?.metadata?.authorization) {
    candidates.push(verification.metadata.authorization);
  }
  if (eventPayload?.authorization) {
    candidates.push(eventPayload.authorization);
  }
  if (eventPayload?.data?.authorization) {
    candidates.push(eventPayload.data.authorization);
  }

  for (const candidate of candidates) {
    const details = mapAuthorizationDetails(candidate);
    if (details.cardType || details.last4) {
      return details;
    }
  }

  return { cardType: "", last4: "" };
}

function mapVerificationPayload(raw = {}) {
  const metadata = parseMetadata(raw.metadata);
  const expectedMinor = resolveMinorAmount({
    candidates: [metadata.expectedAmountMinor, metadata.amountMinor],
  });
  const amountMinor = resolveMinorAmount({
    candidates: [
      raw.amount_minor,
      raw.amountMinor,
      raw.amount,
      metadata.amountMinor,
      metadata.expectedAmountMinor,
    ],
    expectedMinor,
  });

  return {
    status: String(raw.status || "").toLowerCase(),
    amountMinor,
    currency: extractCurrency(raw, metadata),
    metadata,
    transactionId: extractTransactionId(raw),
  };
}

async function verifyLahzaTransaction(reference) {
  if (!LAHZA_SECRET_KEY) {
    const err = new Error("LAHZA_SECRET_KEY is not configured");
    err.code = "NO_SECRET";
    throw err;
  }

  const url = `https://api.lahza.io/transaction/verify/${encodeURIComponent(
    reference
  )}`;

  const resp = await axios.get(url, {
    headers: {
      Authorization: `Bearer ${LAHZA_SECRET_KEY}`,
      "Content-Type": "application/json",
    },
    timeout: 15000,
  });

  const rawResponse = resp?.data || {};
  const raw = rawResponse?.data || {};
  const payload = mapVerificationPayload(raw);

  return { ...payload, raw, response: rawResponse };
}

function prepareLahzaPaymentUpdate({
  order = {},
  verification = {},
  eventPayload = null,
  tolerance = MINOR_AMOUNT_TOLERANCE,
} = {}) {
  const eventMetadata = parseMetadata(eventPayload?.metadata);
  const eventSnapshot = mapVerificationPayload({
    ...(eventPayload ? eventPayload : {}),
    metadata: eventMetadata,
  });

  const verificationExpected = resolveMinorAmount({
    candidates: [
      verification?.metadata?.expectedAmountMinor,
      verification?.metadata?.amountMinor,
    ],
  });
  const eventExpected = resolveMinorAmount({
    candidates: [
      eventSnapshot?.metadata?.expectedAmountMinor,
      eventSnapshot?.metadata?.amountMinor,
      eventMetadata?.expectedAmountMinor,
      eventMetadata?.amountMinor,
    ],
  });

  const orderExpectedMinor = Math.round(Number(order.total || 0) * 100);
  const expectedHint = Number.isFinite(verificationExpected)
    ? verificationExpected
    : Number.isFinite(eventExpected)
    ? eventExpected
    : orderExpectedMinor;

  const amountMinor = resolveMinorAmount({
    candidates: [
      verification?.amountMinor,
      eventSnapshot?.amountMinor,
      eventPayload?.amount_minor,
      eventPayload?.amountMinor,
      eventPayload?.amount,
      verification?.metadata?.amountMinor,
      verification?.metadata?.expectedAmountMinor,
      eventMetadata?.amountMinor,
      eventMetadata?.expectedAmountMinor,
    ],
    expectedMinor: expectedHint,
  });

  const verifiedCurrency = (
    verification?.currency || eventSnapshot?.currency || ""
  )
    .toString()
    .trim()
    .toUpperCase();

  const storedCurrency = (order.paymentCurrency || "").toString().trim().toUpperCase();
  const fallbackCurrency = (eventMetadata?.expectedCurrency || "")
    .toString()
    .trim()
    .toUpperCase();
  const expectedCurrency = storedCurrency || fallbackCurrency;

  const expectedMinor = orderExpectedMinor;
  const amountDelta =
    typeof amountMinor === "number" && Number.isFinite(amountMinor)
      ? Math.abs(amountMinor - expectedMinor)
      : null;
  const amountMatches =
    typeof amountMinor === "number" && Number.isFinite(amountMinor)
      ? amountDelta <= tolerance
      : false;
  const currencyMatches =
    !expectedCurrency || !verifiedCurrency
      ? true
      : verifiedCurrency === expectedCurrency;

  const amountForStorage =
    typeof amountMinor === "number" && Number.isFinite(amountMinor)
      ? Number((amountMinor / 100).toFixed(2))
      : null;
  const transactionId =
    verification?.transactionId || eventSnapshot?.transactionId || null;

  const successSet = {
    paymentStatus: "paid",
    status: "waiting_confirmation",
  };
  if (amountForStorage !== null) successSet.paymentVerifiedAmount = amountForStorage;
  if (verifiedCurrency) successSet.paymentVerifiedCurrency = verifiedCurrency;
  if (transactionId) successSet.paymentTransactionId = String(transactionId);
  if (!storedCurrency && verifiedCurrency) {
    successSet.paymentCurrency = verifiedCurrency;
  }

  const mismatchSet = {};
  if (amountForStorage !== null)
    mismatchSet.paymentVerifiedAmount = amountForStorage;
  if (verifiedCurrency) mismatchSet.paymentVerifiedCurrency = verifiedCurrency;
  if (transactionId) mismatchSet.paymentTransactionId = String(transactionId);

  const cardDetails = extractCardDetails({ verification, eventPayload });
  if (cardDetails.cardType) {
    successSet.paymentCardType = cardDetails.cardType;
    mismatchSet.paymentCardType = cardDetails.cardType;
  }
  if (cardDetails.last4) {
    successSet.paymentCardLast4 = cardDetails.last4;
    mismatchSet.paymentCardLast4 = cardDetails.last4;
  }

  return {
    amountMatches,
    currencyMatches,
    amountMinor,
    expectedMinor,
    amountDelta,
    toleranceMinor: tolerance,
    verifiedCurrency,
    expectedCurrency,
    amountForStorage,
    transactionId,
    cardDetails,
    successSet,
    mismatchSet,
  };
}

module.exports = {
  normalizeMinorAmount,
  parseMetadata,
  mapVerificationPayload,
  resolveMinorAmount,
  verifyLahzaTransaction,
  prepareLahzaPaymentUpdate,
  extractCardDetails,
  MINOR_AMOUNT_TOLERANCE,
};
