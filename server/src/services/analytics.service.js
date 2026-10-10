const analyticsRepository = require('../repositories/analytics.repository');

class AnalyticsService {
  async getOverview(userId, period) {
    return await analyticsRepository.getOverview(userId, period);
  }
}

module.exports = new AnalyticsService();
