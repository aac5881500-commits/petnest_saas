/* eslint-disable require-jsdoc */
const test = require("node:test");
const assert = require("node:assert/strict");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  storeOrderRequestIdentity,
  readStoreOrderReplay,
  createStoreOrderOnce,
  storeOrderFailureFromTransaction,
} = require("./store_order_idempotency");

// Optimistic transaction retries model two requests reading the same missing
// order. All simulated stock, points, counter and promotion writes commit only
// with the production helper's order document and immutable response.
function fakeFirestore() {
  const records = new Map();
  let serial = 0;
  let rejectCommit = null;
  let lostCommitResponse = null;
  function snapshot(reference) {
    const record = records.get(reference.path);
    const data = record ? structuredClone(record.data) : undefined;
    return {id: reference.id, ref: reference, exists: !!record,
      data: () => data, version: record ? record.version : 0};
  }
  function doc(path) {
    return {
      id: path.split("/").at(-1), path,
      collection: (name) => collection(`${path}/${name}`),
      get: async function() {
        return snapshot(this);
      },
    };
  }
  function collection(path) {
    return {doc: (id = `auto-${++serial}`) => doc(`${path}/${id}`)};
  }
  function put(path, data) {
    const previous = records.get(path);
    records.set(path, {data: structuredClone(data),
      version: (previous ? previous.version : 0) + 1});
  }
  return {
    collection, records, put,
    failNextCommit: (error) => {
      rejectCommit = error;
    },
    loseNextCommitResponse: (error) => {
      lostCommitResponse = error;
    },
    runTransaction: async (callback) => {
      for (let attempt = 0; attempt < 8; attempt++) {
        const reads = new Map();
        const writes = [];
        const result = await callback({
          get: async (reference) => {
            assert.equal(writes.length, 0, "read after write");
            const snap = snapshot(reference);
            reads.set(reference.path, snap.version);
            return snap;
          },
          set: (reference, data) => writes.push({reference, data}),
        });
        if (rejectCommit) {
          const error = rejectCommit;
          rejectCommit = null;
          throw error;
        }
        if ([...reads].some(([path, version]) => {
          return (records.get(path)?.version || 0) !== version;
        })) continue;
        for (const {reference, data} of writes) put(reference.path, data);
        if (lostCommitResponse) {
          const error = lostCommitResponse;
          lostCommitResponse = null;
          throw error;
        }
        return result;
      }
      throw new Error("transaction retry exhausted");
    },
  };
}

const request = {
  requestId: "checkout-1", items: [{productId: "food", quantity: 1}],
  customerName: "顧客", customerPhone: "0912345678", requestedPoints: 10,
};
const expiry = "2026-10-24T12:20:00.000Z";
function harness() {
  const db = fakeFirestore();
  let validations = 0;
  async function invoke({uid = "u", shopId = "s", data = request,
    validationFails = false, creationError = null, amount = 90} = {}) {
    const identity = storeOrderRequestIdentity({shopId, userId: uid,
      requestData: data});
    const orders = db.collection("shops").doc(shopId).collection("store_orders");
    const orderRef = identity ? orders.doc(identity.orderId) : orders.doc();
    const replay = await readStoreOrderReplay(orderRef, identity);
    if (replay) return replay;
    validations++;
    if (validationFails) throw new Error("product no longer available");
    return createStoreOrderOnce({firestore: db, orderRef, identity,
      create: async (transaction) => {
        const effectRef = db.collection("effects").doc(shopId);
        const effectSnap = await transaction.get(effectRef);
        const effects = effectSnap.data() || {
          reserved: 0, pointsSpent: 0, promotionUses: 0, orderCounter: 0,
        };
        const next = effects.orderCounter + 1;
        transaction.set(effectRef, {
          reserved: effects.reserved + 1,
          pointsSpent: effects.pointsSpent + 10,
          promotionUses: effects.promotionUses + 1,
          orderCounter: next,
        });
        if (creationError) throw creationError;
        const response = {orderId: orderRef.id, orderCode: `S${next}`, shopId,
          totalAmount: amount, pointsUsed: 10, pointAmount: 10,
          reservationExpireAt: expiry};
        return {response, order: {...response, userId: uid,
          status: "pending_payment", paymentStatus: "unpaid"}};
      }});
  }
  return {db, invoke, get validations() {
    return validations;
  }};
}

