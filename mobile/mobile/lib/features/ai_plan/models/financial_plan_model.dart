class FinancialPlanModel {
  final double monthlySavingsTarget;
  final double emergencyFundTarget;
  final double emergencyFundCurrent;
  final Map<String, double> investmentAllocation;
  final List<String> spendingRecommendations;
  final List<String> learningRecommendations;

  const FinancialPlanModel({
    required this.monthlySavingsTarget,
    required this.emergencyFundTarget,
    required this.emergencyFundCurrent,
    required this.investmentAllocation,
    required this.spendingRecommendations,
    required this.learningRecommendations,
  });
}
