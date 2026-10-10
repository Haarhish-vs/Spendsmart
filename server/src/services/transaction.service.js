const transactionRepository = require('../repositories/transaction.repository');

class TransactionService {
  async createTransaction(data) {
    return await transactionRepository.createTransaction(data);
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
