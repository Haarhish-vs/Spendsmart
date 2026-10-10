class AppConstants {
  AppConstants._();

  static const String appName = 'SpendSmart';
  static const String appVersion = '1.0.0';

  // Budget alert thresholds
  static const double budgetWarningThreshold = 0.80; // 80%
  static const double budgetCriticalThreshold = 0.90; // 90%
  static const double budgetExceededThreshold = 1.00; // 100%
}