test("同key並行送單只扣一次點、保留一次庫存、累加一次促銷及流水號", async () => {
  const h = harness();
  const [first, second] = await Promise.all([h.invoke(), h.invoke()]);
  assert.deepEqual(first, second);
  assert.deepEqual(h.db.records.get("effects/s").data, {
    reserved: 1, pointsSpent: 10, promotionUses: 1, orderCounter: 1,
  });
});

test("已commit但回應遺失的重試先回原結果，不重新檢價與庫存", async () => {
  const h = harness();
  const first = await h.invoke();
  const path = `shops/s/store_orders/${first.orderId}`;
  h.db.put(path, {...h.db.records.get(path).data,
    reservationExpireAt: "2026-10-27T12:20:00.000Z"});
  const replay = await h.invoke({validationFails: true, amount: 999});
  assert.deepEqual(replay, first);
  assert.equal(replay.reservationExpireAt, expiry);
  assert.equal(h.validations, 1);
});

test("同key異內容拒絕，包含聯絡資料、品項、數量及點數", async () => {
  const h = harness();
  await h.invoke();
  for (const changed of [
    {customerName: "別人"}, {customerPhone: "0987654321"},
    {items: [{productId: "food", quantity: 2}]},
    {items: [{bundlePromotionId: "bundle", quantity: 1}]},
    {requestedPoints: 20},
  ]) {
    await assert.rejects(h.invoke({data: {...request, ...changed}}),
        {code: "already-exists"});
  }
  assert.equal(h.db.records.get("effects/s").data.orderCounter, 1);
});

