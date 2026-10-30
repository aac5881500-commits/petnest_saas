"use strict";
const admin = require("firebase-admin");
const {onCall, HttpsError} = require("../platform/inspection_write_guard");
const {locationInput} = require("./shop_map_location_policy");
exports.saveShopMapLocation = onCall(
    {region: "asia-east1"}, async (request) => {
      if (!request.auth) throw new HttpsError("unauthenticated", "請先登入");
      const data = request.data || {};
      const id = data.shopId;
      if (typeof id !== "string" || !id || id.includes("/") ||
          id.length > 150) {
        throw new HttpsError("invalid-argument", "店家編號無效");
      }
      let location;
      try {
        location = locationInput(data);
      } catch (error) {
        throw new HttpsError("invalid-argument",
            error.message);
      }
      const db = admin.firestore();
      await db.runTransaction(async (tx) => {
        const ref = db.collection("shops").doc(id);
        const shop = await tx.get(ref);
        if (!shop.exists) throw new HttpsError("not-found", "店家不存在");
        const member = await tx.get(db.collection("shop_members")
            .doc(`${id}_${request.auth.uid}`));
        const owner = shop.get("ownerUid") === request.auth.uid ||
      (member.exists && member.get("uid") === request.auth.uid &&
       member.get("shopId") === id && member.get("role") === "owner");
        if (!owner) throw new HttpsError("permission-denied", "只有店主可設定位置");
        const address = [shop.get("city"), shop.get("district"),
          shop.get("address")].map((v) => v || "").join("");
        if (location !== null &&
            (!address || data.expectedAddress !== address)) {
          throw new HttpsError("failed-precondition",
              "店址已變更，請重新載入確認位置");
        }
        const point = location === null ? admin.firestore.FieldValue.delete() :
      {...location, addressSnapshot: address,
        confirmedBy: request.auth.uid,
        confirmedAt: admin.firestore.FieldValue.serverTimestamp()};
        tx.update(ref, {mapLocation: point,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()});
      });
      return {saved: true};
    });
