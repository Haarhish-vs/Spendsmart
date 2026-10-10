/**
 * Generic date helper utilities
 */
const dateUtils = {
  getStartOfMonth: (date = new Date()) => {
    return new Date(date.getFullYear(), date.getMonth(), 1);
  },
  getEndOfMonth: (date = new Date()) => {
    return new Date(date.getFullYear(), date.getMonth() + 1, 0, 23, 59, 59, 999);
  },
  formatISO: (date = new Date()) => {
    return date.toISOString();
  },
};

module.exports = dateUtils;
