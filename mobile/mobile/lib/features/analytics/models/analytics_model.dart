class AnalyticsModel {
  final Map<String, double> spendingByCategory;
  final double monthlyTotal;
  final String highestSpendingCategory;

  const AnalyticsModel({
    required this.spendingByCategory,
    required this.monthlyTotal,
    required this.highestSpendingCategory,
  });
}
