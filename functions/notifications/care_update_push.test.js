const {test} = require("node:test");
const assert = require("node:assert/strict");
const {deliverCareUpdate} = require("./care_update_push");

test("care notifications push to enabled devices and open the care section", async () => {
  const sent = [];
  const db = {collection: () => ({doc: () => ({collection: (name) =>
    name === "fcm_tokens" ? {get: async () => ({docs: [
      {id: "enabled", data: () => ({})},
      {id: "disabled", data: () => ({enabled: false})},
    ]})} : {doc: () => ({get: async () => ({data: () => ({})})})},
  })})};
  const notice = {userId: "u", bookingId: "b", shopId: "s",
    title: "用藥紀錄已更新", body: "請查看結果",
    data: {type: "booking_status", section: "care", careKind: "medication", bookingId: "b"}};
  await deliverCareUpdate(notice, db, {sendEachForMulticast: async (payload) => sent.push(payload)});
  assert.deepEqual(sent[0].tokens, ["enabled"]);
  assert.equal(sent[0].data.section, "care");
  assert.equal(sent[0].data.bookingId, "b");
  await deliverCareUpdate({...notice, data: {type: "booking_message"}}, null, null);
  assert.equal(sent.length, 1);
});
