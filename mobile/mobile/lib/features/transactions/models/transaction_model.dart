enum TransactionType { expense, income }

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String category;
  final String? merchant;

  const TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.category,
    this.merchant,
  });
}
