const budgetService = require('../services/budget.service');

const getAll = async (req, res) => {
  try {
    const userId = req.params.userId || req.query.userId;
    const budgets = await budgetService.getUserBudgets(userId);

    return res.status(200).json({
      success: true,
      data: budgets,
    });
  } catch (error) {
    return res.status(error.status || 500).json({
      success: false,
      message: error.message || 'Failed to fetch budgets',
    });
  }
};

const create = async (req, res) => {
  try {
    const budget = await budgetService.saveBudget(req.body);

    return res.status(201).json({
      success: true,
      message: 'Budget saved successfully',
      data: budget,
    });
  } catch (error) {
    return res.status(error.status || 500).json({
      success: false,
      message: error.message || 'Failed to save budget',
    });
  }
};

const update = async (req, res) => {
  try {
    const budget = await budgetService.saveBudget({
      id: req.params.id,
      ...req.body,
    });

    return res.status(200).json({
      success: true,
      message: 'Budget updated successfully',
      data: budget,
    });
  } catch (error) {
    return res.status(error.status || 500).json({
      success: false,
      message: error.message || 'Failed to update budget',
    });
  }
};

const deleteBudget = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.query.userId || req.body.user_id;
    await budgetService.deleteBudget(id, userId);

    return res.status(200).json({
      success: true,
      message: 'Budget deleted successfully',
    });
  } catch (error) {
    return res.status(error.status || 500).json({
      success: false,
      message: error.message || 'Failed to delete budget',
    });
  }
};

const getAlerts = async (req, res) => {
  try {
    const userId = req.params.userId || req.query.userId;
    const alerts = await budgetService.getBudgetAlerts(userId);

    return res.status(200).json({
      success: true,
      data: alerts,
    });
  } catch (error) {
    return res.status(error.status || 500).json({
      success: false,
      message: error.message || 'Failed to fetch budget alerts',
    });
  }
};

module.exports = {
  getAll,
  create,
  update,
  delete: deleteBudget,
  getAlerts,
};
