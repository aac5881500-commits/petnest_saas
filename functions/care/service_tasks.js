/* eslint-disable require-jsdoc, max-len */
const first = (...values) => values.find((value) => value != null);
const maps = (v) => Array.isArray(v) ? v.filter((x) => x && typeof x === "object") : [];
function instant(v) {
  return v && v.toDate ? v.toDate() : new Date(v);
}
function dayOf(v) {
  if (typeof v === "string" && /^\d{4}-\d{2}-\d{2}$/.test(v)) return v;
  if (!v) return "";
  const time = instant(v).getTime();
  return Number.isFinite(time) ? new Date(time + 8 * 3600000).toISOString().slice(0, 10) : "";
}
function serviceTasks(b) {
  const tasks = new Map();
  const names = Object.fromEntries(maps(b.pets).map((p) => [String(p.petId || p.id || ""), p.name || p.petName || ""]));
  for (const a of maps(b.addons)) {
    if (!["daily_timed", "dailyTimedServices"].includes(a.type)) continue;
    const title = String(first(a.name, a.label, "預約服務")); const service = String(first(a.serviceId, a.id, title));
    const add = (petId, day, slotId, label, pet) => {
      const match = String(label).match(/(?<!\d)([01]?\d|2[0-3]):([0-5]\d)(?!\d)/);
      if (!/^\d{4}-\d{2}-\d{2}$/.test(day) || !match) return;
      const date = new Date(`${day}T${match[1].padStart(2, "0")}:${match[2]}:00+08:00`);
      if (!Number.isFinite(date.getTime())) return;
      const id = Buffer.from(JSON.stringify([service, petId ? String(petId) : `legacy:${pet || ""}`, day, String(slotId)])).toString("base64url");
      const scheduledAt = date.toISOString();
      const raw = (b.careServiceRecords || {})[id];
      const record = raw && Date.parse(raw.scheduledAt) === date.getTime() ? raw : null;
      tasks.set(id, {id, petId: String(petId), pet: pet || "寵物", title, scheduledAt, slot: label, record});
    };
    for (const s of maps(a.selections)) {
      for (const d of maps(s.dates)) {
        const ids = Array.isArray(d.slotIds) ? d.slotIds : [];
        const labels = Array.isArray(d.slotLabels) && d.slotLabels.length ? d.slotLabels : ids;
        const matching = Object.entries(names).filter(([, name]) => name === s.petName);
        const petId = s.petId || (matching.length === 1 ? matching[0][0] : "");
        labels.forEach((label, i) => add(String(petId), d.date || "", first(ids[i], label), label, first(s.petName, names[petId])));
      }
    }
    for (const petId of (Array.isArray(a.selectedPetIds) ? a.selectedPetIds : [])) {
      for (const slot of maps(a.selectedTimeSlots)) {
        let day = dayOf(b.scheduledStartAt || b.startAt);
        const label = String(slot.label || ""); const clock = label.match(/^(\d{1,2}):(\d{2})$/);
        const start = instant(b.scheduledStartAt || b.startAt);
        if (clock && Number.isFinite(start.getTime())) {
          const candidate = new Date(`${day}T${clock[1].padStart(2, "0")}:${clock[2]}:00+08:00`);
          if (candidate < start) day = dayOf(new Date(candidate.getTime() + 86400000));
        }
        add(String(petId), day, first(slot.id, label), label, names[petId]);
      }
    }
  }
  return [...tasks.values()].sort((a, b) => Date.parse(a.scheduledAt) - Date.parse(b.scheduledAt));
}
const canRecord = (b) => b && b.status === "checked_in" && !b.settlementConfirmed && !b.settlementLocked && !b.settledAt;
const fitsStayDates = (b, start, end) => serviceTasks(b).every((t) => {
  const day = dayOf(t.scheduledAt); return day >= dayOf(start) && day <= dayOf(end);
});
module.exports = {serviceTasks, canRecord, fitsStayDates};
