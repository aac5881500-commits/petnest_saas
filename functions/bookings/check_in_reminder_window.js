"use strict";

const TAIPEI_OFFSET_MS = 8 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Return tomorrow's Taipei calendar day as absolute instants.
 * @param {Date} now Current instant.
 * @return {{start: Date, end: Date}} Inclusive start, exclusive end.
 */
function checkInReminderWindow(now = new Date()) {
  const local = new Date(now.getTime() + TAIPEI_OFFSET_MS);
  const start = Date.UTC(
      local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate() + 1,
  ) - TAIPEI_OFFSET_MS;
  return {start: new Date(start), end: new Date(start + DAY_MS)};
}

module.exports = {checkInReminderWindow};
