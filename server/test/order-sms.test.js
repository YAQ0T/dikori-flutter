const test = require("node:test");
const assert = require("node:assert/strict");

const { buildOrderSummaryMessage } = require("../utils/orderSms");

test("buildOrderSummaryMessage includes key order details", () => {
  const createdAt = new Date("2024-03-12T09:15:00Z");
  const order = {
    user: { name: "أحمد", phone: "0590000000" },
    guestInfo: { name: "", phone: "" },
    items: [
      {
        name: { ar: "منتج رائع", he: "" },
        quantity: 2,
        price: 49.5,
      },
      {
        name: { ar: "منتج إضافي", he: "" },
        quantity: 1,
        price: 20,
      },
    ],
    subtotal: 119,
    discount: { amount: 9 },
    total: 110,
    paymentCurrency: "ILS",
    paymentMethod: "card",
    createdAt,
    reference: "REF-12345",
  };

  const message = buildOrderSummaryMessage({
    order,
    cardTypeOverride: "Visa",
    cardLast4Override: "0444",
  });

  assert.match(message, /أحمد/);
  assert.match(message, /0590000000/);
  assert.match(message, /2024-03-12/);
  assert.match(message, /منتج رائع x2/);
  assert.match(message, /49\.50 ILS/);
  assert.match(message, /الإجمالي المطلوب: 110\.00 ILS/);
  assert.match(message, /الخصم: 9\.00 ILS/);
  assert.match(message, /طريقة الدفع: Visa \*\*\*\*0444/);
  assert.match(message, /مرجع الدفع: REF-12345/);
});

test("buildOrderSummaryMessage falls back to COD label", () => {
  const order = {
    guestInfo: { name: "ضيف", phone: "0591111111" },
    items: [
      { name: { ar: "منتج" }, quantity: 1, price: 15 },
    ],
    subtotal: 15,
    discount: { amount: 0 },
    total: 15,
    paymentCurrency: "ILS",
    paymentMethod: "cod",
    createdAt: new Date("2024-01-01T10:00:00Z"),
  };

  const message = buildOrderSummaryMessage({ order });

  assert.match(message, /ضيف/);
  assert.match(message, /طريقة الدفع: الدفع عند الاستلام/);
});
