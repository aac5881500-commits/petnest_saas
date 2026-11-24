/* eslint-disable require-jsdoc, max-len */
// Pure medication validation, Taiwan scheduling and billing. No medical defaults.
const TYPES = {oral: "口服藥", eye: "點眼藥", ear: "點耳藥", topical: "擦藥", spray: "噴藥", supplement: "保健品"};
const MODES = ["free", "visit", "day", "night", "quote"];
const RESULTS = ["done", "partial", "failed", "skipped", "mixed"];
function fail(message) {
  throw new Error(message);
}
function str(v, max = 1000) {
  return String(v == null ? "" : v).trim().slice(0, max);
}
function integer(v, min, max, label) {
  const n = Number(v);
  if (!Number.isInteger(n) || n < min || n > max) fail(label);
  return n;
}
function settings(raw = {}) {
  const mode = str(raw.mode || "quote");
  if (!MODES.includes(mode)) fail("請選擇收費方式");
  const types = [...new Set(Array.isArray(raw.types) ? raw.types : [])].filter((x) => TYPES[x]);
  if (raw.enabled === true && !types.length) fail("請選擇接受的服務類型");
  const windows = (Array.isArray(raw.windows) ? raw.windows : []).map((w) => {
    if (!/^\d{2}:\d{2}$/.test(w.start) || !/^\d{2}:\d{2}$/.test(w.end) ||
      w.start >= w.end || !validTime(w.start) || !validTime(w.end)) fail("照護時段格式不正確");
    return {start: w.start, end: w.end};
  });
  if (raw.enabled === true && (!windows.length || windows.length > 4)) fail("請設定一至四個照護時段");
  return {enabled: raw.enabled === true, types, mode,
    price: mode === "free" ? 0 : integer(raw.price || 0, 0, 100000, "金額不正確"),
    paymentTiming: ["visit", "day", "night"].includes(mode) && raw.paymentTiming === "advance" ?
      "advance" : "checkout",
    mixFree: raw.mixFree === true, successOnly: raw.successOnly === true,
    splitTypes: raw.splitTypes === true,
    includedTimes: integer(raw.includedTimes || 0, 0, 24, "每日包含次數不正確"),
    includedPills: integer(raw.includedPills || 0, 0, 100, "包含顆數不正確"),
    dayRule: raw.dayRule === "stay_days" ? "stay_days" : raw.dayRule === "all_dates" ? "all_dates" : "service_dates",
    windows, note: str(raw.note), version: 1};
}
function validTime(v) {
  return /^([01]\d|2[0-3]):[0-5]\d$/.test(v);
}
function date(v) {
  if (v && typeof v.toDate === "function") return v.toDate();
  const d = new Date(v);
  if (!Number.isFinite(d.getTime())) fail("日期格式不正確");
  return d;
}
function key(v) {
  return new Date(date(v).getTime() + 8 * 3600000).toISOString().slice(0, 10);
}
function time(v) {
  return new Date(date(v).getTime() + 8 * 3600000).toISOString().slice(11, 16);
}
function validateRequest(raw, booking, setting, uid, {allowMissingDetails = false} = {}) {
  if (!raw || !Array.isArray(raw.medicines) || !raw.medicines.length) return null;
  if (!setting.enabled) fail("本店尚未開放用藥協助，請先聯繫店家");
  if (raw.medicines.length > 20) fail("每張訂單最多二十筆藥品");
  const pets = new Set((booking.petIds || []).map(String));
  const start = date(raw.careStart); const end = date(raw.careEnd);
  if (end <= start || end - start > 180 * 86400000 || key(start) < key(booking.startDate) || key(end) > key(booking.endDate)) fail("用藥交接期間須在住宿日期內，且最多一百八十日");
  const medicines = raw.medicines.map((m, i) => {
    const petId = str(m.petId, 128); const type = str(m.type);
    if (!pets.has(petId) || !setting.types.includes(type)) fail("用藥貓咪或服務類型不符合本店設定");
    const name = str(m.name, 100); const dose = str(m.dose, 100); const instruction = str(m.instruction);
    if (!allowMissingDetails && (!name || !dose || !instruction)) fail("請填寫藥名、用量與使用指示");
    const schedule = ["fixed", "meal", "interval", "custom", "dated"].includes(m.schedule) ? m.schedule : "fixed";
    const times = [...new Set(Array.isArray(m.times) ? m.times : [])].sort();
    if (["fixed", "meal"].includes(schedule) && (!times.length || times.length > 12 || times.some((x) => !validTime(x)))) fail("請填寫正確的每日時間");
    const from = date(m.from || raw.careStart); const until = date(m.until || raw.careEnd);
    if (from < start || until > end || until < from) fail("藥品使用期間超出交接期間");
    let dates;
    if (schedule === "dated") {
      if (!Array.isArray(m.dates) || !m.dates.length || m.dates.length > 181) {
        fail("請至少排入一個用藥日期");
      }
      const seen = new Set();
      dates = m.dates.map((day) => {
        const dayKey = day?.date;
        if (typeof dayKey !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(dayKey) ||
            dayKey < key(from) || dayKey > key(until) || seen.has(dayKey)) {
          fail("用藥日期須在交接期間內，且不可重複");
        }
        seen.add(dayKey);
        if (!Array.isArray(day.times) || !day.times.length || day.times.length > 12 ||
            day.times.some((t) => typeof t !== "string" || !validTime(t))) {
          fail("請填寫正確的用藥時間");
        }
        const uniqueTimes = [...new Set(day.times)].sort();
        for (const t of uniqueTimes) {
          const at = new Date(dayKey + "T" + t + ":00+08:00");
          if (!Number.isFinite(at.getTime()) || key(at) !== dayKey || at < from || at > until) {
            fail("用藥時間須在交接期間內");
          }
        }
        return {date: dayKey, times: uniqueTimes};
      }).sort((a, b) => a.date.localeCompare(b.date));
    }
    const photoPath = str(m.photoPath, 500);
    if (photoPath && (!photoPath.startsWith(`medication_uploads/${uid}/${booking.shopId}/`) || photoPath.includes("..") || photoPath.split("/").length !== 4)) fail("藥袋照片來源不正確");
    return {id: `m${i}`, petId, type, name, dose, instruction,
      reason: str(m.reason, 300), mix: m.mix === true,
      pills: integer(m.pills || 0, 0, 100, "顆數不正確"),
      schedule, times: ["fixed", "meal"].includes(schedule) ? times : [],
      ...(dates ? {dates} : {}),
      intervalHours: schedule === "interval" ? integer(m.intervalHours, 1, 168, "請填寫一至一百六十八小時間隔") : 0,
      custom: str(m.custom), photoPath, from: from.toISOString(), until: until.toISOString()};
  });
  return {careStart: start.toISOString(), careEnd: end.toISOString(), medicines};
}
function plan(request, setting) {
  const groups = new Map();
  const issues = [];
  function add(m, at) {
    const t = time(at);
    const outside = !setting.windows.some((w) => t >= w.start && t <= w.end);
    const group = `${m.petId}|${at.toISOString()}|${setting.splitTypes ? m.type : "all"}`;
    if (!groups.has(group)) groups.set(group, {id: `t${groups.size}`, petId: m.petId, scheduledAt: at.toISOString(), medicineIds: [], outside, result: "pending"});
    groups.get(group).medicineIds.push(m.id);
    if (groups.size > 500) fail("用藥待辦超過五百筆，請縮短期間或聯繫店家分段安排");
  }
  for (const m of request.medicines) {
    const start = date(m.from); const end = date(m.until);
    if (m.schedule === "custom") {
      issues.push(`${m.name}：其他安排須先改成可執行時間`); continue;
    }
    if (m.schedule === "dated") {
      for (const day of m.dates) {
        for (const t of day.times) add(m, new Date(day.date + "T" + t + ":00+08:00"));
      }
    } else if (m.schedule === "interval") {
      for (let at = start; at <= end; at = new Date(at.getTime() + m.intervalHours * 3600000)) add(m, at);
    } else {
      for (let day = new Date(`${key(start)}T00:00:00+08:00`); day <= end; day = new Date(day.getTime() + 86400000)) {
        for (const t of m.times) {
          const at = new Date(`${key(day)}T${t}:00+08:00`);
          if (at >= start && at <= end) add(m, at);
        }
      }
    }
  }
  const tasks = [...groups.values()].sort((a, b) => a.scheduledAt.localeCompare(b.scheduledAt));
  if (!tasks.length && !issues.length) fail("期間內沒有符合時間的用藥安排");
  if (tasks.some((t) => t.outside)) issues.push("部分時間超出店家照護時段，須店家明確確認");
  return {tasks, issues};
}
function quote(request, setting, tasks, booking, final = false) {
  const meds = new Map(request.medicines.map((m) => [m.id, m]));
  let manual = setting.mode === "quote" || request.medicines.some((m) => m.schedule === "custom");
  const included = tasks.filter((t) => {
    if (final && !t.finished && ["pending", "partial", "mixed"].includes(t.result)) fail("尚有待辦或部分完成紀錄，請先確認結果");
    return t.medicineIds.some((id) => {
      if (setting.mixFree && meds.get(id).mix) return false;
      const result = t.medicineResults ? t.medicineResults[id] : t.result;
      return !final || (result !== "skipped" && (!setting.successOnly || result === "done"));
    });
  });
  const days = new Set();
  const dailyCount = new Map();
  for (const t of included) {
    const type = setting.splitTypes ? meds.get(t.medicineIds[0]).type : "all";
    const daily = `${t.petId}|${key(t.scheduledAt)}|${type}`;
    days.add(daily);
    dailyCount.set(daily, (dailyCount.get(daily) || 0) + 1);
    if (setting.includedPills && t.medicineIds.reduce((sum, id) => sum + meds.get(id).pills, 0) > setting.includedPills) manual = true;
  }
  if (setting.includedTimes && [...dailyCount.values()].some((n) => n > setting.includedTimes)) manual = true;
  let units = included.length;
  if (setting.mode === "day") {
    units = days.size;
    if (setting.dayRule === "all_dates" && included.length) {
      const petTypes = new Set(included.map((t) => `${t.petId}|${setting.splitTypes ? meds.get(t.medicineIds[0]).type : "all"}`));
      units = petTypes.size * (Math.round((new Date(`${key(request.careEnd)}T00:00:00+08:00`) - new Date(`${key(request.careStart)}T00:00:00+08:00`)) / 86400000) + 1);
    }
  }
  if (setting.mode === "day" && setting.dayRule === "stay_days") {
    const first = key(booking.startDate || request.careStart);
    const checkout = key(booking.endDate || request.careEnd);
    const last = checkout > first ? key(new Date(`${checkout}T00:00:00+08:00`).getTime() - 86400000) : first;
    const stayDays = new Set(included.map((task) => {
      const dateKey = key(task.scheduledAt);
      const stayKey = dateKey > last ? last : dateKey < first ? first : dateKey;
      return `${task.petId}|${stayKey}|${setting.splitTypes ? meds.get(task.medicineIds[0]).type : "all"}`;
    }));
    units = stayDays.size;
  }
  if (setting.mode === "night") {
    const petTypes = new Set(included.map((t) => `${t.petId}|${setting.splitTypes ? meds.get(t.medicineIds[0]).type : "all"}`));
    units = petTypes.size * Math.max(1, Math.round((new Date(`${key(request.careEnd)}T00:00:00+08:00`) - new Date(`${key(request.careStart)}T00:00:00+08:00`)) / 86400000));
  }
  if (setting.mode === "free") manual = false;
  const billingBuckets = new Map();
  const addBilling = (day, token) => {
    if (!billingBuckets.has(day)) billingBuckets.set(day, new Set());
    billingBuckets.get(day).add(token);
  };
  for (const t of included) {
    const token = `${t.petId}|${setting.splitTypes ? meds.get(t.medicineIds[0]).type : "all"}`;
    let day = key(t.scheduledAt);
    if (setting.mode === "day" && setting.dayRule === "stay_days") {
      const first = key(booking.startDate || request.careStart);
      const end = key(booking.endDate || request.careEnd);
      const last = end > first ? key(new Date(`${end}T00:00:00+08:00`).getTime() - 86400000) : first;
      day = day > last ? last : day < first ? first : day;
    }
    if (setting.mode === "night" || (setting.mode === "day" && setting.dayRule === "all_dates")) {
      const first = new Date(`${key(request.careStart)}T00:00:00+08:00`);
      const count = setting.mode === "night" ? Math.max(1, Math.round((new Date(`${key(request.careEnd)}T00:00:00+08:00`) - first) / 86400000)) : Math.round((new Date(`${key(request.careEnd)}T00:00:00+08:00`) - first) / 86400000) + 1;
      for (let n = 0; n < count; n++) addBilling(key(first.getTime() + n * 86400000), token);
    } else addBilling(day, setting.mode === "day" ? token : t.id);
  }
  const billingDays = [...billingBuckets.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([day, tokens]) => ({date: day, count: tokens.size}));
  return {units, amount: setting.mode === "free" ? 0 : manual ? null : units * setting.price, manual, plannedCount: tasks.length, billingDays, billingMode: setting.mode, dayRule: setting.dayRule};
}
function validatePreferences(entries, booking, setting) {
  if (!Array.isArray(entries)) fail("用藥時段資料不正確");
  if (!entries.length) return null;
  if (!setting.enabled) fail("本店尚未開放用藥協助，請先聯繫店家");
  const pets = new Set((booking.petIds || []).map(String));
  if (entries.some((entry) => entry && Object.hasOwn(entry, "dates")) &&
      entries.length > 20) fail("每張訂單最多二十筆用藥需求");
  const scheduleByPet = new Map();
  const preferences = entries.map((entry) => {
    const petId = str(entry?.petId, 128);
    const dated = entry && Object.hasOwn(entry, "dates");
    if (!pets.has(petId) || (scheduleByPet.has(petId) &&
      (!dated || !scheduleByPet.get(petId)))) fail("用藥貓咪不符合本筆預約");
    scheduleByPet.set(petId, dated);
    const validateTimes = (input) => {
      if (!Array.isArray(input) || !input.length || input.length > 12) {
        fail("請為每隻需要用藥的貓咪選擇一至十二個時段");
      }
      const times = [...new Set(input)];
      if (times.some((t) => typeof t !== "string" || !validTime(t) ||
        !/:(00|30)$/.test(t) ||
        !setting.windows.some((w) => t >= w.start && t <= w.end))) {
        fail("用藥時段已變更，請重新選擇店家開放的時段");
      }
      return times.sort();
    };
    let schedule;
    if (dated) {
      if (!Array.isArray(entry.dates) || !entry.dates.length || entry.dates.length > 181) {
        fail("請選擇需要用藥的住宿日期");
      }
      const first = key(booking.startDate);
      const last = key(booking.endDate);
      const seen = new Set();
      schedule = {dates: entry.dates.map((day) => {
        const selectedDate = day?.date;
        if (typeof selectedDate !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(selectedDate) ||
            selectedDate < first || selectedDate > last || seen.has(selectedDate) ||
            key(selectedDate + "T00:00:00+08:00") !== selectedDate) {
          fail("用藥日期須在住宿期間內，且不可重複");
        }
        seen.add(selectedDate);
        return {date: selectedDate, times: validateTimes(day.times)};
      }).sort((a, b) => a.date.localeCompare(b.date))};
      if (!Array.isArray(entry.types) || entry.types.length !== 1) fail("請選擇一種用藥類型");
    } else {
      schedule = {times: validateTimes(entry.times)};
    }
    // Older pending requests may only contain times.
    if (!Object.hasOwn(entry, "types")) return {petId, ...schedule};
    if (!Array.isArray(entry.types) || !entry.types.length ||
      entry.types.length > setting.types.length ||
      entry.types.some((type) => !setting.types.includes(type))) {
      fail("請選擇店家接受的用藥類型");
    }
    const handover = {};
    if (dated) {
      for (const [field, limit] of [["name", 100], ["dose", 100], ["note", 500]]) {
        const value = typeof entry[field] === "string" ? str(entry[field], limit) : "";
        if (value) handover[field] = value;
      }
    }
    return {petId, ...schedule, types: [...new Set(entry.types)], ...handover};
  });
  const datedKeys = preferences.flatMap((p) => (p.dates || []).map((d) => d.date)).sort();
  return {preferences, medicines: [],
    careStart: datedKeys.length ? datedKeys[0] + "T00:00:00+08:00" :
      key(booking.startDate) + "T15:00:00+08:00",
    careEnd: datedKeys.length ? datedKeys.at(-1) + "T23:59:00+08:00" :
      key(booking.endDate) + "T12:00:00+08:00"};
}
function estimatePreferences(request, booking, setting) {
  const start = Date.parse(key(booking.startDate));
  const end = Date.parse(key(booking.endDate));
  const days = Math.max(0, Math.round((end - start) / 86400000));
  const byVisit = setting.mode === "visit";
  const datedVisits = new Map();
  let units = 0;
  let needsQuote = setting.mode === "quote";
  for (const entry of request.preferences) {
    if (!entry.types?.length) needsQuote = true;
    const types = setting.splitTypes && entry.types?.length ? entry.types : ["all"];
    if (!entry.dates) {
      units += days * types.length * (byVisit ? entry.times.length : 1);
      if (setting.includedTimes > 0 && entry.times.length > setting.includedTimes) needsQuote = true;
      continue;
    }
    for (const day of entry.dates) {
      const group = JSON.stringify([entry.petId, day.date, types[0]]);
      if (!datedVisits.has(group)) datedVisits.set(group, new Set());
      const times = datedVisits.get(group);
      day.times.forEach((time) => times.add(time));
    }
  }
  for (const times of datedVisits.values()) {
    units += byVisit ? times.size : 1;
    if (setting.includedTimes > 0 && times.size > setting.includedTimes) needsQuote = true;
  }
  const manual = setting.mode !== "free" && needsQuote;
  return {units, amount: setting.mode === "free" ? 0 : manual ? null : units * setting.price,
    manual, plannedCount: 0};
}
function initial(raw, booking, rawSetting, uid) {
  const current = {...(rawSetting || {})};
  if (["day", "night"].includes(current.mode)) {
    current.mode = "day";
    current.dayRule = "stay_days";
  }
  const setting = settings(current);
  if (raw && Object.hasOwn(raw, "preferences")) {
    const request = validatePreferences(raw.preferences, booking, setting);
    if (!request) return null;
    const dated = request.preferences.some((entry) => entry.dates);
    if (dated && setting.mode === "day") setting.dayRule = "service_dates";
    const estimate = estimatePreferences(request, booking, setting);
    const advanceAmount = dated && setting.paymentTiming === "advance" ?
      estimate.amount || 0 : 0;
    return {version: 1, revision: 1, state: "pending_shop", request, setting,
      tasks: [], issues: [], estimate, advanceAmount, finalized: false, history: []};
  }
  const request = validateRequest(raw, booking, setting, uid);
  if (!request) return null;
  const built = plan(request, setting);
  return {version: 1, revision: 1, state: "pending_shop", request, setting, ...built,
    estimate: quote(request, setting, built.tasks, booking), finalized: false, history: []};
}
function checkoutGuard(booking) {
  const m = booking.medication;
  if (m && !["declined", "cancelled"].includes(m.state) && (!m.finalized || (m.tasks || []).some((t) => !t.finished && ["pending", "partial", "mixed"].includes(t.result)))) fail("請先在用藥協助完成需求確認、執行紀錄及費用結算，再辦理退房");
}
module.exports = { TYPES, RESULTS, settings, validateRequest, plan, quote, initial, checkoutGuard, key};
