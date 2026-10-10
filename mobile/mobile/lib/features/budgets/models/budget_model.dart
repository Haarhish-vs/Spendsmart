enum BudgetPeriod { daily, weekly, monthly }

enum BudgetStatus { normal, warning, critical, exceeded }

class BudgetModel {
  final String id;
  final String category;
  final double limitAmount;
  final double currentSpent;
  final BudgetPeriod period;

  const BudgetModel({
    required this.id,
    required this.category,
    required this.limitAmount,
    required this.currentSpent,
    required this.period,
  });

  double get progress => limitAmount > 0 ? (currentSpent / limitAmount) : 0.0;

  BudgetStatus get status {
    if (progress >= 1.0) return BudgetStatus.exceeded;
    if (progress >= 0.9) return BudgetStatus.critical;
    if (progress >= 0.8) return BudgetStatus.warning;
    return BudgetStatus.normal;
  }
}
