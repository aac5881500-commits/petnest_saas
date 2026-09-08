/* eslint-disable require-jsdoc */
// 檔案名稱：functions/daycare/custom_form_answers.test.js
// 功能說明：安親送出訂單表單後端驗證單元測試

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  validateAndNormalizeBookingSubmitAnswers,
} = require("./custom_form_answers");

function enabledForm() {
  return {
    id: "booking_submit",
    enabled: true,
    version: 3,
    title: "送出訂單表單",
    sections: [{
      id: "s1",
      title: "照護",
      enabled: true,
      questions: [
        {
          id: "q_req",
          label: "飲食習慣",
          type: "shortText",
          required: true,
          enabled: true,
        },
        {
          id: "q_multi",
          label: "個性",
          type: "multipleChoice",
          required: true,
          enabled: true,
          options: [
            {id: "a", label: "親人"},
            {id: "b", label: "怕生"},
          ],
        },
        {
          id: "q_yes",
          label: "是否吃藥",
          type: "yesNo",
          required: true,
          enabled: true,
        },
        {
          id: "q_num",
          label: "藥量",
          type: "number",
          required: false,
          enabled: true,
        },
      ],
    }],
  };
}

test("表單未啟用時維持舊流程", () => {
  const result = validateAndNormalizeBookingSubmitAnswers({
    form: {enabled: false, sections: []},
    payloadAnswers: {},
    source: "customer",
  });
  assert.equal(result.error, null);
  assert.equal(result.snapshot, null);
});

test("缺少必填答案時拒絕", () => {
  const result = validateAndNormalizeBookingSubmitAnswers({
    form: enabledForm(),
    payloadAnswers: {answers: []},
    source: "customer",
  });
  assert.equal(result.error, "請完成送出訂單表單");
});

test("未知 questionId 不能冒充必填", () => {
  const result = validateAndNormalizeBookingSubmitAnswers({
    form: enabledForm(),
    payloadAnswers: {
      answers: [{questionId: "unknown", value: "x"}],
    },
    source: "customer",
  });
  assert.equal(result.error, "請完成送出訂單表單");
});

test("完整答案通過並保存快照", () => {
  const result = validateAndNormalizeBookingSubmitAnswers({
    form: enabledForm(),
    payloadAnswers: {
      answers: [
        {questionId: "q_req", value: "早午晚"},
        {questionId: "q_multi", value: ["a", "b"]},
        {questionId: "q_yes", value: true},
        {questionId: "q_num", value: 1.5},
      ],
    },
    source: "customer",
  });
  assert.equal(result.error, null);
  assert.equal(result.snapshot.formVersion, 3);
  assert.equal(result.snapshot.formTitle, "送出訂單表單");
  const multi = result.snapshot.answers.find((item) => {
    return item.questionId === "q_multi";
  });
  assert.deepEqual(multi.value, ["a", "b"]);
  const yes = result.snapshot.answers.find((item) => {
    return item.questionId === "q_yes";
  });
  assert.equal(yes.value, true);
  const food = result.snapshot.answers.find((item) => {
    return item.questionId === "q_req";
  });
  assert.equal(food.questionLabel, "飲食習慣");
});

test("多選不是陣列時拒絕", () => {
  const result = validateAndNormalizeBookingSubmitAnswers({
    form: enabledForm(),
    payloadAnswers: {
      answers: [
        {questionId: "q_req", value: "早午晚"},
        {questionId: "q_multi", value: "a"},
        {questionId: "q_yes", value: true},
      ],
    },
    source: "customer",
  });
  assert.equal(result.error, "請完成送出訂單表單");
});
