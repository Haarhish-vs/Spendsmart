const budgetRepository = require('../repositories/budget.repository');

class BudgetService {
  async getUserBudgets(userId) {
    return await budgetRepository.getUserBudgets(userId);
  }

  async saveBudget(data) {
    return await budgetRepository.saveBudget(data);
  }

  async deleteBudget(id, userId) {
    return await budgetRepository.deleteBudget(id, userId);
  }

  async getBudgetAlerts(userId) {
    return await budgetRepository.getBudgetAlerts(userId);
  }
}

module.exports = new BudgetService();
