const {setGlobalOptions} = require("firebase-functions");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

setGlobalOptions({maxInstances: 10});

exports.sendBookingStatusNotification = onDocumentUpdated(
    "bookings/{bookingId}",
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();

      const oldStatus = before.status;
      const newStatus = after.status;

      if (oldStatus === newStatus) return;

      const userId = after.userId;
      if (!userId) return;

      const statusTextMap = {
        pending: "預約已送出",
        confirmed: "預約已確認",
        checked_in: "已辦理入住",
        completed: "已完成退房",
        cancelled: "預約已取消",
      };

      const title = statusTextMap[newStatus] || "預約狀態已更新";
      const shopName = after.shopName || "店家";

      const tokensSnapshot = await admin
          .firestore()
          .collection("users")
          .doc(userId)
          .collection("fcm_tokens")
          .get();

      if (tokensSnapshot.empty) return;

      const tokens = tokensSnapshot.docs
          .map((doc) => doc.id)
          .filter((token) => token && token.length > 0);

      if (tokens.length === 0) return;

      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title,
          body: `${shopName} 的預約狀態已更新`,
        },
        data: {
          type: "booking_status",
          bookingId: event.params.bookingId,
          status: newStatus,
        },
      });
    },
);
