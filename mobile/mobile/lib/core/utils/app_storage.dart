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

  // JWT Authentication Keys
  static const String keyAuthToken = 'auth_jwt_token';
  static const String keyUserEmail = 'user_email';
  static const String keyUserFullName = 'user_full_name';
  static const String keyIsLoggedIn = 'is_logged_in';

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyIsLoggedIn) ?? false;
  }

  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyAuthToken);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyUserEmail);
  }

  static Future<String?> getUserFullName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyUserFullName);
  }

  static Future<void> saveAuthSession({
    required String token,
    required String userId,
    required String email,
    required String fullName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyIsLoggedIn, true);
    await prefs.setString(keyAuthToken, token);
    await prefs.setString(keyUserId, userId);
    await prefs.setString(keyUserEmail, email);
    await prefs.setString(keyUserFullName, fullName);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyIsLoggedIn);
    await prefs.remove(keyAuthToken);
    await prefs.remove(keyUserId);
    await prefs.remove(keyUserEmail);
    await prefs.remove(keyUserFullName);
    await prefs.remove(keyIsOnboarded);
    await prefs.remove(keySelectedBank);
    await prefs.remove(keyTrackingStart);
    await prefs.remove(keyEmploymentStatus);
    await prefs.remove(keyMonthlyIncome);
    await prefs.remove(keyDailyBudget);
    await prefs.remove(keyWeeklyBudget);
    await prefs.remove(keyMonthlyBudget);
  }

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

  static Future<void> setUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyUserId, userId);
  }

  static Future<void> setSelectedBank(String selectedBank) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keySelectedBank, selectedBank);
  }

  static Future<void> setTrackingStartDate(String trackingStart) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyTrackingStart, trackingStart);
  }

  static Future<void> setIsOnboarded(bool onboarded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyIsOnboarded, onboarded);
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
