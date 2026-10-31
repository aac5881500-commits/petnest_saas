// 檔案名稱：functions/legal_pet/callables.js
// 功能說明：政府業者同步、查核、認證審核與平台名單的 Cloud Functions 出口。

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("../platform/inspection_write_guard");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {canViewDirectory} = require("./access");
const {loadPlatformUser} = require("./staff_access");
const {runLegalPetSync} = require("./sync_job");
const shopOps = require("./shop_operations");
const directory = require("./directory_operations");
const {
  guardShopLicenseCertification,
} = require("./shop_license_guard");

const syncOptions = {
  region: "asia-east1",
  timeoutSeconds: 540,
  memory: "1GiB",
};

const syncLegalPetBusinesses = onCall(syncOptions, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "請先登入");
  }
  const user = await loadPlatformUser(admin.firestore(), request.auth.uid);
  if (!canViewDirectory(user)) {
    throw new HttpsError("permission-denied", "沒有同步業者資料的權限");
  }
  return runLegalPetSync(admin.firestore(), "manual");
});

const syncLegalPetBusinessesDaily = onSchedule(Object.assign({
  schedule: "30 3 * * *",
  timeZone: "Asia/Taipei",
}, syncOptions), async () => {
  await runLegalPetSync(admin.firestore(), "schedule");
});

const lookupLegalPetLicense = onCall({region: "asia-east1",
  inspectionRead: true}, (request) => {
  return shopOps.lookupLegalPetLicense(request);
});

const saveShopInitialProfile = onCall({region: "asia-east1"}, (request) => {
  return shopOps.saveShopInitialProfile(request);
});

const submitShopCertification = onCall({region: "asia-east1"}, (request) => {
  return shopOps.submitShopCertification(request);
});

const reviewShopChangeRequest = onCall({region: "asia-east1"}, (request) => {
  return shopOps.reviewShopChangeRequest(request);
});

const listLegalPetBusinesses = onCall({
  region: "asia-east1",
  timeoutSeconds: 60,
  memory: "512MiB",
}, (request) => {
  return directory.listLegalPetBusinesses(request);
});

const getLegalPetBusiness = onCall({region: "asia-east1"}, (request) => {
  return directory.getLegalPetBusiness(request);
});

const updateLegalPetContact = onCall({region: "asia-east1"}, (request) => {
  return directory.updateLegalPetContact(request);
});

const backfillLegalPetDirectory = onCall({
  region: "asia-east1",
  timeoutSeconds: 120,
  memory: "512MiB",
}, (request) => {
  return directory.backfillLegalPetDirectory(request);
});

const backfillLicenseLookupKeys = onCall({
  region: "asia-east1",
  timeoutSeconds: 120,
  memory: "512MiB",
}, (request) => {
  return directory.backfillLicenseLookupKeys(request);
});

module.exports = {
  syncLegalPetBusinesses,
  syncLegalPetBusinessesDaily,
  lookupLegalPetLicense,
  saveShopInitialProfile,
  submitShopCertification,
  reviewShopChangeRequest,
  listLegalPetBusinesses,
  getLegalPetBusiness,
  updateLegalPetContact,
  backfillLegalPetDirectory,
  backfillLicenseLookupKeys,
  guardShopLicenseCertification,
};
