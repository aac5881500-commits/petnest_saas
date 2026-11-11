const fs = require('node:fs');
const path = require('node:path');
const {test, before, after} = require('node:test');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, setDoc, updateDoc} = require('firebase/firestore');
const {ref, uploadBytes, getBytes} = require('firebase/storage');
let env;
const jpeg = new Uint8Array([255, 216, 255, 217]);
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-medication', firestore: {rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8')}, storage: {rules: fs.readFileSync(path.resolve(__dirname, '../../storage.rules'), 'utf8')}});
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'shops/s'), {ownerUid: 'owner'});
    await setDoc(doc(db, 'shops/other'), {ownerUid: 'otherOwner'});
    await setDoc(doc(db, 'shop_members/s_worker'), {shopId: 's', uid: 'worker', role: 'staff', permissions: {manage_bookings: true}});
    await setDoc(doc(db, 'shop_members/s_viewer'), {shopId: 's', uid: 'viewer', role: 'staff', permissions: {edit_media: true}});
    await setDoc(doc(db, 'user_profiles/u/pets/p'), {species: 'cat', name: '麻糬'});
    await setDoc(doc(db, 'bookings/b'), {shopId: 's', userId: 'u', status: 'checked_in', medication: {state: 'confirmed'}});
    await uploadBytes(ref(ctx.storage(), 'medication_uploads/u/s/a.jpg'), jpeg, {contentType: 'image/jpeg'});
  });
});
after(async () => { if (env) await env.cleanup(); });
function storage(uid) { return uid ? env.authenticatedContext(uid).storage() : env.unauthenticatedContext().storage(); }
test('medication photo readable by uploader, owner and booking staff', async () => {
  for (const uid of ['u', 'owner', 'worker']) await assertSucceeds(getBytes(ref(storage(uid), 'medication_uploads/u/s/a.jpg')));
});
test('private photos deny anonymous, other customer, other shop owner and unrelated staff', async () => {
  for (const uid of [null, 'stranger', 'otherOwner', 'viewer']) await assertFails(getBytes(ref(storage(uid), 'medication_uploads/u/s/a.jpg')));
});
test('customer may upload own JPEG but not another user path or PNG', async () => {
  await assertSucceeds(uploadBytes(ref(storage('u'), 'medication_uploads/u/s/new.jpg'), jpeg, {contentType: 'image/jpeg'}));
  await assertFails(uploadBytes(ref(storage('u'), 'medication_uploads/other/s/new.jpg'), jpeg, {contentType: 'image/jpeg'}));
  await assertFails(uploadBytes(ref(storage('u'), 'medication_uploads/u/s/new.png'), jpeg, {contentType: 'image/png'}));
});
test('referenced photo immutable and inspection identity cannot upload', async () => {
  await assertFails(uploadBytes(ref(storage('u'), 'medication_uploads/u/s/a.jpg'), jpeg, {contentType: 'image/jpeg'}));
  const preview = env.authenticatedContext('u', {petnestInspection: true}).storage();
  await assertFails(uploadBytes(ref(preview, 'medication_uploads/u/s/preview.jpg'), jpeg, {contentType: 'image/jpeg'}));
});
test('direct booking create cannot forge authoritative medication snapshot', async () => {
  const db = env.authenticatedContext('u').firestore();
  const base = {shopId: 's', userId: 'u', petIds: ['p'], source: 'customer', status: 'pending'};
  await assertSucceeds(setDoc(doc(db, 'bookings/plain'), base));
  await assertFails(setDoc(doc(db, 'bookings/forged'), {...base, medication: {finalized: true, finalAmount: 0}}));
  await assertFails(setDoc(doc(db, 'bookings/forged-request'), {...base, medicationRequest: {medicines: []}}));
});
test('customer cannot directly confirm or alter medication on booking', async () => {
  const db = env.authenticatedContext('u').firestore();
  await assertFails(updateDoc(doc(db, 'bookings/b'), {medication: {state: 'confirmed', finalized: true}}));
});
