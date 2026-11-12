const {readFileSync} = require('node:fs');
const {join} = require('node:path');
const {test} = require('node:test');
const {
  initializeTestEnvironment, assertSucceeds, assertFails,
} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, writeBatch, serverTimestamp} = require('firebase/firestore');

test('handover notes are private, revisioned, and locked with their order', async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-care-handover',
    firestore: {rules: readFileSync(join(__dirname, '../../firestore.rules'), 'utf8')},
  });
  try {
    const path = 'shops/shop-a/internal_handover_notes/order-a';
    const payload = (revision, text) => ({
      shopId: 'shop-a', bookingId: 'order-a', text, revision,
      updatedAt: serverTimestamp(), updatedByUid: 'owner', updatedByEmail: 'owner@example.test',
    });
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'shops/shop-a'), {ownerUid: 'owner'});
      await setDoc(doc(db, 'shops/shop-b'), {ownerUid: 'other-owner'});
      await setDoc(doc(db, 'bookings/order-a'), {shopId: 'shop-a', userId: 'customer'});
    });
    const owner = env.authenticatedContext('owner', {email: 'owner@example.test'}).firestore();
    const note = doc(owner, path);
    await assertSucceeds(getDoc(note));
    const batch = writeBatch(owner);
    batch.set(note, payload(1, '喵喵｜藥名｜用量'));
    batch.set(doc(owner, path + '/history/first'), payload(1, '喵喵｜藥名｜用量'));
    await assertSucceeds(batch.commit());
    await assertFails(setDoc(note, payload(1, '重複版本')));
    for (const uid of ['customer', 'other-owner']) {
      const db = env.authenticatedContext(uid).firestore();
      await assertFails(getDoc(doc(db, path)));
      await assertFails(getDoc(doc(db, path + '/history/first')));
      await assertFails(setDoc(doc(db, path), payload(2, '不可寫入')));
    }
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'bookings/order-a'), {settlementLocked: true}, {merge: true});
    });
    await assertSucceeds(getDoc(note));
    await assertFails(setDoc(note, payload(2, '已鎖定')));
  } finally {
    await env.cleanup();
  }
});
