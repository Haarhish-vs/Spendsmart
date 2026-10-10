const { describe, it } = require('node:test');
const assert = require('node:assert');
const dateUtils = require('../../../src/utils/date');

describe('Date Utilities - Timezone & Calendar Boundaries (Asia/Kolkata)', () => {
  it('should compute daily boundaries correctly for IST', () => {
    // 2026-10-10 12:00:00 IST
    const date = new Date('2026-10-10T06:30:00.000Z');
    const { start, end, periodKey } = dateUtils.getDailyBoundaries(date);

    assert.strictEqual(periodKey, '2026-10-10');
    // Start should be 2026-10-10 00:00:00 IST -> 2026-10-09T18:30:00.000Z
    assert.strictEqual(start, '2026-10-09T18:30:00.000Z');
    // End should be 2026-10-10 23:59:59.999 IST -> 2026-10-10T18:29:59.999Z
    assert.strictEqual(end, '2026-10-10T18:29:59.999Z');
  });

  it('should compute weekly boundaries (Monday to Sunday) correctly for IST', () => {
    // 2026-10-10 is a Saturday
    const date = new Date('2026-10-10T06:30:00.000Z');
    const { start, end, periodKey } = dateUtils.getWeeklyBoundaries(date);

    // Monday of this week is 2026-10-05, Sunday is 2026-10-11
    assert.ok(periodKey.includes('2026-W10-05'));
    // Start is Monday 00:00:00 IST -> 2026-10-04T18:30:00.000Z
    assert.strictEqual(start, '2026-10-04T18:30:00.000Z');
    // End is Sunday 23:59:59.999 IST -> 2026-10-11T18:29:59.999Z
    assert.strictEqual(end, '2026-10-11T18:29:59.999Z');
  });

  it('should compute monthly boundaries correctly for IST', () => {
    const date = new Date('2026-10-10T06:30:00.000Z');
    const { start, end, periodKey } = dateUtils.getMonthlyBoundaries(date);

    assert.strictEqual(periodKey, '2026-10');
    // Start is 2026-10-01 00:00:00 IST -> 2026-09-30T18:30:00.000Z
    assert.strictEqual(start, '2026-09-30T18:30:00.000Z');
    // End is 2026-10-31 23:59:59.999 IST -> 2026-10-31T18:29:59.999Z
    assert.strictEqual(end, '2026-10-31T18:29:59.999Z');
  });

  it('should dispatch correct boundaries via getBoundariesForPeriod', () => {
    const date = new Date('2026-10-10T06:30:00.000Z');
    const daily = dateUtils.getBoundariesForPeriod('daily', date);
    const weekly = dateUtils.getBoundariesForPeriod('weekly', date);
    const monthly = dateUtils.getBoundariesForPeriod('monthly', date);

    assert.strictEqual(daily.periodKey, '2026-10-10');
    assert.ok(weekly.periodKey.startsWith('2026-W'));
    assert.strictEqual(monthly.periodKey, '2026-10');
  });
});
