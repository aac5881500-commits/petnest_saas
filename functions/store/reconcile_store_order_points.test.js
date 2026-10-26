/* eslint-disable require-jsdoc */
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  reconcileCancelledStoreOrderPoints,
} = require("./reconcile_store_order_points");

// Exercises the production restoreSpend transaction with an atomic local store.
// No Firebase app, credentials, network, or production documents are used.
function fakeFirestore(initial) {
  const documents = new Map(Object.entries(initial));
  let failCommit = false;
  let reads = 0;
  const snapshot = (ref) => ({
    exists: documents.has(ref.path),
    ref,
    data: () => documents.has(ref.path) ? {...documents.get(ref.path)} : undefined,
  });
  function ref(path) {
    const result = {
      path,
      collection: (name) => collection(`${path}/${name}`),
      get: async () => {
        reads++;
        return snapshot(result);
      },
    };
    return result;
  }
  function collection(path) {
    return {doc: (id) => ref(`${path}/${id}`)};
  }
  return {
    collection,
    documents,
    get reads() {
      return reads;
    },
    failNextCommit: () => {
      failCommit = true;
    },
    runTransaction: async (callback) => {
      const writes = [];
      const result = await callback({
        get: async (reference) => {
          assert.equal(writes.length, 0, "transaction reads must precede writes");
          reads++;
          return snapshot(reference);
        },
        set: (reference, data, options) => {
          writes.push({reference, data, merge: options && options.merge});
        },
        update: (reference, data) => {
          assert.equal(documents.has(reference.path), true);
          writes.push({reference, data, merge: true});
        },
      });
      if (failCommit) {
        failCommit = false;
        throw new Error("transient commit failure");
      }
      for (const {reference, data, merge} of writes) {
        documents.set(reference.path, {
          ...(merge ? documents.get(reference.path) : {}),
          ...data,
        });
      }
      return result;
    },
  };
}

const orderPath = "shops/s/store_orders/o";
const pointPath = "shops/s/member_points/u";
const spendPath = "shops/s/member_point_logs/spend_store_o";
const order = {
  userId: "u",
  status: "cancelled",
  pointAmount: 10,
  pointsUsed: 30,
  cancelReason: "庫存保留已過期，請重新下單",
};
const spend = {points: -30, amount: 10, returned: false};
function fixture({legacy = false, missingLog = false} = {}) {
  return fakeFirestore({
    [orderPath]: {...order},
    [pointPath]: {
      ...(legacy ? {} : {currentPoints: 70}),
      points: 70,
      totalEarnedPoints: 100,
      totalUsedPoints: 30,
    },
    ...(!missingLog ? {[spendPath]: {...spend}} : {}),
  });
}
function reconcile(db, after = order, before = {status: "pending_payment"}) {
  return reconcileCancelledStoreOrderPoints({
    firestore: db,
    shopId: "s",
    orderId: "o",
    order: after,
    previousOrder: before,
  });
}

test("庫存過期的取消事件退回實際扣點，非僅折抵金額", async () => {
  const db = fixture();
  await reconcile(db);
  const points = db.documents.get(pointPath);
  assert.equal(points.currentPoints, 100);
  assert.equal(points.points, 100);
  assert.equal(points.totalUsedPoints, 0);
  assert.equal(points.totalEarnedPoints, 100);
  assert.equal(db.documents.get(spendPath).returned, true);
  assert.equal(db.documents.get(orderPath).pointsReturned, true);
});

test("同一事件重送或前景已退點不會重複加點", async () => {
  const db = fixture();
  await reconcile(db);
  await reconcile(db);
  assert.equal(db.documents.get(pointPath).currentPoints, 100);
  assert.equal(db.documents.get(pointPath).totalUsedPoints, 0);
});

test("退點 transaction 失敗不留下部分寫入，事件重試可修復", async () => {
  const db = fixture();
  db.failNextCommit();
  await assert.rejects(reconcile(db), /transient commit failure/);
  assert.equal(db.documents.get(pointPath).currentPoints, 70);
  assert.equal(db.documents.get(spendPath).returned, false);
  assert.equal(db.documents.get(orderPath).pointsReturned, undefined);
  await reconcile(db);
  assert.equal(db.documents.get(pointPath).currentPoints, 100);
});

test("舊會員僅 points 餘額也會同步回寫兩個餘額欄位", async () => {
  const db = fixture({legacy: true});
  await reconcile(db);
  assert.equal(db.documents.get(pointPath).currentPoints, 100);
  assert.equal(db.documents.get(pointPath).points, 100);
});

test("缺少宣稱已扣點的紀錄會拋錯等待重試，不會偽造退款或靜默成功", async () => {
  const db = fixture({missingLog: true});
  await assert.rejects(reconcile(db), /missing its points spend log/);
  assert.equal(db.documents.get(pointPath).currentPoints, 70);
  db.documents.set(spendPath, {...spend});
  await reconcile(db);
  assert.equal(db.documents.get(pointPath).currentPoints, 100);
});

test("非取消、未扣點、已退點及自身回寫事件均不觸發資料讀寫", async () => {
  const db = fixture();
  for (const status of ["pending_payment", "paid", "completed"]) {
    assert.equal(await reconcile(db, {...order, status}), false);
  }
  assert.equal(await reconcile(db, {...order, pointsReturned: true}), false);
  assert.equal(await reconcile(db, {
    ...order, pointsUsed: 0, pointAmount: 0,
  }), false);
  assert.equal(await reconcile(db, order, {status: "cancelled"}), false);
  assert.equal(db.reads, 0);
  assert.equal(db.documents.get(pointPath).currentPoints, 70);
});
