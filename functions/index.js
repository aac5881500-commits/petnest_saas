// 檔案名稱：functions/index.js
// 功能說明：Cloud Functions 入口：監聽訂單狀態、發送 FCM 推播並清除失效 Token
// 🔔 PetNest Cloud Functions

const {setGlobalOptions} = require("firebase-functions");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

setGlobalOptions({
  maxInstances: 10,
});

/**
 * 🗂️ 儲存通知中心資料
 *
 * 使用固定 notificationId 作為文件 ID，
 * 避免 Cloud Function 重試時重複建立通知。
 *
 * @param {Object} params 通知資料
 * @param {string} params.notificationId 固定通知文件 ID
 * @param {string} params.userId 接收通知的使用者 UID
 * @param {string} params.title 通知標題
 * @param {string} params.body 通知內容
 * @param {Object<string, string>} params.data 通知附加資料
 * @return {Promise<FirebaseFirestore.DocumentReference>}
 */
async function saveNotification({
  notificationId,
  userId,
  title,
  body,
  data,
}) {
  if (!notificationId || !userId) {
    throw new Error(
        "儲存通知失敗：notificationId 與 userId 不可為空",
    );
  }

  const firestore = admin.firestore();
  const notificationRef = firestore
      .collection("notifications")
      .doc(notificationId);

  await firestore.runTransaction(async (transaction) => {
    const notificationSnapshot =
      await transaction.get(notificationRef);

    if (notificationSnapshot.exists) {
      console.log(`通知 ${notificationId} 已存在，略過重複建立`);
      return;
    }

    const notificationData = data || {};

    transaction.create(notificationRef, {
      userId,
      title,
      body,
      type: (notificationData.type || "").toString(),
      bookingId: (notificationData.bookingId || "").toString(),
      shopId: (notificationData.shopId || "").toString(),
      messageId: (notificationData.messageId || "").toString(),
      status: "active",
      data: notificationData,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      readAt: null,
    });
  });

  return notificationRef;
}

/**
 * 🔔 發送推播給指定使用者
 *
 * 功能：
 * 1. 儲存通知中心資料
 * 2. 讀取使用者所有啟用中的 FCM Token
 * 3. 發送通知與自訂資料
 * 4. 自動刪除 Firebase 判定已失效的 Token
 *
 * @param {Object} params 推播參數
 * @param {string} params.notificationId 固定通知文件 ID
 * @param {string} params.userId Firebase Auth UID
 * @param {string} params.title 通知標題
 * @param {string} params.body 通知內容
 * @param {Object<string, string>} params.data 通知附加資料
 * @return {Promise<void>}
 */
async function sendNotificationToUser({
  notificationId,
  userId,
  title,
  body,
  data,
}) {
  if (!userId) {
    return;
  }

  if (notificationId) {
    await saveNotification({
      notificationId,
      userId,
      title,
      body,
      data,
    });
  } else {
    console.warn(
        `使用者 ${userId} 的通知缺少 notificationId，僅發送 FCM`,
    );
  }
  const settingSnapshot = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("notification_settings")
      .doc("global")
      .get();

  const notificationSetting = settingSnapshot.data() || {};
  const notificationEnabled = notificationSetting.enabled !== false;

  if (!notificationEnabled) {
    console.log(
        `使用者 ${userId} 已關閉全部推播通知，略過 FCM 發送`,
    );
    return;
  }

  const notificationType = (data && data.type ?
    data.type :
    "").toString();

  const settingKeyByType = {
    booking_status: "bookingStatus",
    booking_message: "bookingMessage",
    review: "reviewReminder",
    check_in: "checkInReminder",
  };

  const settingKey = settingKeyByType[notificationType];

  if (
    settingKey &&
    notificationSetting[settingKey] === false
  ) {
    console.log(
        `使用者 ${userId} 已關閉 ${settingKey} 推播，略過 FCM 發送`,
    );
    return;
  }

  const tokensSnapshot = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("fcm_tokens")
      .get();

  if (tokensSnapshot.empty) {
    console.log(`使用者 ${userId} 沒有可用的 FCM Token`);
    return;
  }

  const tokenDocuments = tokensSnapshot.docs.filter((document) => {
    const tokenData = document.data();
    const token = document.id;

    return token &&
      token.length > 0 &&
      tokenData.enabled !== false;
  });

  if (tokenDocuments.length === 0) {
    console.log(`使用者 ${userId} 沒有啟用中的 FCM Token`);
    return;
  }

  const tokens = tokenDocuments.map((document) => document.id);

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title,
      body,
    },
    data,
    android: {
      priority: "high",
      notification: {
        sound: "default",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  });

  console.log(
      `推播完成：成功 ${response.successCount}，失敗 ${response.failureCount}`,
  );

  const invalidTokenDeleteTasks = [];

  response.responses.forEach((sendResponse, index) => {
    if (sendResponse.success) {
      return;
    }

    const errorCode = sendResponse.error ?
      sendResponse.error.code :
      "";

    const tokenInvalid =
      errorCode === "messaging/registration-token-not-registered" ||
      errorCode === "messaging/invalid-registration-token";

    if (!tokenInvalid) {
      console.error(
          `FCM 推播失敗：${errorCode}`,
          sendResponse.error,
      );
      return;
    }

    invalidTokenDeleteTasks.push(
        tokenDocuments[index].ref.delete(),
    );
  });

  if (invalidTokenDeleteTasks.length > 0) {
    await Promise.all(invalidTokenDeleteTasks);

    console.log(
        `已刪除 ${invalidTokenDeleteTasks.length} 個失效 FCM Token`,
    );
  }
}

