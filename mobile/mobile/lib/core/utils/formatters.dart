class Formatters {
  Formatters._();

  static String currency(double amount, {String symbol = '₹'}) {
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  static String percentage(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }
}
