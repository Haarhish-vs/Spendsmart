/**
 * Budget constants
 */
const BUDGET_PERIODS = {
  DAILY: 'daily',
  WEEKLY: 'weekly',
  MONTHLY: 'monthly',
};

const BUDGET_THRESHOLDS = {
  WARNING: 0.80, // 80% threshold
  CRITICAL: 0.90, // 90% threshold
  EXCEEDED: 1.00, // 100% threshold
};

const BUDGET_STATUS = {
  NORMAL: 'normal',
  WARNING: 'warning',
  CRITICAL: 'critical',
  EXCEEDED: 'exceeded',
};

module.exports = {
  BUDGET_PERIODS,
  BUDGET_THRESHOLDS,
  BUDGET_STATUS,
};
