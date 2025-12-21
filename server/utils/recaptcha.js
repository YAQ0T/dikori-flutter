// server/utils/recaptcha.js
const axios = require("axios");

class RecaptchaError extends Error {
  constructor(
    message,
    { statusCode = 400, code = "RECAPTCHA_FAILED", details } = {}
  ) {
    super(message);
    this.name = "RecaptchaError";
    this.statusCode = statusCode;
    this.code = code;
    if (details) {
      this.details = details;
    }
  }
}

async function verifyRecaptchaToken({
  token,
  expectedAction,
  minScore = 0.5,
} = {}) {
  if (!token) {
    throw new RecaptchaError("reCAPTCHA token is required", {
      statusCode: 400,
      code: "MISSING_TOKEN",
    });
  }

  const secret = process.env.RECAPTCHA_SECRET;
  if (!secret) {
    throw new RecaptchaError("reCAPTCHA secret is not configured", {
      statusCode: 500,
      code: "SERVER_SECRET_NOT_CONFIGURED",
    });
  }

  const params = new URLSearchParams();
  params.append("secret", secret);
  params.append("response", token);

  let data;
  try {
    ({ data } = await axios.post(
      "https://www.google.com/recaptcha/api/siteverify",
      params.toString(),
      {
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        timeout: 15000,
      }
    ));
  } catch (err) {
    throw new RecaptchaError("Failed to verify reCAPTCHA token", {
      statusCode: 502,
      code: "VERIFY_REQUEST_FAILED",
      details: { message: err?.message },
    });
  }

  if (!data?.success) {
    throw new RecaptchaError("Google reCAPTCHA verification failed", {
      statusCode: 400,
      code: "GOOGLE_VERIFICATION_FAILED",
      details: { errorCodes: data?.["error-codes"] || [] },
    });
  }

  if (typeof data?.score === "number" && data.score < minScore) {
    throw new RecaptchaError("reCAPTCHA score below threshold", {
      statusCode: 400,
      code: "LOW_SCORE",
      details: { score: data.score, action: data?.action },
    });
  }

  if (expectedAction && data?.action && data.action !== expectedAction) {
    throw new RecaptchaError("Unexpected reCAPTCHA action", {
      statusCode: 400,
      code: "UNEXPECTED_ACTION",
      details: { score: data?.score, action: data?.action },
    });
  }

  return {
    success: true,
    score: data?.score,
    action: data?.action,
  };
}

module.exports = {
  verifyRecaptchaToken,
  RecaptchaError,
};
