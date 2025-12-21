// server/routes/recaptcha.js
const express = require("express");

const router = express.Router();
const { verifyRecaptchaToken } = require("../utils/recaptcha");

/**
 * POST /api/recaptcha/verify
 * Body: { token: string, expectedAction?: string, minScore?: number }
 * Response: { success: boolean, score?: number, action?: string, error?: string, errorCodes?: string[] }
 */
router.post("/verify", async (req, res) => {
  try {
    const expectedAction = req.body?.expectedAction;
    const maybeMinScore = Number(req.body?.minScore);
    const minScore = Number.isFinite(maybeMinScore) ? maybeMinScore : undefined;

    const result = await verifyRecaptchaToken({
      token: req.body?.token,
      expectedAction,
      ...(typeof minScore === "number" ? { minScore } : {}),
    });

    return res.json({
      success: true,
      score: result?.score,
      action: result?.action,
    });
  } catch (err) {
    const status = err?.statusCode || 500;
    if (status >= 500) {
      console.error("reCAPTCHA verify error:", err);
    }
    return res.status(status).json({
      success: false,
      error: err?.code || "RECAPTCHA_FAILED",
      ...(err?.details ? err.details : {}),
    });
  }
});

module.exports = router;
