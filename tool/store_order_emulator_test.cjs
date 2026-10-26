// Run only against a local, disposable Firestore emulator.
const test = require('node:test');
const assert = require('node:assert/strict');
const {createRequire} = require('node:module');
const requireFunctions = createRequire(require('node:path').resolve(__dirname, '../functions/package.json'));
const host = process.env.FIRESTORE_EMULATOR_HOST || '';
if (!/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
  throw new Error('Set FIRESTORE_EMULATOR_HOST to a localhost emulator; remote access is forbidden.');
}
const admin = requireFunctions('firebase-admin');
admin.initializeApp({projectId: 'demo-petnest-content'});
const db = admin.firestore();
const {confirmZeroTotalStoreOrder} = requireFunctions('./store/confirm_zero_total_store_order');
const {reconcileCancelledStoreOrderPoints} = requireFunctions('./store/reconcile_store_order_points');
const {Timestamp, FieldValue} = admin.firestore;

test('真實交易並行零元確認只扣一次庫存，且過期舊訂單可安全退點', async () => {
  const shopId = `store-integration-${process.pid}-${Date.now()}`;
  const shop = db.collection('shops').doc(shopId);
  const orderRef = shop.collection('store_orders').doc('zero');
  const oldRef = shop.collection('store_orders').doc('expired');
  const itemRef = shop.collection('inventory_items').doc('food');
  const productRef = shop.collection('store_products').doc('food');
  const currentOrder = {
    shopId, userId: 'buyer', totalAmount: 0, pointsUsed: 300, pointAmount: 100,
    status: 'pending_payment', paymentStatus: 'unpaid',
  };
  const oldOrder = {...currentOrder, userId: 'previous-buyer',
    totalAmount: 50, pointsUsed: 30, pointAmount: 10};
  const batch = db.batch();
  batch.set(orderRef, currentOrder);
  batch.set(oldRef, oldOrder);
  batch.set(itemRef, {name: '飼料', unit: '包', enabled: true,
    currentStock: 10, reservedQuantity: 3, weightedAverageCost: 20,
    estimatedStockCost: 200});
  batch.set(productRef, {useInventory: true, inventoryItemId: 'food',
    inventoryQuantityPerSale: 1});
  batch.set(shop.collection('store_reservations').doc('zero'), {
    userId: 'buyer', status: 'held',
    expireAt: Timestamp.fromMillis(Date.now() + 600000),
    lines: [{inventoryItemId: 'food', quantity: 1}],
  });
  batch.set(shop.collection('store_reservations').doc('expired'), {
    userId: 'previous-buyer', status: 'held',
    expireAt: Timestamp.fromMillis(Date.now() - 600000),
    lines: [{inventoryItemId: 'food', quantity: 2}],
  });
  for (const [id, order, balance] of [
    ['zero', currentOrder, 0], ['expired', oldOrder, 70],
  ]) {
    batch.set(shop.collection('member_point_logs').doc(`spend_store_${id}`), {
      shopId, userId: order.userId, points: -order.pointsUsed,
      amount: order.pointAmount, returned: false,
    });
    batch.set(shop.collection('member_points').doc(order.userId), {
      currentPoints: balance, points: balance,
      totalUsedPoints: order.pointsUsed,
      totalEarnedPoints: balance + order.pointsUsed,
    });
  }
  await batch.commit();

  const confirm = () => db.runTransaction(async transaction => {
    const order = (await transaction.get(orderRef)).data();
    const patch = await confirmZeroTotalStoreOrder({
      firestore: db, transaction, shopId, orderId: 'zero',
      actorUid: 'buyer', canManage: false, order,
      now: FieldValue.serverTimestamp(),
    });
    if (patch) transaction.update(orderRef, patch);
  });
  await Promise.all([confirm(), confirm()]);
  await confirm();
  assert.equal((await orderRef.get()).data().status, 'paid');
  const item = (await itemRef.get()).data();
  assert.equal(item.currentStock, 9);
  assert.equal(item.reservedQuantity, 0);
  assert.equal((await productRef.get()).data().publicSellableQuantity, 9);
  assert.equal((await itemRef.collection('movements').get()).size, 1);
  assert.equal((await shop.collection('inventory_consumptions').get()).size, 1);
  assert.equal((await shop.collection('store_reservations').doc('zero').get()).data().status, 'converted');
  assert.equal((await shop.collection('member_points').doc('buyer').get()).data().currentPoints, 0);

  const cancelledOrder = (await oldRef.get()).data();
  assert.equal(cancelledOrder.status, 'cancelled');
  const reconcile = () => reconcileCancelledStoreOrderPoints({
    firestore: db, shopId, orderId: 'expired',
    order: cancelledOrder, previousOrder: oldOrder,
  });
  await Promise.all([reconcile(), reconcile()]);
  assert.equal((await oldRef.get()).data().pointsReturned, true);
  const points = (await shop.collection('member_points').doc('previous-buyer').get()).data();
  assert.equal(points.currentPoints, 100);
  assert.equal(points.totalUsedPoints, 0);
});

test('真實交易並行建單只提交一次副作用，遺失回應可讀回原結果', async () => {
  const {storeOrderRequestIdentity, createStoreOrderOnce, readStoreOrderReplay} =
    requireFunctions('./store/store_order_idempotency');
  const shopId = `store-replay-${process.pid}-${Date.now()}`;
  const identity = storeOrderRequestIdentity({shopId, userId: 'buyer',
    requestData: {requestId: 'retry-key', items: [{productId: 'food', quantity: 1}]}});
  const shop = db.collection('shops').doc(shopId);
  const orderRef = shop.collection('store_orders').doc(identity.orderId);
  const effectRef = shop.collection('store_counters').doc('effects');
  const response = {shopId, orderId: orderRef.id, totalAmount: 100,
    reservationExpireAt: '2026-10-24T12:20:00.000Z'};
  const create = () => createStoreOrderOnce({firestore: db, orderRef, identity,
    create: async transaction => {
      transaction.set(effectRef, {count: FieldValue.increment(1)}, {merge: true});
      return {order: {shopId, userId: 'buyer', totalAmount: 100}, response};
    }});
  const [first, duplicate] = await Promise.all([create(), create()]);
  assert.deepEqual(first, response);
  assert.deepEqual(duplicate, first);
  assert.equal((await effectRef.get()).data().count, 1);
  assert.deepEqual(await readStoreOrderReplay(orderRef, identity), first);
  await assert.rejects(readStoreOrderReplay(orderRef, {...identity, fingerprint: 'changed'}),
    {code: 'already-exists'});
});

test.after(async () => { await db.terminate(); await admin.app().delete(); });
