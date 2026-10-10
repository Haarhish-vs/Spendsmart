const transactionRepository = require('../repositories/transaction.repository');
const budgetAlertService = require('./budget-alert.service');

class TransactionService {
  async createTransaction(data) {
    const transaction = await transactionRepository.createTransaction(data);

    // If a valid new expense was inserted, evaluate budget thresholds immediately
    if (transaction && !transaction.is_duplicate && transaction.transaction_type === 'expense') {
      budgetAlertService
        .evaluateBudgetsForTransaction({
          userId: transaction.user_id,
          transaction,
        })
        .catch((err) => {
          console.error('Budget threshold evaluation error (non-fatal):', err.message);
        });
    }

    return transaction;
  }

  async getTransactions(userId) {
    return await transactionRepository.getTransactions(userId);
  }

  async getDashboardSummary(userId) {
    return await transactionRepository.getDashboardSummary(userId);
  }

  async deleteTransaction(id, userId) {
    return await transactionRepository.deleteTransaction(id, userId);
  }
}

module.exports = new TransactionService();
