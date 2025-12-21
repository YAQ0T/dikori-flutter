// server/utils/sms.js
const axios = require("axios");
const qs = require("querystring");

const HTD_BASE = "http://sms.htd.ps/API";
const HTD_ID = process.env.SMS_HTD_ID;
const HTD_SENDER = process.env.SMS_HTD_SENDER || "Dikori"; // عدّل اسم المرسل

function buildTo(msisdn) {
  // تأكد من أن الرقم بصيغة 970XXXXXXXXX بدون +
  let to = String(msisdn || "").replace(/[^\d]/g, "");
  if (to.startsWith("0")) to = "970" + to.slice(1);
  if (!to.startsWith("970")) to = "970" + to;
  return to;
}

async function sendSMS({ to, msg }) {
  if (!HTD_ID) throw new Error("Missing SMS_HTD_ID env");
  const safeTo = buildTo(to);
  const url = `${HTD_BASE}/SendSMS.aspx`;
  // واجهة HTD تستخدم GET مع باراميتر id/sender/to/msg
  const query = {
    id: HTD_ID,
    sender: HTD_SENDER,
    to: safeTo,
    msg, // HTD يقوم بترميزها داخلياً عادة؛ نتركها كـ raw
  };
  const full = `${url}?${qs.stringify(query)}`;
  const { data, status } = await axios.get(full, { timeout: 15000 });
  // رجّع الرد كما هو؛ تقدر تخصّص فحص النجاح حسب تنسيق HTD
  return { ok: status === 200, raw: data };
}

async function getCredit() {
  if (!HTD_ID) throw new Error("Missing SMS_HTD_ID env");
  const url = `${HTD_BASE}/GetCredit.aspx?id=${encodeURIComponent(HTD_ID)}`;
  const { data, status } = await axios.get(url, { timeout: 10000 });
  return { ok: status === 200, raw: data };
}

module.exports = {
  sendSMS,
  getCredit,
  buildTo,
};