/**
 * 📦 訂單狀態變更通知
 *
 * 監聽 bookings/{bookingId}
 * 當 status 改變時，通知該訂單所屬會員。
 */
exports.sendBookingStatusNotification = onDocumentUpdated(
    "bookings/{bookingId}",
    async (event) => {
      if (!event.data) {
        return;
      }

      const before = event.data.before.data();
      const after = event.data.after.data();

      const oldStatus = before.status;
      const newStatus = after.status;

      if (oldStatus === newStatus) {
        return;
      }

      const userId = (after.userId || "").toString();
      const afterKind = (after.bookingKind || "").toString();
      const resolveKind = afterKind === "daycare" ||
        (after.serviceType || "").toString() === "daycare" ?
        "daycare" : "accommodation";

      if (!userId) {
        console.log(
            `訂單 ${event.params.bookingId} 沒有 userId，略過推播`,
        );
        return;
      }

      const statusTextMap = {
        pending: "預約已送出",
        confirmed: "預約已確認",
        checked_in: resolveKind === "daycare" ? "臨托已開始" : "已辦理入住",
        completed: resolveKind === "daycare" ? "臨托已完成" : "已完成退房",
        cancelled: "預約已取消",
      };

      const needReviewReminder = newStatus === "completed";

      const title = statusTextMap[newStatus] || "預約狀態已更新";
      const shopName = (after.shopName || "店家").toString();
      const shopId = (after.shopId || "").toString();

      await sendNotificationToUser({
        notificationId:
          `booking_status_${event.id}_${userId}`,
        userId,
        title,
        body: `${shopName} 的預約狀態已更新`,
        data: {
          type: "booking_status",
          bookingId: event.params.bookingId,
          shopId,
          status: (newStatus || "").toString(),
        },
      });

      if (needReviewReminder) {
        await sendNotificationToUser({
          notificationId:
            `review_${event.id}_${userId}`,
          userId,
          title: "住宿完成，歡迎留下評價",
          body: `歡迎分享這次在 ${shopName} 的住宿體驗`,
          data: {
            type: "review",
            bookingId: event.params.bookingId,
            shopId,
          },
        });
      }
    },
);

/**
 * 💬 訂單聊天室通知
 *
 * 監聽：
 * bookings/{bookingId}/messages/{messageId}
 *
 * 店家傳訊息：
 * 通知訂單會員。
 *
 * 會員傳訊息：
 * 通知店主、管理員與主管。
 */
