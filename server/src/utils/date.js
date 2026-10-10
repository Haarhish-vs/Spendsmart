/**
 * Timezone-aware date utilities (defaults to Asia/Kolkata)
 */

const DEFAULT_TIMEZONE = 'Asia/Kolkata';

/**
 * Extract local year, month (1-12), day (1-31), day of week (0=Sun, 1=Mon, ..., 6=Sat) in timezone
 */
function getLocalDateParts(date = new Date(), timezone = DEFAULT_TIMEZONE) {
  const targetDate = typeof date === 'string' ? new Date(date) : date;
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
    weekday: 'short',
    hour: 'numeric',
    minute: 'numeric',
    second: 'numeric',
    hour12: false,
  });

  const parts = formatter.formatToParts(targetDate);
  const map = {};
  for (const p of parts) map[p.type] = p.value;

  const weekdayMap = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 };

  return {
    year: parseInt(map.year, 10),
    month: parseInt(map.month, 10),
    day: parseInt(map.day, 10),
    dayOfWeek: weekdayMap[map.weekday] ?? 0,
  };
}

/**
 * Format local date components into ISO string in timezone offset (+05:30)
 */
function toTzIso(year, month, day, hour = 0, minute = 0, second = 0, ms = 0) {
  const pad = (n, len = 2) => String(n).padStart(len, '0');
  const dateStr = `${pad(year, 4)}-${pad(month)}-${pad(day)}T${pad(hour)}:${pad(minute)}:${pad(second)}.${pad(ms, 3)}+05:30`;
  return new Date(dateStr).toISOString();
}

/**
 * Daily boundaries: 00:00:00 to 23:59:59.999 IST
 */
function getDailyBoundaries(date = new Date(), timezone = DEFAULT_TIMEZONE) {
  const { year, month, day } = getLocalDateParts(date, timezone);
  const start = toTzIso(year, month, day, 0, 0, 0, 0);
  const end = toTzIso(year, month, day, 23, 59, 59, 999);
  return { start, end, periodKey: `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}` };
}

/**
 * Weekly boundaries (Monday to Sunday) in IST
 */
function getWeeklyBoundaries(date = new Date(), timezone = DEFAULT_TIMEZONE) {
  const { year, month, day, dayOfWeek } = getLocalDateParts(date, timezone);
  // Mon = 0, Tue = 1, ..., Sun = 6
  const daysSinceMonday = (dayOfWeek + 6) % 7;

  // Compute Monday in UTC milliseconds
  const currentLocalMs = Date.UTC(year, month - 1, day);
  const mondayMs = currentLocalMs - daysSinceMonday * 86400000;
  const sundayMs = mondayMs + 6 * 86400000;

  const monDate = new Date(mondayMs);
  const sunDate = new Date(sundayMs);

  const start = toTzIso(monDate.getUTCFullYear(), monDate.getUTCMonth() + 1, monDate.getUTCDate(), 0, 0, 0, 0);
  const end = toTzIso(sunDate.getUTCFullYear(), sunDate.getUTCMonth() + 1, sunDate.getUTCDate(), 23, 59, 59, 999);

  const periodKey = `${monDate.getUTCFullYear()}-W${String(monDate.getUTCMonth() + 1).padStart(2, '0')}-${String(monDate.getUTCDate()).padStart(2, '0')}`;
  return { start, end, periodKey };
}

/**
 * Monthly boundaries (1st to last day) in IST
 */
function getMonthlyBoundaries(date = new Date(), timezone = DEFAULT_TIMEZONE) {
  const { year, month } = getLocalDateParts(date, timezone);
  const lastDay = new Date(year, month, 0).getDate(); // 28, 29, 30, or 31

  const start = toTzIso(year, month, 1, 0, 0, 0, 0);
  const end = toTzIso(year, month, lastDay, 23, 59, 59, 999);
  const periodKey = `${year}-${String(month).padStart(2, '0')}`;

  return { start, end, periodKey };
}

function getBoundariesForPeriod(period, date = new Date(), timezone = DEFAULT_TIMEZONE) {
  const p = (period || 'monthly').toLowerCase();
  if (p === 'daily') return getDailyBoundaries(date, timezone);
  if (p === 'weekly') return getWeeklyBoundaries(date, timezone);
  return getMonthlyBoundaries(date, timezone);
}

module.exports = {
  DEFAULT_TIMEZONE,
  getLocalDateParts,
  getDailyBoundaries,
  getWeeklyBoundaries,
  getMonthlyBoundaries,
  getBoundariesForPeriod,
};
