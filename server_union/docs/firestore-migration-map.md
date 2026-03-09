# Firestore Migration Map (Phase 1)

## Project
- Firebase project (dev): `dikori-7244d`
- Region target: `europe-west1`
- Auth target: `Firebase Auth` (HTD SMS remains external)
- Images: external URLs (Imgur), no Firebase Storage dependency for now

## Strategy
- Keep existing REST API contract (`/api/...`) during migration.
- Replace MongoDB access with Firestore repositories behind routes.
- Preserve route behavior first, optimize query patterns second.

## Collection Design

### `users/{uid}`
- Source model: `models/User.js`
- Key fields:
  - `name`, `email`, `phone`, `role`
  - `passwordHash`
  - `phoneVerified`
  - OTP/reset fields:
    - `phoneVerificationCodeHash`
    - `phoneVerificationExpires`
    - `phoneVerificationAttempts`
    - `phoneVerificationResends`
    - `resetPasswordCodeHash`
    - `resetPasswordExpires`
    - `resetPasswordAttempts`
  - `address` object
  - `createdAt`, `updatedAt`
- Notes:
  - Document id = Firebase Auth uid.
  - Keep external HTD OTP flow; Firebase Auth is identity/session layer.

### `products/{productId}`
- Source model: `models/Product.js`
- Key fields:
  - localized `name` + `description`
  - `category`, `mainCategory`, `subCategory`
  - `images[]`
  - `ownershipType`, `priority`, `isVisible`
  - denormalized: `minPrice`, `totalStock`, `variantCount`
  - `createdAt`, `updatedAt`
- Notes:
  - `minPrice/totalStock` are required to avoid expensive cross-collection scans.
  - Update these values whenever variants change.

### `variants/{variantId}`
- Source model: `models/Variant.js`
- Key fields:
  - `productId`
  - `measure`, `measureUnit`, `measureSlug`
  - `color { name, code, images[] }`, `colorSlug`
  - `price { currency, amount, compareAt, discount }`
  - `stock { inStock, sku }`
  - `trackQuantity`
  - `tags[]`
  - `createdAt`, `updatedAt`
- Notes:
  - Keep `sku` unique via transactional uniqueness check collection:
    - `variant_sku_index/{sku}` -> `{ variantId }`

### `orders/{orderId}`
- Source model: `models/Order.js`
- Key fields:
  - `user` snapshot object + `guestInfo`
  - `isGuest`
  - `items[]`
  - `subtotal`, `discount`, `total`
  - `address`, `notes`
  - `status`, `deliveredAt`
  - `paymentMethod`, `paymentCurrency`, `paymentStatus`
  - payment verification fields + card details
  - `reference`
  - `createdAt`, `updatedAt`
- Notes:
  - Add `trackedVariantQuantities` map for rollback safety in payment flows.

### `discount_rules/{ruleId}`
- Source model: `models/DiscountRule.js`
- Key fields:
  - `name`, `type`, `value`, `threshold`, `priority`
  - `isActive`, `startAt`, `endAt`
  - `createdAt`, `updatedAt`

### `notifications/{notificationId}`
- Source model: `models/Notification.js`
- Key fields:
  - `userId`, `title`, `body`, `link`, `isRead`, `createdAt`, `updatedAt`

### Singleton Collections
- `site_settings/main`
- `site_ad/main`
- `home_collections/main`

## Required Composite Indexes (initial)
- `products`: `mainCategory + subCategory + isVisible + priority + createdAt(desc)`
- `products`: `isVisible + priority + createdAt(desc)`
- `variants`: `productId + measureSlug + colorSlug`
- `variants`: `productId + updatedAt(desc)`
- `orders`: `user._id + createdAt(desc)`
- `orders`: `reference`
- `orders`: `status + createdAt(desc)`
- `discount_rules`: `isActive + threshold(desc) + priority(desc) + createdAt(desc)`
- `notifications`: `userId + createdAt(desc)`

## Transaction-Critical Flows

### 1) COD/Bank Order Creation
- Read requested variants.
- Validate tracked stock.
- Transaction:
  - decrement tracked variant stock with `inStock >= qty` guards
  - create order document
- On transaction failure: no partial stock change.

### 2) Card Payment Confirmation/Webhook
- Idempotency key: `reference`.
- Transaction:
  - verify order not already paid
  - decrement tracked stock once
  - mark `paymentStatus=paid`
  - persist verification details
- If already paid: no stock decrement.

### 3) Variant SKU Uniqueness
- Transaction on create/update:
  - check/create `variant_sku_index/{sku}`
  - write variant document

## Route Migration Order
1. Products + Variants read paths
2. Auth + Users
3. Orders + Payments + Webhook
4. Notifications + Settings + Admin routes

## Parity Checks Before Cutover
- Record counts per entity (Mongo vs Firestore)
- Spot checks for localized fields and discount calculations
- Order/payment consistency by `reference`
- Stock invariants:
  - no negative tracked stock
  - paid order stock decremented exactly once

