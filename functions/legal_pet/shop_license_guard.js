// 檔案名稱：functions/legal_pet/shop_license_guard.js
// 功能說明：字號或營業地址變更後，不讓舊認證留在新資料上。

const admin = require("firebase-admin");
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {normalizeLicense, text} = require("./normalize");
const {guardShopCertification} = require("./profile_lock");
const {mirrorLicenseLink} = require("./directory_operations");

/**
 * @param {FirebaseFirestore.Transaction} tx 交易
 * @param {string} license 正規化字號
 * @param {string} shopId 店家
 * @param {boolean} dropCertified 是否解除這家的認證綁定
 * @param {boolean} keepCandidate 是否仍列為候選
 */
async function updateLink(tx, license, shopId, dropCertified, keepCandidate) {
  if (!license) {
    return;
  }
  const ref = admin.firestore()
      .collection("legal_pet_license_links")
      .doc(license);
  const snap = await tx.get(ref);
  const data = snap.exists ? snap.data() : {};
  const candidates = Array.isArray(data.candidateShopIds) ?
    data.candidateShopIds.filter((id) => {
      return id !== shopId;
    }) :
    [];
  if (keepCandidate && candidates.length < 20) {
    candidates.push(shopId);
  }
  const patch = {
    normalizedLicense: license,
    candidateShopIds: candidates,
  };
  if (dropCertified && text(data.certifiedShopId) === shopId) {
    patch.certifiedShopId = "";
  }
  tx.set(ref, patch, {merge: true});
}

const guardShopLicenseCertification = onDocumentWritten(
    {
      document: "shops/{shopId}",
      region: "asia-east1",
    },
    async (event) => {
      const afterSnap = event.data.after;
      if (!afterSnap.exists) {
        return;
      }
      const before = event.data.before.exists ? event.data.before.data() : {};
      const after = afterSnap.data() || {};
      const beforeNorm = normalizeLicense(before.licenseNumber);
      const afterNorm = normalizeLicense(after.licenseNumber);
      const decision = guardShopCertification(before, after);
      const needsNorm = text(after.normalizedLicenseNumber) !== afterNorm;
      if (!needsNorm && !decision.clearLicense && beforeNorm === afterNorm) {
        return;
      }
      if (needsNorm || decision.clearLicense) {
        const patch = {normalizedLicenseNumber: afterNorm};
        if (decision.clearLicense) {
          patch.licenseVerified = false;
          patch.isPublic = false;
        }
        await afterSnap.ref.update(patch);
      }
      const dropCertified = decision.clearLicense ||
        (before.licenseVerified === true && beforeNorm !== afterNorm);
      const db = admin.firestore();
      await db.runTransaction(async (tx) => {
        const beforeRef = beforeNorm && beforeNorm !== afterNorm ?
          db.collection("legal_pet_license_links").doc(beforeNorm) :
          null;
        const afterRef = afterNorm ?
          db.collection("legal_pet_license_links").doc(afterNorm) :
          null;
        const beforeSnap = beforeRef ? await tx.get(beforeRef) : null;
        const afterSnap = afterRef && afterRef !== beforeRef ?
          await tx.get(afterRef) :
          beforeSnap;
        if (beforeRef && beforeSnap) {
          const data = beforeSnap.exists ? beforeSnap.data() : {};
          const candidates = Array.isArray(data.candidateShopIds) ?
            data.candidateShopIds.filter((id) => {
              return id !== event.params.shopId;
            }) :
            [];
          const patch = {
            normalizedLicense: beforeNorm,
            candidateShopIds: candidates,
          };
          const certifiedHere = text(data.certifiedShopId) ===
            event.params.shopId;
          if (dropCertified && certifiedHere) {
            patch.certifiedShopId = "";
          }
          tx.set(beforeRef, patch, {merge: true});
        }
        if (afterRef) {
          const data = afterSnap && afterSnap.exists ? afterSnap.data() : {};
          const candidates = Array.isArray(data.candidateShopIds) ?
            data.candidateShopIds.filter((id) => {
              return id !== event.params.shopId;
            }) :
            [];
          if (candidates.length < 20) {
            candidates.push(event.params.shopId);
          }
          const patch = {
            normalizedLicense: afterNorm,
            candidateShopIds: candidates,
          };
          if (dropCertified && beforeNorm === afterNorm &&
              text(data.certifiedShopId) === event.params.shopId) {
            patch.certifiedShopId = "";
          }
          tx.set(afterRef, patch, {merge: true});
        }
      });
      try {
        if (beforeNorm) {
          await mirrorLicenseLink(db, beforeNorm);
        }
        if (afterNorm && afterNorm !== beforeNorm) {
          await mirrorLicenseLink(db, afterNorm);
        }
      } catch (error) {
        console.error("mirror license link failed", error);
      }
    },
);

module.exports = {
  guardShopLicenseCertification,
  updateLink,
};
