const transactionService = require('../services/transaction.service');

/**
 * Controller to handle transaction creation
 * @route POST /api/v1/transactions
 */
const createTransaction = async (req, res) => {
  try {
    const transactionData = req.body;
    const transaction = await transactionService.createTransaction(transactionData);

    return res.status(201).json({
      success: true,
      message: transaction.is_duplicate ? 'Transaction already exists' : 'Transaction created successfully',
      data: transaction,
    });
  } catch (error) {
    return res.status(error.status || 500).json({
      success: false,
      message: error.message || 'Failed to create transaction',
    });
  }
};

/**
 * Controller to retrieve user transactions
 * @route GET /api/v1/transactions/:userId
 */
const getTransactions = async (req, res) => {
  try {
    const { userId } = req.params;
    const transactions = await transactionService.getTransactions(userId);

    return res.status(200).json({
      success: true,
      data: transactions,
    });
  } catch (error) {
    return res.status(error.status || 500).json({
      success: false,
      message: error.message || 'Failed to fetch transactions',
    });
  }
};

/**
 * Controller to retrieve dashboard metrics & summary
 * @route GET /api/v1/transactions/summary/:userId
 */
const getDashboardSummary = async (req, res) => {
  try {
    const { userId } = req.params;
    const summary = await transactionService.getDashboardSummary(userId);

    return res.status(200).json({
      success: true,
      data: summary,
    });
  } catch (error) {
    return res.status(error.status || 500).json({
      success: false,
      message: error.message || 'Failed to fetch dashboard summary',
    });
  }
};

/**
 * Controller to delete a transaction
 * @route DELETE /api/v1/transactions/:id
 */
const deleteTransaction = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.query.userId || req.body.user_id;
    await transactionService.deleteTransaction(id, userId);

    return res.status(200).json({
      success: true,
      message: 'Transaction deleted successfully',
    });
  } catch (error) {
    return res.status(error.status || 500).json({
      success: false,
      message: error.message || 'Failed to delete transaction',
    });
  }
};

module.exports = {
  createTransaction,
  getTransactions,
  getDashboardSummary,
  deleteTransaction,
};