exports.sendBookingMessageNotification = onDocumentCreated(
    "bookings/{bookingId}/messages/{messageId}",
    async (event) => {
      if (!event.data) {
        return;
      }

      const message = event.data.data();
      const senderType = (message.senderType || "").toString();
      const senderId = (message.senderId || "").toString();
      const bookingId = event.params.bookingId;

      if (senderType !== "shop" && senderType !== "customer") {
        console.log(
            `訊息 ${event.params.messageId} 的 senderType 無法識別`,
        );
        return;
      }

      const bookingSnapshot = await admin
          .firestore()
          .collection("bookings")
          .doc(bookingId)
          .get();

      if (!bookingSnapshot.exists) {
        console.log(`找不到訂單 ${bookingId}，略過聊天推播`);
        return;
      }

      const booking = bookingSnapshot.data();
      const shopId = (booking.shopId || "").toString();
      const userId = (booking.userId || "").toString();
      const shopName = (booking.shopName || "店家").toString();

      const messageText =
        (message.text || "您有一則新訊息").toString();

      const body = messageText.length > 80 ?
        `${messageText.substring(0, 80)}...` :
        messageText;

      // =========================
      // 店家 → 會員
      // =========================
      if (senderType === "shop") {
        if (!userId) {
          console.log(
              `訂單 ${bookingId} 沒有 userId，略過會員聊天推播`,
          );
          return;
        }

        await sendNotificationToUser({
          notificationId:
            `booking_message_${event.params.messageId}_${userId}`,
          userId,
          title: `${shopName} 傳來新訊息`,
          body,
          data: {
            type: "booking_message",
            bookingId,
            messageId: event.params.messageId,
            shopId,
            senderType,
          },
        });

        return;
      }

      // =========================
      // 會員 → 店家
      // =========================
      if (!shopId) {
        console.log(
            `訂單 ${bookingId} 沒有 shopId，略過店家聊天推播`,
        );
        return;
      }

      const shopMembersSnapshot = await admin
          .firestore()
          .collection("shop_members")
          .where("shopId", "==", shopId)
          .where("role", "in", ["owner", "admin", "manager"])
          .get();

      if (shopMembersSnapshot.empty) {
        console.log(
            `店家 ${shopId} 沒有可接收聊天推播的成員`,
        );
        return;
      }

      const receiverIds = shopMembersSnapshot.docs
          .map((document) => {
            const member = document.data();
            return (member.uid || "").toString();
          })
          .filter((memberUid) => {
            return memberUid &&
              memberUid.length > 0 &&
              memberUid !== senderId;
          });

      const uniqueReceiverIds = [...new Set(receiverIds)];

      if (uniqueReceiverIds.length === 0) {
        console.log(
            `店家 ${shopId} 沒有其他可接收聊天推播的成員`,
        );
        return;
      }

      const notificationTasks = uniqueReceiverIds.map((receiverId) => {
        return sendNotificationToUser({
          notificationId:
            `booking_message_${event.params.messageId}_${receiverId}`,
          userId: receiverId,
          title: "會員傳來新訊息",
          body,
          data: {
            type: "booking_message",
            bookingId,
            messageId: event.params.messageId,
            shopId,
            senderType,
          },
        });
      });

      await Promise.all(notificationTasks);
    },
);

/**
 * 💬 店家聊天通知
 *
 * 監聽：
 * shops/{shopId}/chat_threads/{threadId}/messages/{messageId}
 *
 * 會員傳訊息：
 * 通知店主，以及未關閉 manage_chat 的店家成員。
 *
 * 店家傳訊息：
 * 通知該聊天室會員。
 */
