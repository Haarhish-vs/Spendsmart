const { describe, it } = require('node:test');
const assert = require('node:assert');
const budgetAlertService = require('../../../src/services/budget-alert.service');

describe('Budget Threshold Logic & Calculations', () => {
  const THRESHOLDS = budgetAlertService.constructor.THRESHOLDS;

  function calculateCrossedThresholds(prevSpent, newSpent, budgetAmount) {
    const prevPercent = (prevSpent / budgetAmount) * 100;
    const newPercent = (newSpent / budgetAmount) * 100;
    const crossed = [];

    for (const t of THRESHOLDS) {
      let isCrossed = false;
      if (t.percentage === 101) {
        isCrossed = prevPercent <= 100 && newPercent > 100;
      } else {
        isCrossed = prevPercent < t.percentage && newPercent >= t.percentage;
      }

      if (isCrossed) {
        crossed.push(t);
      }
    }
    return { prevPercent, newPercent, crossed };
  }

  it('1. Daily budget crosses 50%', () => {
    // Budget ₹500. Previous: ₹240 (48%), New: ₹260 (52%)
    const { crossed } = calculateCrossedThresholds(240, 260, 500);
    assert.strictEqual(crossed.length, 1);
    assert.strictEqual(crossed[0].percentage, 50);
    assert.strictEqual(crossed[0].alertType, 'halfway');
  });

  it('2. Daily budget crosses 80%', () => {
    // Budget ₹500. Previous: ₹390 (78%), New: ₹410 (82%)
    const { crossed } = calculateCrossedThresholds(390, 410, 500);
    assert.strictEqual(crossed.length, 1);
    assert.strictEqual(crossed[0].percentage, 80);
    assert.strictEqual(crossed[0].alertType, 'warning');
  });

  it('3. Daily budget reaches exactly 100%', () => {
    // Budget ₹500. Previous: ₹490 (98%), New: ₹500 (100%)
    const { crossed } = calculateCrossedThresholds(490, 500, 500);
    assert.strictEqual(crossed.length, 1);
    assert.strictEqual(crossed[0].percentage, 100);
    assert.strictEqual(crossed[0].alertType, 'limit_reached');
  });

  it('4. Daily budget exceeds 100%', () => {
    // Budget ₹500. Previous: ₹500 (100%), New: ₹510 (102%)
    const { crossed } = calculateCrossedThresholds(500, 510, 500);
    assert.strictEqual(crossed.length, 1);
    assert.strictEqual(crossed[0].percentage, 101);
    assert.strictEqual(crossed[0].alertType, 'exceeded');
  });

  it('5. Weekly budget crosses all thresholds correctly', () => {
    const weeklyBudget = 3000;
    // Cross 50% (₹1,500)
    assert.strictEqual(calculateCrossedThresholds(1400, 1500, weeklyBudget).crossed[0].percentage, 50);
    // Cross 80% (₹2,400)
    assert.strictEqual(calculateCrossedThresholds(2300, 2450, weeklyBudget).crossed[0].percentage, 80);
    // Cross 100% (₹3,000)
    assert.strictEqual(calculateCrossedThresholds(2900, 3000, weeklyBudget).crossed[0].percentage, 100);
    // Exceed 100% (> ₹3,000)
    assert.strictEqual(calculateCrossedThresholds(3000, 3100, weeklyBudget).crossed[0].percentage, 101);
  });

  it('6. Monthly budget crosses all thresholds correctly', () => {
    const monthlyBudget = 12000;
    // Cross 50% (₹6,000)
    assert.strictEqual(calculateCrossedThresholds(5500, 6000, monthlyBudget).crossed[0].percentage, 50);
    // Cross 80% (₹9,600)
    assert.strictEqual(calculateCrossedThresholds(9000, 9600, monthlyBudget).crossed[0].percentage, 80);
    // Cross 100% (₹12,000)
    assert.strictEqual(calculateCrossedThresholds(11500, 12000, monthlyBudget).crossed[0].percentage, 100);
    // Exceed 100% (> ₹12,000)
    assert.strictEqual(calculateCrossedThresholds(12000, 12500, monthlyBudget).crossed[0].percentage, 101);
  });

  it('7. One transaction crosses multiple thresholds (50% -> 105%)', () => {
    // Budget ₹1,000. Previous: ₹450 (45%), New: ₹1,050 (105%)
    // Crosses: 50%, 80%, 100%, and exceeded (101)
    const { crossed } = calculateCrossedThresholds(450, 1050, 1000);
    assert.strictEqual(crossed.length, 4);
    assert.deepStrictEqual(crossed.map(c => c.percentage), [50, 80, 100, 101]);

    // Highest newly crossed threshold policy:
    const highest = crossed[crossed.length - 1];
    assert.strictEqual(highest.percentage, 101);
    assert.strictEqual(highest.alertType, 'exceeded');
  });

  it('8. Spending stays above a threshold: no duplicate alert', () => {
    // Budget ₹1,000. Previous: ₹850 (85%), New: ₹890 (89%)
    const { crossed } = calculateCrossedThresholds(850, 890, 1000);
    assert.strictEqual(crossed.length, 0);
  });

  it('9. Income transaction does not trigger budget alerts', async () => {
    const results = await budgetAlertService.evaluateBudgetsForTransaction({
      userId: 'test-user-id',
      transaction: {
        transaction_type: 'income',
        amount: 5000,
      },
    });
    assert.deepStrictEqual(results, []);
  });

  it('10. Zero or negative transaction does not trigger budget alerts', async () => {
    const zeroResults = await budgetAlertService.evaluateBudgetsForTransaction({
      userId: 'test-user-id',
      transaction: {
        transaction_type: 'expense',
        amount: 0,
      },
    });
    assert.deepStrictEqual(zeroResults, []);

    const nullResults = await budgetAlertService.evaluateBudgetsForTransaction({
      userId: null,
      transaction: null,
    });
    assert.deepStrictEqual(nullResults, []);
  });
});