test("同key異內容同時提交，交易衝突後只保留一份原子副作用", async () => {
  const h = harness();
  const results = await Promise.allSettled([
    h.invoke(), h.invoke({data: {...request, customerName: "變更"}}),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(results.find((r) => r.status === "rejected").reason.code,
      "already-exists");
  assert.equal(h.db.records.get("effects/s").data.pointsSpent, 10);
});

test("callback失敗回failed-precondition且不提交，可修正同key內容", async () => {
  const h = harness();
  await assert.rejects(h.invoke({creationError: new Error("庫存不足")}),
      {code: "failed-precondition", message: "庫存不足"});
  assert.equal(h.db.records.size, 0);
  const fixed = await h.invoke({data: {...request, customerName: "修正姓名"}});
  assert.ok(fixed.orderId);
  assert.equal(h.db.records.get("effects/s").data.orderCounter, 1);
});

test("callback既有HttpsError保留代碼、內容與details", async () => {
  const h = harness();
  const original = new HttpsError("permission-denied", "不允許扣點", {reason: "owner"});
  await assert.rejects(h.invoke({creationError: original}),
      (error) => error === original);
  assert.equal(h.db.records.size, 0);
});

test("callback內Firestore錯誤保留code供SDK重試，不誤判業務拒絕", async () => {
  for (const code of [4, 10, 14]) {
    const h = harness();
    const original = Object.assign(new Error("Firestore unavailable"), {code});
    await assert.rejects(h.invoke({creationError: original}),
        (error) => error === original);
    assert.equal(h.db.records.size, 0);
    assert.equal(storeOrderFailureFromTransaction(original).code, "unavailable");
  }
});

test("commit階段錯誤不轉成業務失敗，保留原error供外層判定", async () => {
  const h = harness();
  const original = Object.assign(new Error("commit unavailable"), {code: 14});
  h.db.failNextCommit(original);
  await assert.rejects(h.invoke(), (error) => error === original);
  assert.equal(h.db.records.size, 0);
  const retried = await h.invoke();
  assert.ok(retried.orderId);
  assert.equal(h.db.records.get("effects/s").data.orderCounter, 1);
});

test("已commit但回覆遺失仍保留原error，同key恢復不重扣", async () => {
  const h = harness();
  const original = new Error("commit acknowledgement lost");
  h.db.loseNextCommitResponse(original);
  await assert.rejects(h.invoke(), (error) => error === original);
  const replay = await h.invoke({validationFails: true});
  assert.ok(replay.orderId);
  assert.equal(h.validations, 1);
  assert.deepEqual(h.db.records.get("effects/s").data, {
    reserved: 1, pointsSpent: 10, promotionUses: 1, orderCounter: 1,
  });
});

test("外層將未知交易結果轉unavailable，既有HttpsError保持原樣", () => {
  const mapped = storeOrderFailureFromTransaction(new Error("raw commit detail"));
  assert.equal(mapped.code, "unavailable");
  assert.equal(mapped.message, "訂單結果尚未確認，請在同一頁重試，避免重新下單。");
  for (const code of ["failed-precondition", "already-exists", "data-loss", "unavailable"]) {
    const original = new HttpsError(code, "原訊息", {reason: "fixture"});
    assert.equal(storeOrderFailureFromTransaction(original), original);
  }
});

test("交易內replay讀取失敗保持未知結果，不解凍可能已有的訂單", async () => {
  const original = new Error("replay read unavailable");
  const identity = storeOrderRequestIdentity({shopId: "s", userId: "u", requestData: request});
  const firestore = {runTransaction: async (callback) => callback({
    get: async () => {
      throw original;
    },
  })};
  await assert.rejects(createStoreOrderOnce({firestore, orderRef: {}, identity,
    create: async () => assert.fail("must resolve replay before creating")}),
  (error) => error === original);
  assert.equal(storeOrderFailureFromTransaction(original).code, "unavailable");
});

test("已有訂單但原回傳缺損為data-loss，不當成未建單重建", async () => {
  const h = harness();
  const first = await h.invoke();
  const path = `shops/s/store_orders/${first.orderId}`;
  const order = h.db.records.get(path).data;
  const identity = storeOrderRequestIdentity({shopId: "s", userId: "u", requestData: request});
  const orderRef = h.db.collection("shops").doc("s").collection("store_orders").doc(identity.orderId);
  for (const broken of [null, {...first, orderId: "wrong"}, {...first, shopId: "other"}]) {
    h.db.put(path, {...order, creationResponse: broken});
    await assert.rejects(h.invoke(), {code: "data-loss"});
    await assert.rejects(createStoreOrderOnce({firestore: h.db, orderRef, identity,
      create: async () => assert.fail("must not recreate an existing order")}),
    {code: "data-loss"});
  }
  assert.equal(h.db.records.get("effects/s").data.orderCounter, 1);
});

test("不同會員或店家使用相同key互相隔離", async () => {
  const h = harness();
  const one = await h.invoke();
  const two = await h.invoke({uid: "u2"});
  const three = await h.invoke({shopId: "s2"});
  assert.equal(new Set([one.orderId, two.orderId, three.orderId]).size, 3);
  assert.equal(h.db.records.get("effects/s").data.orderCounter, 2);
  assert.equal(h.db.records.get("effects/s2").data.orderCounter, 1);
});

test("沒有requestId的舊客戶仍可建立獨立訂單", async () => {
  const h = harness();
  const data = {...request, requestId: ""};
  const first = await h.invoke({data});
  const second = await h.invoke({data});
  assert.notEqual(first.orderId, second.orderId);
  assert.equal(h.db.records.get("effects/s").data.orderCounter, 2);
});

test("指紋沿用建單正規化，未知欄位及格式差異不誤判異內容", async () => {
  const h = harness();
  const first = await h.invoke();
  const second = await h.invoke({data: {...request,
    requestId: " checkout-1 ", customerName: " 顧客 ",
    requestedPoints: "10", irrelevant: true,
    items: [{productId: " food ", quantity: "1"}],
  }});
  assert.deepEqual(first, second);
});
