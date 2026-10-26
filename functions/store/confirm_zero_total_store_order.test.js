/* eslint-disable require-jsdoc */
const test = require("node:test");
const assert = require("node:assert/strict");
const {confirmZeroTotalStoreOrder} = require("./confirm_zero_total_store_order");

const pending = {
  shopId: "s", userId: "u", status: "pending_payment", paymentStatus: "unpaid",
  totalAmount: 0, pointsUsed: 300, pointAmount: 100,
};
const reservation = {
  status: "held", userId: "u", expireAt: {toMillis: () => 200},
  lines: [{inventoryItemId: "food", quantity: 1}],
};
const spend = {shopId: "s", userId: "u", points: -300, amount: 100,
  returned: false};

function fixture({order = pending, held = reservation, log = spend} = {}) {
  const reads = [];
  let conversions = 0;
  const documents = {
    "shops/s/store_reservations/o": held,
    "shops/s/member_point_logs/spend_store_o": log,
  };
  function collection(path) {
    return {doc: (id) => ({
      path: `${path}/${id}`,
      collection: (name) => collection(`${path}/${id}/${name}`),
    })};
  }
  const args = {
    firestore: {collection},
    transaction: {
      get: async (ref) => {
        assert.equal(conversions, 0, "all proof reads precede stock writes");
        reads.push(ref.path);
        return {exists: !!documents[ref.path], data: () => documents[ref.path]};
      },
    },
    shopId: "s", orderId: "o", actorUid: "u", canManage: false, order,
    now: "server-timestamp", nowMs: 100,
    convertInventory: async (params) => {
      assert.equal(params.shopId, "s");
      assert.equal(params.orderId, "o");
      conversions++;
    },
  };
  return {args, reads, get conversions() {
    return conversions;
  }};
}

test("全額點數折抵訂單使用既有扣庫存流程並標示零元付款完成", async () => {
  const f = fixture();
  const patch = await confirmZeroTotalStoreOrder(f.args);
  assert.equal(f.conversions, 1);
  assert.equal(f.reads.length, 2);
  assert.deepEqual(patch, {
    status: "paid", paymentStatus: "paid", paidAt: "server-timestamp",
    lastPaymentAmount: 0, lastPaymentMethod: "points",
  });
  assert.equal("pointsUsed" in patch, false);
  assert.equal("totalAmount" in patch, false);
  assert.equal("lastPaymentId" in patch, false);
});

test("免費商品無扣點紀錄也能確認，但不偽造金流紀錄", async () => {
  const f = fixture({order: {...pending, pointsUsed: 0, pointAmount: 0},
    log: null});
  const patch = await confirmZeroTotalStoreOrder(f.args);
  assert.equal(patch.lastPaymentMethod, "no_payment_required");
  assert.equal(f.conversions, 1);
  assert.deepEqual(f.reads, ["shops/s/store_reservations/o"]);
});

test("重送已完成確認或後續履約狀態不會再次扣庫存", async () => {
  for (const status of ["paid", "preparing", "ready_for_pickup", "completed"]) {
    const f = fixture({order: {...pending, status, paymentStatus: "paid"}});
    assert.equal(await confirmZeroTotalStoreOrder(f.args), null);
    assert.equal(f.conversions, 0);
    assert.equal(f.reads.length, 0);
  }
});

test("其他會員或只有查看權限的員工不可確認；管理者可處理", async () => {
  const f = fixture();
  f.args.actorUid = "other";
  await assert.rejects(confirmZeroTotalStoreOrder(f.args),
      {code: "permission-denied"});
  assert.equal(f.conversions, 0);
  f.args.canManage = true;
  assert.equal((await confirmZeroTotalStoreOrder(f.args)).status, "paid");
});

test("僅接受後端訂單的數值零，不接受非零、缺值或字串零", async () => {
  for (const totalAmount of [undefined, null, "0", 1, -1, NaN, Infinity]) {
    const f = fixture({order: {...pending, totalAmount}});
    await assert.rejects(confirmZeroTotalStoreOrder(f.args),
        {code: "failed-precondition"});
    assert.equal(f.conversions, 0);
  }
});

test("取消、狀態不一致、已返還庫存或跨店訂單不能確認", async () => {
  for (const change of [{status: "cancelled"}, {paymentStatus: "paid"},
    {inventoryReturned: true}, {shopId: "other"}]) {
    const f = fixture({order: {...pending, ...change}});
    await assert.rejects(confirmZeroTotalStoreOrder(f.args),
        {code: "failed-precondition"});
    assert.equal(f.conversions, 0);
  }
});

test("已過期、缺少或不再held的庫存保留不得完成零元訂單", async () => {
  for (const held of [null, {...reservation, status: "released"},
    {...reservation, status: "converted"},
    {...reservation, expireAt: {toMillis: () => 100}},
    {...reservation, expireAt: null}]) {
    const f = fixture({held});
    await assert.rejects(confirmZeroTotalStoreOrder(f.args),
        {code: "deadline-exceeded"});
    assert.equal(f.conversions, 0);
  }
});

test("扣點紀錄缺失、已退款、數量錯誤或屬於別人都拒絕確認", async () => {
  for (const log of [null, {...spend, returned: true},
    {...spend, points: -100}, {...spend, amount: 99},
    {...spend, userId: "other"}, {...spend, shopId: "other"}]) {
    const f = fixture({log});
    await assert.rejects(confirmZeroTotalStoreOrder(f.args),
        {code: "failed-precondition"});
    assert.equal(f.conversions, 0);
  }
});

test("扣庫存失敗向外拋出以回滾，不回傳已付款更新", async () => {
  const f = fixture();
  f.args.convertInventory = async () => {
    throw new Error("庫存不足");
  };
  await assert.rejects(confirmZeroTotalStoreOrder(f.args), /庫存不足/);
});
