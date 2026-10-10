import 'package:shared_preferences/shared_preferences.dart';

class AppStorage {
  static const String keyIsOnboarded = 'is_onboarded';
  static const String keyUserId = 'user_id';
  static const String keySelectedBank = 'selected_bank';
  static const String keyTrackingStart = 'tracking_start_date';
  static const String keyEmploymentStatus = 'employment_status';
  static const String keyMonthlyIncome = 'monthly_income';
  static const String keyDailyBudget = 'daily_budget';
  static const String keyWeeklyBudget = 'weekly_budget';
  static const String keyMonthlyBudget = 'monthly_budget';

  static Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyIsOnboarded) ?? false;
  }

  static Future<void> setOnboarded({
    required String userId,
    required String selectedBank,
    required String trackingStart,
    required String employmentStatus,
    double? monthlyIncome,
    required double dailyBudget,
    required double weeklyBudget,
    required double monthlyBudget,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyIsOnboarded, true);
    await prefs.setString(keyUserId, userId);
    await prefs.setString(keySelectedBank, selectedBank);
    await prefs.setString(keyTrackingStart, trackingStart);
    await prefs.setString(keyEmploymentStatus, employmentStatus);
    if (monthlyIncome != null) {
      await prefs.setDouble(keyMonthlyIncome, monthlyIncome);
    }
    await prefs.setDouble(keyDailyBudget, dailyBudget);
    await prefs.setDouble(keyWeeklyBudget, weeklyBudget);
    await prefs.setDouble(keyMonthlyBudget, monthlyBudget);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyUserId);
  }

  static Future<String?> getSelectedBank() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keySelectedBank);
  }

  static Future<DateTime?> getTrackingStartDate() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(keyTrackingStart);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
