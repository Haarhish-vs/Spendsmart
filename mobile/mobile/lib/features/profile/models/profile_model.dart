enum RiskPreference { low, moderate, high }

class ProfileModel {
  final String id;
  final String name;
  final String email;
  final double monthlyIncome;
  final double savingsGoals;
  final RiskPreference riskPreference;
  final int investmentHorizonYears;

  const ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    required this.monthlyIncome,
    required this.savingsGoals,
    required this.riskPreference,
    required this.investmentHorizonYears,
  });
}
