/* eslint-disable require-jsdoc */
// 檔案名稱：functions/daycare/sync_shop_member.test.js
// 功能說明：安親成立後同步店家會員快取

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  memberPetPayload,
  syncShopMemberCache,
  SHOP_OWNED_FIELDS,
} = require("./sync_shop_member");

function doc(data, exists = true) {
  return {
    exists,
    id: data && data.__id,
    data: () => {
      const copy = {...(data || {})};
      delete copy.__id;
      return copy;
    },
  };
}

function createFakeDb(seed) {
  const store = {...seed};
  function pathOf(...parts) {
    return parts.join("/");
  }
  const FieldValue = {
    serverTimestamp: () => ({_sv: true}),
  };
  function col(base) {
    return {
      doc(id) {
        const full = pathOf(base, id);
        return {
          id,
          get: async () => doc(store[full], Boolean(store[full])),
          set: async (data, opts) => {
            const prev = store[full] || {};
            store[full] = opts && opts.merge ? {...prev, ...data} : {...data};
          },
          collection(name) {
            return col(pathOf(full, name));
          },
        };
      },
      where(field, _op, value) {
        const prefix = base + "/";
        const docs = Object.keys(store)
            .filter((key) => key.startsWith(prefix) &&
              !key.slice(prefix.length).includes("/"))
            .map((key) => {
              const id = key.slice(prefix.length);
              return {id, data: () => store[key], ...doc({...store[key], __id: id})};
            })
            .filter((item) => item.data()[field] === value);
        return {
          where(field2, _op2, value2) {
            const nested = docs.filter((item) => item.data()[field2] === value2);
            return {
              get: async () => ({
                docs: nested,
                size: nested.length,
              }),
            };
          },
          get: async () => ({docs, size: docs.length}),
        };
      },
      get: async () => {
        const prefix = base + "/";
        const docs = Object.keys(store)
            .filter((key) => key.startsWith(prefix) &&
              !key.slice(prefix.length).includes("/"))
            .map((key) => {
              const id = key.slice(prefix.length);
              return {id, ...doc({...store[key], __id: id})};
            });
        return {docs, size: docs.length};
      },
    };
  }
  return {
    FieldValue,
    store,
    collection(name) {
      return col(name);
    },
  };
}

test("一般安親成功後同步會員與寵物", async () => {
  const db = createFakeDb({
    "user_profiles/u1": {
      name: "小明", email: "a@b.c", phone: "0911", address: "台北",
      avatarUrl: "https://img/new.jpg", avatarStoragePath: "pets/u1/avatar_1.jpg",
    },
    "user_profiles/u1/pets/p1": {name: "咪", breed: "混", type: "cat", species: "cat"},
    "bookings/b1": {shopId: "shop-a", userId: "u1"},
  });
  const result = await syncShopMemberCache({
    firestore: db,
    FieldValue: db.FieldValue,
    shopId: "shop-a",
    userId: "u1",
    customer: {name: "小明", phone: "0911"},
    policy: {policyVersion: 2, policyTitle: "安親須知"},
  });
  assert.equal(result.bookingCount, 1);
  assert.equal(result.petCount, 1);
  const member = db.store["shops/shop-a/members/u1"];
  assert.equal(member.name, "小明");
  assert.equal(member.phone, "0911");
  assert.equal(member.bookingCount, 1);
  assert.equal(member.avatarUrl, "https://img/new.jpg");
  assert.equal(member.avatarStoragePath, "pets/u1/avatar_1.jpg");
  assert.ok(db.store["shops/shop-a/members/u1/pets/p1"]);
});

