const {readFileSync} = require('node:fs');
const {join} = require('node:path');
const {test} = require('node:test');
const {
  initializeTestEnvironment, assertSucceeds, assertFails,
} = require('@firebase/rules-unit-testing');
const {doc, getDoc, getDocs, collection, setDoc, writeBatch, runTransaction, serverTimestamp} = require('firebase/firestore');

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
    // Match the additive client's transaction: two staff saves preserve both histories.
    const append = async (text, id) => {
      for (let attempt = 0; attempt < 5; attempt++) {
        let revision = 0;
        try {
          await runTransaction(owner, async (tx) => {
            const current = await tx.get(note);
            revision = current.data().revision;
            const next = payload(revision + 1, text);
            tx.set(note, next);
            tx.set(doc(owner, path + '/history/' + id), next);
          });
          return;
        } catch (error) {
          if (!['permission-denied', 'aborted'].includes(error.code)) throw error;
          if ((await getDoc(note)).data().revision <= revision) throw error;
        }
      }
      throw new Error('Concurrent append retry exhausted');
    };
    await append('【健康觀察】\n單筆確認', 'check');
    await Promise.all([
      append('【住宿交代】\n請慢慢接近', 'stay'),
      append('【餵藥交代】\n晚餐後餵藥', 'medicine'),
    ]);
    const history = await getDocs(collection(owner, path + '/history'));
    if (history.size !== 4) throw new Error('Existing and concurrent entries must all remain');
    const texts = history.docs.map((row) => row.data().text);
    for (const expected of ['喵喵｜藥名｜用量', '【住宿交代】\n請慢慢接近', '【餵藥交代】\n晚餐後餵藥']) {
      if (!texts.includes(expected)) throw new Error('Missing preserved handover entry');
    }
    if ((await getDoc(note)).data().revision !== 4) throw new Error('Expected atomic next revisions');
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'bookings/order-a'), {settlementLocked: true}, {merge: true});
    });
    await assertSucceeds(getDoc(note));
    await assertFails(setDoc(note, payload(5, '已鎖定')));
  } finally {
    await env.cleanup();
  }
});
