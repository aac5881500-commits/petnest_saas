const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('This test requires an isolated Firestore emulator.');
const admin = require('../../functions/node_modules/firebase-admin');
admin.initializeApp({projectId: 'demo-medication-save'});
const db = admin.firestore();
const {saveMedicationSetting} = require('../../functions/medication/medication_functions');
const shopId = 'medication-save-shop';
const owner = 'medication-save-owner';
const setting = {enabled: true, types: ['oral', 'eye'], mode: 'day', price: 50, mixFree: true, successOnly: true, splitTypes: false, includedTimes: 0, includedPills: 0, windows: [{start: '09:00', end: '21:00'}], note: '請自備藥袋照片'};
before(async () => { await db.collection('shops').doc(shopId).set({ownerUid: owner, name: '測試店家'}); });
after(async () => { await db.collection('shops').doc(shopId).delete(); await admin.app().delete(); });
test('actual callable saves setting and reads back from Firestore', async () => {
  const result = await saveMedicationSetting.run({auth: {uid: owner, token: {}}, data: {shopId, setting}});
  assert.equal(result.ok, true);
  const doc = (await db.collection('shops').doc(shopId).get()).data();
  assert.equal(doc.medicationSetting.price, 50);
  assert.equal(doc.medicationSetting.mode, 'day');
  assert.equal(doc.medicationSetting.dayRule, 'stay_days');
  assert.equal(doc.medicationSettingUpdatedBy, owner);
  assert.ok(doc.medicationSettingUpdatedAt.toDate());
});
test('actual callable rejects unauthorized write and keeps the saved value', async () => {
  await assert.rejects(saveMedicationSetting.run({auth: {uid: 'other-owner', token: {}}, data: {shopId, setting: {...setting, price: 999}}}), {code: 'permission-denied'});
  assert.equal((await db.collection('shops').doc(shopId).get()).data().medicationSetting.price, 50);
});
test('actual callable rejects invalid settings without replacing good data', async () => {
  await assert.rejects(saveMedicationSetting.run({auth: {uid: owner, token: {}}, data: {shopId, setting: {...setting, price: -1}}}), {code: 'failed-precondition'});
  assert.equal((await db.collection('shops').doc(shopId).get()).data().medicationSetting.price, 50);
});
