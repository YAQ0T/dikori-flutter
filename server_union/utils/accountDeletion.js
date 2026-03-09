const User = require("../models/User");
const Order = require("../models/Order");
const Notification = require("../models/Notification");
const { getFirebaseAuth } = require("./firebaseAdmin");

function normalizeId(value) {
  const normalized = String(value || "").trim();
  return normalized || null;
}

async function maybeDeleteFirebaseUser(firebaseUid) {
  const uid = normalizeId(firebaseUid);
  if (!uid) {
    return { attempted: false, deleted: false, reason: "missing_uid" };
  }

  try {
    await getFirebaseAuth().deleteUser(uid);
    return { attempted: true, deleted: true };
  } catch (err) {
    const code = String(err?.code || "");
    if (code === "auth/user-not-found") {
      return { attempted: true, deleted: false, reason: "not_found" };
    }
    throw err;
  }
}

async function deleteUserAccountData({ userId, firebaseUid } = {}) {
  const normalizedUserId = normalizeId(userId);
  if (!normalizedUserId) {
    throw new Error("userId is required for account deletion");
  }

  const summary = {
    userId: normalizedUserId,
    notificationsDeleted: 0,
    notificationsReadByCleaned: 0,
    ordersAnonymized: 0,
    userDeleted: false,
    firebase: { attempted: false, deleted: false, reason: null },
  };

  const deletedNotifications = await Notification.deleteMany({
    target: "user",
    user: normalizedUserId,
  });
  summary.notificationsDeleted = Number(deletedNotifications?.deletedCount || 0);

  const cleanedReadBy = await Notification.updateMany(
    { readBy: normalizedUserId },
    { $pull: { readBy: normalizedUserId } }
  );
  summary.notificationsReadByCleaned = Number(
    cleanedReadBy?.modifiedCount || 0
  );

  const anonymizedOrders = await Order.updateMany(
    {
      $or: [{ "user._id": normalizedUserId }, { user: normalizedUserId }],
    },
    {
      $unset: { user: "" },
      $set: {
        isGuest: true,
        "guestInfo.name": "Deleted User",
        "guestInfo.phone": "",
        "guestInfo.email": "",
        "guestInfo.address": "",
      },
    }
  );
  summary.ordersAnonymized = Number(anonymizedOrders?.modifiedCount || 0);

  const deletedUser = await User.deleteOne({ _id: normalizedUserId });
  summary.userDeleted = Number(deletedUser?.deletedCount || 0) > 0;

  const firebaseResult = await maybeDeleteFirebaseUser(firebaseUid);
  summary.firebase = {
    attempted: firebaseResult.attempted,
    deleted: firebaseResult.deleted,
    reason: firebaseResult.reason || null,
  };

  return summary;
}

module.exports = {
  deleteUserAccountData,
};