exports.sendShopChatNotification = onDocumentCreated(
    "shops/{shopId}/chat_threads/{threadId}/messages/{messageId}",
    async (event) => {
      if (!event.data) {
        return;
      }

      const message = event.data.data();
      const senderType = (message.senderType || "").toString();
      const senderUid = (message.senderUid || "").toString();
      const shopId = event.params.shopId;
      const threadId = event.params.threadId;
      const messageId = event.params.messageId;
      const messageType = (message.type || "text").toString();
      const rawText = (message.text || "").toString();
      const body = messageType === "image" ?
        "傳了一張圖片" :
        (rawText.length > 80 ? `${rawText.substring(0, 80)}...` : rawText);

      if (senderType !== "shop" && senderType !== "customer") {
        console.log(`店家聊天訊息 ${messageId} 的 senderType 無法識別`);
        return;
      }

      const firestore = admin.firestore();
      const shopSnapshot = await firestore
          .collection("shops")
          .doc(shopId)
          .get();
      const shopName = ((shopSnapshot.data() || {}).name || "店家").toString();

      const threadSnapshot = await firestore
          .collection("shops")
          .doc(shopId)
          .collection("chat_threads")
          .doc(threadId)
          .get();
      const thread = threadSnapshot.data() || {};
      const customerName = (thread.customerName || "會員").toString();
      const customerUid = (thread.customerUid || threadId).toString();

      const commonData = {
        type: "shop_chat",
        shopId,
        threadId,
        messageId,
        senderType,
      };

      if (senderType === "shop") {
        if (!customerUid) {
          console.log(`聊天室 ${threadId} 沒有 customerUid，略過會員推播`);
          return;
        }

        await sendNotificationToUser({
          notificationId: `shop_chat_${messageId}_${customerUid}`,
          userId: customerUid,
          title: `${shopName} 回覆了你的訊息`,
          body: body || "您有一則新訊息",
          data: commonData,
        });
        return;
      }

      const shopMembersSnapshot = await firestore
          .collection("shop_members")
          .where("shopId", "==", shopId)
          .get();

      if (shopMembersSnapshot.empty) {
        console.log(`店家 ${shopId} 沒有可接收聊天推播的成員`);
        return;
      }

      const receiverIds = shopMembersSnapshot.docs
          .map((document) => {
            const member = document.data() || {};
            const role = (member.role || "").toString();
            const permissions = member.permissions || {};
            const canReceive = role === "owner" ||
              permissions.manage_chat !== false;
            if (!canReceive) {
              return "";
            }
            return (member.uid || "").toString();
          })
          .filter((memberUid) => {
            return memberUid &&
              memberUid.length > 0 &&
              memberUid !== senderUid;
          });

      const uniqueReceiverIds = [...new Set(receiverIds)];

      if (uniqueReceiverIds.length === 0) {
        console.log(`店家 ${shopId} 沒有其他可接收聊天推播的成員`);
        return;
      }

      const notificationTasks = uniqueReceiverIds.map((receiverId) => {
        return sendNotificationToUser({
          notificationId: `shop_chat_${messageId}_${receiverId}`,
          userId: receiverId,
          title: `${customerName}傳來新訊息`,
          body: body || "您有一則新訊息",
          data: commonData,
        });
      });

      await Promise.all(notificationTasks);
    },
);

/**
 * 🏨 入住前一天提醒
 *
 * 每天台灣時間上午 10 點執行。
 * 搜尋明天入住、已確認且尚未發送提醒的訂單。
 */
