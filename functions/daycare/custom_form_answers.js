/* eslint-disable require-jsdoc */
// 檔案名稱：functions/daycare/custom_form_answers.js
// 功能說明：安親建單時由後端重讀 booking_submit 表單並核對答案，不信任前端題目設定。

function asString(value) {
  return value == null ? "" : String(value).trim();
}

function asBool(value) {
  if (typeof value === "boolean") {
    return value;
  }
  if (value === 1 || value === "1" || value === "true") {
    return true;
  }
  if (value === 0 || value === "0" || value === "false") {
    return false;
  }
  return null;
}

function asNumber(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value.trim());
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return null;
}

function optionLabel(question, id) {
  const options = Array.isArray(question.options) ? question.options : [];
  for (let i = 0; i < options.length; i++) {
    if (asString(options[i].id) === id) {
      return asString(options[i].label) || id;
    }
  }
  return id;
}

function displayValue(question, value) {
  const type = asString(question.type) || "shortText";
  if (type === "yesNo") {
    if (typeof value !== "boolean") {
      return "";
    }
    return value ? "是" : "否";
  }
  if (type === "multipleChoice") {
    if (!Array.isArray(value)) {
      return "";
    }
    return value.map((id) => optionLabel(question, asString(id))).join("、");
  }
  if (type === "singleChoice" || type === "dropdown") {
    return optionLabel(question, asString(value));
  }
  if (type === "yearMonth") {
    const match = asString(value).match(/^(\d{4})-(\d{2})$/);
    if (match) {
      return `${match[1]}年${Number(match[2])}月`;
    }
  }
  if (value == null) {
    return "";
  }
  return String(value);
}

function hasRequiredAnswer(question, value) {
  const type = asString(question.type) || "shortText";
  if (type === "multipleChoice") {
    return Array.isArray(value) && value.length > 0;
  }
  if (type === "yesNo") {
    return typeof value === "boolean";
  }
  if (type === "number") {
    return asNumber(value) != null;
  }
  return asString(value).length > 0;
}

function normalizeValue(question, raw) {
  const type = asString(question.type) || "shortText";
  const incoming = raw && Object.prototype.hasOwnProperty.call(raw, "value") ?
    raw.value : raw;
  if (type === "multipleChoice") {
    if (!Array.isArray(incoming)) {
      return {error: true};
    }
    return incoming.map((item) => asString(item)).filter(Boolean);
  }
  if (type === "yesNo") {
    const flag = asBool(incoming);
    if (incoming != null && incoming !== "" && typeof flag !== "boolean") {
      return {error: true};
    }
    return flag;
  }
  if (type === "number") {
    if (incoming == null || incoming === "") {
      return null;
    }
    const parsed = asNumber(incoming);
    if (parsed == null) {
      return {error: true};
    }
    return parsed;
  }
  return asString(incoming);
}

function collectEnabledQuestions(form) {
  const sections = Array.isArray(form.sections) ? form.sections : [];
  const result = [];
  sections.forEach((section) => {
    if (section && section.enabled === false) {
      return;
    }
    const questions = Array.isArray(section.questions) ?
      section.questions : [];
    questions.forEach((question) => {
      if (!question || question.enabled === false) {
        return;
      }
      const id = asString(question.id);
      if (!id) {
        return;
      }
      result.push({
        sectionId: asString(section.id),
        sectionTitle: asString(section.title),
        question: question,
        questionId: id,
      });
    });
  });
  return result;
}

function validateAndNormalizeAnswers({
  form,
  payloadAnswers,
  formType,
  errorMessage,
}) {
  if (!form || form.enabled !== true) {
    return {snapshot: null, error: null};
  }
  const enabled = collectEnabledQuestions(form);
  if (enabled.length === 0) {
    return {snapshot: null, error: null};
  }

  const payload = payloadAnswers && typeof payloadAnswers === "object" ?
    payloadAnswers : {};
  const incomingList = Array.isArray(payload.answers) ? payload.answers : [];
  const byId = {};
  incomingList.forEach((item) => {
    if (!item || typeof item !== "object") {
      return;
    }
    const id = asString(item.questionId);
    if (id) {
      byId[id] = item;
    }
  });

  const answers = [];
  for (let i = 0; i < enabled.length; i++) {
    const entry = enabled[i];
    const question = entry.question;
    const raw = byId[entry.questionId];
    const required = question.required === true;
    const normalized = raw ? normalizeValue(question, raw) : (
      required ? undefined : null
    );
    if (normalized && normalized.error) {
      return {snapshot: null, error: errorMessage};
    }
    if (required && !hasRequiredAnswer(question, normalized)) {
      return {snapshot: null, error: errorMessage};
    }
    if (!raw && !required) {
      continue;
    }
    answers.push({
      sectionId: entry.sectionId,
      sectionTitle: entry.sectionTitle,
      questionId: entry.questionId,
      questionLabel: asString(question.label),
      questionType: asString(question.type) || "shortText",
      required,
      value: normalized == null ? "" : normalized,
      displayValue: displayValue(question, normalized),
    });
  }

  return {
    error: null,
    snapshot: {
      formId: asString(form.id) || formType,
      formType,
      formVersion: Number(form.version || 0),
      formTitle: asString(form.title) || errorMessage,
      answers,
    },
  };
}

function validateAndNormalizeBookingSubmitAnswers({
  form,
  payloadAnswers,
  source,
}) {
  if (source === "admin") {
    return {snapshot: null, error: null};
  }
  return validateAndNormalizeAnswers({
    form,
    payloadAnswers,
    formType: "booking_submit",
    errorMessage: "請完成送出訂單表單",
  });
}

function validateAndNormalizeAdminCreateAnswers({
  form,
  payloadAnswers,
}) {
  return validateAndNormalizeAnswers({
    form,
    payloadAnswers,
    formType: "admin_create",
    errorMessage: "請完成手動訂單表單必填題",
  });
}

function stampSubmittedAt(value, FieldValue) {
  if (!value || typeof value !== "object") {
    return value;
  }
  if (Array.isArray(value)) {
    return value.map((item) => stampSubmittedAt(item, FieldValue));
  }
  const out = {...value};
  if (Object.prototype.hasOwnProperty.call(out, "submittedAt")) {
    out.submittedAt = FieldValue.serverTimestamp();
  }
  const keys = Object.keys(out);
  for (let i = 0; i < keys.length; i++) {
    const key = keys[i];
    if (key === "submittedAt") {
      continue;
    }
    if (out[key] && typeof out[key] === "object") {
      out[key] = stampSubmittedAt(out[key], FieldValue);
    }
  }
  return out;
}

module.exports = {
  validateAndNormalizeBookingSubmitAnswers,
  validateAndNormalizeAdminCreateAnswers,
  stampSubmittedAt,
};
