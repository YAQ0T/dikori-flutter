// server/utils/smsHtd.js
const axios = require("axios");
const qs = require("querystring");

/**
 * إعدادات وبيئة مزود HTD للرسائل القصيرة.
 * تمت مشاركتها بين مسارات مختلفة لضمان سلوك موحد عند إرسال الرسائل.
 */
const HTD_BASE =
  process.env.SMS_HTD_BASE || process.env.SMS_BASE || "http://sms.htd.ps/API";

const HTD_API_STYLE = String(
  process.env.SMS_HTD_API_STYLE || "auto"
).toLowerCase();

const SMS_USERNAME = process.env.SMS_USERNAME || process.env.SMS_USER || "";
const SMS_PASSWORD =
  process.env.SMS_PASSWORD ||
  process.env.SMS_PASS ||
  process.env.SMS_HTD_PASSWORD ||
  process.env.SMS_HTD_PASS ||
  "";
const SMS_SENDER =
  process.env.SMS_SENDER || process.env.SMS_HTD_SENDER || "SENDER";
const SMS_HTD_ID = process.env.SMS_HTD_ID || process.env.SMS_ID || "";

const SEND_SMS_ENABLED =
  String(process.env.SEND_SMS_ENABLED || "false").toLowerCase() === "true";
const DEV_ECHO_SMS = String(
  process.env.DEV_ECHO_SMS ?? process.env.DEV_ECHO_OTP ?? "true"
).toLowerCase() === "true";

const DEFAULT_RECIPIENT_FORMAT =
  HTD_API_STYLE === "simple"
    ? "INT"
    : (process.env.SMS_RECIPIENT_FORMAT || "E164").toUpperCase();

function normalizePhone(phone) {
  if (!phone) return null;
  let p = String(phone).trim().replace(/\s+/g, "");
  p = p.replace(/[^\d+]/g, "");
  if (!p.startsWith("+")) p = p.replace(/^0+/, "");
  if (!p.startsWith("+")) p = "+970" + p;
  return p;
}

function formatForProvider(e164Phone, preferFormat = DEFAULT_RECIPIENT_FORMAT) {
  if (!e164Phone) return null;
  const digits = e164Phone.replace(/^\+/, "");
  if (preferFormat === "E164") return e164Phone;
  if (preferFormat === "INT") return digits;
  if (preferFormat === "LOCAL") {
    if (digits.startsWith("970")) {
      const rest = digits.slice(3);
      return "0" + rest;
    }
    return "0" + digits;
  }
  return digits;
}

function resolveApiStyle() {
  if (HTD_API_STYLE === "simple" || HTD_API_STYLE === "classic") {
    return HTD_API_STYLE;
  }
  if (SMS_HTD_ID && !SMS_USERNAME) return "simple";
  if (SMS_USERNAME || SMS_PASSWORD) return "classic";
  return "simple";
}

async function sendSMSHTD(toE164, text) {
  if (!toE164 || !text) return { ok: false, reason: "missing_to_or_text" };

  const style = resolveApiStyle();
  const to = formatForProvider(
    toE164,
    style === "simple" ? "INT" : DEFAULT_RECIPIENT_FORMAT
  );

  if (!SEND_SMS_ENABLED) {
    if (DEV_ECHO_SMS) {
      console.log(
        `[DEV SMS] To: ${toE164} (provider:${to}) | Message: ${text}`
      );
    }
    return { ok: true, dev: true, style };
  }

  try {
    const base = HTD_BASE.replace(/\/+$/, "");
    const url = `${base}/SendSMS.aspx`;

    let payload;
    if (style === "simple") {
      payload = {
        id: SMS_HTD_ID,
        sender: SMS_SENDER,
        to,
        msg: text,
      };
      if (!payload.id) {
        return { ok: false, reason: "missing_SMS_HTD_ID_for_simple_mode" };
      }
    } else {
      payload = {
        SenderName: SMS_SENDER,
        Recipients: to,
        Message: text,
      };
      if (SMS_USERNAME) payload.UserName = SMS_USERNAME;
      if (SMS_PASSWORD) payload.Password = SMS_PASSWORD;
      if (!payload.UserName || !payload.Password) {
        return { ok: false, reason: "missing_credentials_for_classic_mode" };
      }
    }

    const full = url + "?" + qs.stringify(payload);
    const res = await axios.get(full, { timeout: 15000 });

    console.log(`[HTD SMS] style=${style} status=${res.status} data=`, res.data);
    return { ok: true, style, status: res.status, data: res.data };
  } catch (e) {
    console.error(
      "[HTD SMS] Error:",
      e?.response?.status,
      e?.response?.data || e?.message
    );
    return { ok: false, reason: e?.message || "send_failed" };
  }
}

module.exports = {
  sendSMSHTD,
  normalizePhone,
  formatForProvider,
  resolveApiStyle,
};
