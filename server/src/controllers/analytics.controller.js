const analyticsService = require('../services/analytics.service');

const getOverview = async (req, res) => {
  try {
    const userId = req.params.userId || req.query.userId;
    const period = req.query.period || 'month';
    const overview = await analyticsService.getOverview(userId, period);

    return res.status(200).json({
      success: true,
      data: overview,
    });
  } catch (error) {
    return res.status(error.status || 500).json({
      success: false,
      message: error.message || 'Failed to fetch analytics overview',
    });
  }
};

module.exports = {
  getOverview,
};
