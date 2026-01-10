// server/routes/payments.js
const express = require("express");
const axios = require("axios");
const { verifyTokenOptional } = require("../middleware/authMiddleware");
const Order = require("../models/Order");
const {
  prepareLahzaPaymentUpdate,
  verifyLahzaTransaction,
} = require("../utils/lahza");
const { queueOrderSummarySMS } = require("../utils/orderSms");

const router = express.Router();

const LAHZA_SECRET_KEY = process.env.LAHZA_SECRET_KEY || "";
const DEFAULT_CURRENCY = process.env.PAY_CURRENCY || "ILS";

function splitName(fullName = "") {
  const s = String(fullName || "")
    .trim()
    .replace(/\s+/g, " ");
  if (!s) return { first_name: "", last_name: "" };
  const parts = s.split(" ");
  if (parts.length === 1) return { first_name: parts[0], last_name: "" };
  return {
    first_name: parts.slice(0, -1).join(" "),
    last_name: parts.slice(-1)[0],
  };
}

router.post("/create", verifyTokenOptional, async (req, res) => {
  try {
    if (!LAHZA_SECRET_KEY) {
      return res.status(500).json({ error: "LAHZA secret key is missing" });
    }

    const {
      orderId,
      currency = DEFAULT_CURRENCY,
      email,
      name,
      mobile,
      callback_url,
      metadata = {},
    } = req.body || {};

    if (!orderId || !callback_url) {
      return res.status(400).json({ error: "orderId و callback_url مطلوبان" });
    }

    const order = await Order.findById(orderId).lean();
    if (!order) return res.status(404).json({ error: "الطلب غير موجود" });

    const total = Number(order.total || 0);
    if (!Number.isFinite(total) || total <= 0) {
      return res
        .status(400)
        .json({ error: "إجمالي الطلب غير صالح لإنشاء معاملة دفع" });
    }

    const amountMinor = Math.round(total * 100);
    const { first_name, last_name } = splitName(name);

    const payload = {
      amount: amountMinor,
      currency,
      email,
      mobile,
      first_name,
      last_name,
      callback_url,
      metadata: JSON.stringify({
        orderId: String(order._id),
        expectedAmountMinor: amountMinor,
        expectedCurrency: currency,
        ...(metadata && typeof metadata === "object" ? metadata : {}),
      }),
    };

    const resp = await axios.post(
      "https://api.lahza.io/transaction/initialize",
      payload,
      {
        headers: {
          Authorization: `Bearer ${LAHZA_SECRET_KEY}`,
          "Content-Type": "application/json",
        },
        timeout: 20000,
      }
    );

    const data = resp?.data?.data || {};
    const authorization_url = data?.authorization_url;
    const reference = data?.reference || data?.ref;

    if (!authorization_url || !reference) {
      return res.status(502).json({
        error: "Missing authorization_url/reference from Lahza",
        raw: resp?.data,
      });
    }

    await Order.findByIdAndUpdate(
      order._id,
      {
        $set: {
          reference,
          paymentMethod: "card",
          paymentCurrency: currency,
        },
      },
      { new: true }
    ).lean();

    return res.json({ authorization_url, reference });
  } catch (err) {
    return res.status(500).json({
      error: "Could not create transaction",
      details: err?.response?.data || err.message,
    });
  }
});

router.get("/status/:reference", async (req, res) => {
  try {
    if (!LAHZA_SECRET_KEY) {
      return res.status(500).json({ error: "LAHZA secret key is missing" });
    }

    const reference = req.params.reference;

    let verification;
    try {
      verification = await verifyLahzaTransaction(reference);
    } catch (err) {
      const status = err?.response?.status || 500;
      const data = err?.response?.data || {
        error: err?.message || "Verify failed",
      };
      return res.status(status).json(data);
    }

    return res.json(verification.response || {});
  } catch (err) {
    const status = err?.response?.status || 500;
    const data = err?.response?.data || {
      error: err.message || "Verify failed",
    };
    return res.status(status).json(data);
  }
});

router.post("/status/:reference/confirm", async (req, res) => {
  try {
    if (!LAHZA_SECRET_KEY) {
      return res.status(500).json({ error: "LAHZA secret key is missing" });
    }

    const reference = req.params.reference;

    let verification;
    try {
      verification = await verifyLahzaTransaction(reference);
    } catch (err) {
      const status = err?.response?.status || 500;
      const data = err?.response?.data || {
        error: err?.message || "Verify failed",
      };
      return res.status(status).json(data);
    }

    const responsePayload = verification.response || {};

    const result = {
      updated: false,
      alreadyPaid: false,
      mismatch: false,
      orderId: null,
    };

    if (verification.status === "success") {
      const order = await Order.findOne({ reference }).lean();
      if (order) {
        result.orderId = String(order._id);

        const {
          amountMatches,
          currencyMatches,
          successSet,
          mismatchSet,
          cardDetails,
        } = prepareLahzaPaymentUpdate({ order, verification });

        if (!amountMatches || !currencyMatches) {
          result.mismatch = true;
          if (Object.keys(mismatchSet).length) {
            await Order.updateOne({ _id: order._id }, { $set: mismatchSet });
          }
        } else {
          const updated = await Order.findOneAndUpdate(
            { _id: order._id, paymentStatus: { $ne: "paid" } },
            { $set: successSet },
            { new: true }
          ).lean();

          if (updated) {
            result.updated = true;
            queueOrderSummarySMS({
              order: updated,
              cardType: cardDetails?.cardType,
              cardLast4: cardDetails?.last4,
            });
          } else {
            result.alreadyPaid = order.paymentStatus === "paid";
            await Order.updateOne({ _id: order._id }, { $set: successSet });
          }
        }
      }
    }

    return res.json({
      ok: true,
      status: verification.status,
      ...result,
      data: responsePayload,
    });
  } catch (err) {
    const status = err?.response?.status || 500;
    const data = err?.response?.data || {
      error: err.message || "Verify failed",
    };
    return res.status(status).json(data);
  }
});

module.exports = router;