test("同步頭像會覆蓋舊網址且不寫入店家欄位", async () => {
  const db = createFakeDb({
    "user_profiles/u1": {
      name: "小明",
      avatarUrl: "https://img/latest.jpg",
      avatarStoragePath: "pets/u1/avatar_9.jpg",
    },
    "shops/shop-a/members/u1": {
      name: "舊名",
      avatarUrl: "https://img/old.jpg",
      tags: ["vip"],
      blacklisted: true,
      points: 80,
    },
    "bookings/b1": {shopId: "shop-a", userId: "u1"},
  });
  await syncShopMemberCache({
    firestore: db,
    FieldValue: db.FieldValue,
    shopId: "shop-a",
    userId: "u1",
    customer: {},
    policy: {},
  });
  const member = db.store["shops/shop-a/members/u1"];
  assert.equal(member.avatarUrl, "https://img/latest.jpg");
  assert.equal(member.tags[0], "vip");
  assert.equal(member.blacklisted, true);
  assert.equal(member.points, 80);
});

test("更新既有會員但保留店家欄位", async () => {
  const db = createFakeDb({
    "user_profiles/u1": {name: "新名", phone: "0900"},
    "shops/shop-a/members/u1": {
      name: "舊名",
      tags: ["vip"],
      blacklisted: true,
      blacklistReason: "咬人",
      isBlocked: true,
      staffNote: "內部",
      memberLevel: "gold",
      points: 88,
      adminNote1: "店家備註",
    },
    "bookings/b1": {shopId: "shop-a", userId: "u1"},
  });
  await syncShopMemberCache({
    firestore: db,
    FieldValue: db.FieldValue,
    shopId: "shop-a",
    userId: "u1",
    customer: {name: "新名", phone: "0900"},
    policy: {},
  });
  const member = db.store["shops/shop-a/members/u1"];
  assert.equal(member.name, "新名");
  assert.deepEqual(member.tags, ["vip"]);
  assert.equal(member.blacklisted, true);
  assert.equal(member.staffNote, "內部");
  assert.equal(member.points, 88);
  assert.ok(SHOP_OWNED_FIELDS.includes("tags"));
});

test("petCount 是同步給該店的寵物數不是本次隻數", async () => {
  const db = createFakeDb({
    "user_profiles/u1": {name: "A"},
    "user_profiles/u1/pets/p1": {name: "1"},
    "user_profiles/u1/pets/p2": {name: "2"},
    "bookings/b1": {shopId: "shop-a", userId: "u1"},
  });
  const result = await syncShopMemberCache({
    firestore: db,
    FieldValue: db.FieldValue,
    shopId: "shop-a",
    userId: "u1",
    customer: {},
    policy: {},
    selectedPetIds: ["p1"],
  });
  assert.equal(result.petCount, 2);
});

test("bookingCount 依實際訂單數，重送不會再加一", async () => {
  const db = createFakeDb({
    "user_profiles/u1": {name: "A"},
    "bookings/b1": {shopId: "shop-a", userId: "u1"},
    "bookings/b2": {shopId: "shop-a", userId: "u1"},
    "bookings/other": {shopId: "shop-b", userId: "u1"},
  });
  const first = await syncShopMemberCache({
    firestore: db,
    FieldValue: db.FieldValue,
    shopId: "shop-a",
    userId: "u1",
    customer: {},
    policy: {},
  });
  const second = await syncShopMemberCache({
    firestore: db,
    FieldValue: db.FieldValue,
    shopId: "shop-a",
    userId: "u1",
    customer: {},
    policy: {},
  });
  assert.equal(first.bookingCount, 2);
  assert.equal(second.bookingCount, 2);
});

test("只附上目前 shopId 的寵物自訂表單答案", () => {
  const payload = memberPetPayload(
      {
        name: "咪",
        customFormAnswersByShop: {
          "shop-a": {formId: "a"},
          "shop-b": {formId: "b"},
        },
      },
      "shop-a",
      {shopId: "shop-a", formId: "pet_profile", answers: [{questionId: "q1"}]},
  );
  assert.equal(payload.customFormAnswersByShop, undefined);
  assert.equal(payload.shopFormAnswers.shopId, "shop-a");
  assert.equal(payload.shopFormAnswers.formId, "pet_profile");
  const other = memberPetPayload(
      {name: "咪"},
      "shop-a",
      {shopId: "shop-b", formId: "other", answers: []},
  );
  assert.equal(other.shopFormAnswers, undefined);
});