exports.sendCheckInReminder = onSchedule(
    {
      schedule: "0 10 * * *",
      timeZone: "Asia/Taipei",
    },
    async () => {
      const firestore = admin.firestore();

      const now = new Date();

      const taiwanNow = new Date(
          now.toLocaleString("en-US", {
            timeZone: "Asia/Taipei",
          }),
      );

      const tomorrowStart = new Date(
          taiwanNow.getFullYear(),
          taiwanNow.getMonth(),
          taiwanNow.getDate() + 1,
          0,
          0,
          0,
          0,
      );

      const tomorrowEnd = new Date(
          taiwanNow.getFullYear(),
          taiwanNow.getMonth(),
          taiwanNow.getDate() + 2,
          0,
          0,
          0,
          0,
      );

      const tomorrowStartTimestamp =
        admin.firestore.Timestamp.fromDate(tomorrowStart);

      const tomorrowEndTimestamp =
        admin.firestore.Timestamp.fromDate(tomorrowEnd);

      const bookingsSnapshot = await firestore
          .collection("bookings")
          .where("status", "==", "confirmed")
          .where("startDate", ">=", tomorrowStartTimestamp)
          .where("startDate", "<", tomorrowEndTimestamp)
          .get();

      if (bookingsSnapshot.empty) {
        console.log("入住提醒：明天沒有符合條件的訂單");
        return;
      }

      const reminderTasks = bookingsSnapshot.docs.map(async (document) => {
        const booking = document.data();

        if (booking.checkInReminderSentAt) {
          return;
        }

        const userId = (booking.userId || "").toString();

        if (!userId) {
          console.log(`訂單 ${document.id} 沒有 userId，略過入住提醒`);
          return;
        }

        const shopName = (booking.shopName || "店家").toString();
        const shopId = (booking.shopId || "").toString();

        await sendNotificationToUser({
          notificationId:
            `check_in_${document.id}_${userId}`,
          userId,
          title: "明天就是入住日",
          body: `提醒您，明天將入住 ${shopName}`,
          data: {
            type: "check_in",
            bookingId: document.id,
            shopId,
          },
        });

        await document.ref.update({
          checkInReminderSentAt:
            admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await Promise.all(reminderTasks);

      console.log(
          `入住提醒完成，共檢查 ${bookingsSnapshot.docs.length} 筆訂單`,
      );
    },
);
/**
 * 💳 建立綠界付款
 *
 * 實際邏輯放在：
 * functions/payments/create_payment.js
 */
exports.createEcpayPayment =
  require("./payments/create_payment").createEcpayPayment;

/**
 * 🔔 接收綠界付款結果通知
 *
 * 實際邏輯放在：
 * functions/payments/payment_callback.js
 */
exports.ecpayPaymentCallback =
  require("./payments/payment_callback")
      .ecpayPaymentCallback;

/**
 * 📝 店家送出綠界金流設定審核
 *
 * 實際邏輯放在：
 * functions/payments/submit_payment_setting.js
 */
exports.submitEcpayPaymentSetting =
  require("./payments/submit_payment_setting")
      .submitEcpayPaymentSetting;
/**
 * ✅ 平台核准店家綠界金流申請
 *
 * 實際邏輯放在：
 * functions/payments/review_payment_setting.js
 */
exports.approveEcpayPaymentSetting =
  require("./payments/review_payment_setting")
      .approveEcpayPaymentSetting;

/**
 * ❌ 平台退回店家綠界金流申請
 *
 * 實際邏輯放在：
 * functions/payments/review_payment_setting.js
 */
exports.rejectEcpayPaymentSetting =
  require("./payments/review_payment_setting")
      .rejectEcpayPaymentSetting;

/**
 * ⛔ 平台停用 / 重新啟用店家綠界金流
 *
 * 實際邏輯放在：
 * functions/payments/review_payment_setting.js
 */
exports.setEcpayPaymentPlatformSuspended =
  require("./payments/review_payment_setting")
      .setEcpayPaymentPlatformSuspended;
/**
 * ➕ 使用 Email 新增平台人員
 *
 * 實際邏輯放在：
 * functions/platform/create_platform_user.js
 */
exports.createPlatformUserByEmail =
  require("./platform/create_platform_user")
      .createPlatformUserByEmail;
/**
 * ⚙️ 更新店家收款方式營運設定
 *
 * 實際邏輯放在：
 * functions/payments/update_operation_settings.js
 */
exports.updatePaymentOperationSettings =
  require("./payments/update_operation_settings")
      .updatePaymentOperationSettings;

/**
 * 🛒 建立商城訂單並保留庫存
 */
exports.createStoreOrder =
  require("./store/create_store_order").createStoreOrder;

/**
 * 🛒 更新商城訂單狀態
 */
exports.updateStoreOrderStatus =
  require("./store/update_store_order_status").updateStoreOrderStatus;

/**
 * 🛒 庫存主檔異動後同步商城商品公開庫存
 */
exports.syncStoreProductPublicStock =
  require("./store/sync_store_product_public_stock")
      .syncStoreProductPublicStock;

/**
 * 🎁 中央庫存點數商品兌換
 */
exports.exchangePointReward =
  require("./points/exchange_point_reward").exchangePointReward;

/**
 * 🎁 取消中央庫存點數實體商品兌換
 */
exports.cancelPointRedemption =
  require("./points/cancel_point_redemption").cancelPointRedemption;

/**
 * 🏨 住宿加購庫存後端扣除
 */
exports.finalizeBookingAddonInventory =
  require("./bookings/finalize_booking_addon_inventory")
      .finalizeBookingAddonInventory;

/**
 * 🏨 取消住宿訂單返還庫存
 */
exports.returnBookingInventory =
  require("./bookings/return_booking_inventory").returnBookingInventory;

/**
 * 🐾 建立臨托訂單
 */
exports.createDaycareBooking =
  require("./daycare/create_daycare_booking").createDaycareBooking;

/**
 * 🐾 臨托訂單狀態與價格操作
 */
exports.manageDaycareBooking =
  require("./daycare/manage_daycare_booking").manageDaycareBooking;

/**
 * 🐾 臨托分房／換房
 */
exports.assignDaycareRoom =
  require("./daycare/assign_daycare_room").assignDaycareRoom;

/**
 * 🐾 臨托轉住宿
 */
exports.convertDaycareToAccommodation =
  require("./daycare/convert_daycare_to_accommodation")
      .convertDaycareToAccommodation;
