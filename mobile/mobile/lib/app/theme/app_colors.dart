import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core UI Base Colors
  static const Color primary = Color(0xFF232C54); // Deep Navy Blue (Trust Base)
  static const Color primaryLight = Color(0xFF384576); // Soft Navy Slate
  static const Color primaryDark = Color(0xFF171E3D); // Deep Midnight
  static const Color secondary = Color(0xFF2ECC71); // Mint / Emerald Green
  static const Color accent = Color(0xFF3498DB); // Royal / Deep Blue

  // Background Canvas & Surface
  static const Color background = Color(0xFFF4F6F9); // Clean Off-White / Light Gray
  static const Color surface = Color(0xFFFFFFFF); // Pure White Surface
  static const Color surfaceVariant = Color(0xFFE9EDF4); // Soft Slate Gray Surface
  static const Color darkCanvas = Color(0xFF121824); // Soft Dark Slate (Dark Mode)

  // Text Colors
  static const Color textPrimary = Color(0xFF1E293B); // Dark Slate Charcoal
  static const Color textSecondary = Color(0xFF64748B); // Muted Slate
  static const Color textMuted = Color(0xFF94A3B8); // Light Slate
  static const Color textLight = Color(0xFFFFFFFF);

  // Semantic Status Colors
  static const Color success = Color(0xFF2ECC71); // Mint / Emerald (Income & Positive)
  static const Color income = Color(0xFF2ECC71); // Growth / Incoming Money
  static const Color expense = Color(0xFFE74C3C); // Coral / Orange-Red (Expenses)
  static const Color warning = Color(0xFFF39C12); // Warm Amber (80% Warning)
  static const Color critical = Color(0xFFE67E22); // Orange (100% Threshold)
  static const Color error = Color(0xFFFF4757); // Bright Warning Red / Magenta (Over-budget)
  static const Color overBudget = Color(0xFFFF4757); // Alert / Over-budget
  static const Color info = Color(0xFF3498DB); // Royal Blue

  // Border & Divider
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFECEFF4);

  // Category Colors
  static const Color categoryFood = Color(0xFFF39C12); // Warm Amber / Orange (Groceries / Food)
  static const Color categoryHousing = Color(0xFF3498DB); // Royal / Deep Blue (Housing / Shopping)
  static const Color categoryBills = Color(0xFF1ABC9C); // Teal / Cyan (Utilities / Bills)
  static const Color categorySavings = Color(0xFF2ECC71); // Mint Green (Savings / Investments / Salary)
  static const Color categoryEntertainment = Color(0xFF9036CA); // Purple / Magenta (Fun Money)
  static const Color categoryTransport = Color(0xFF57606F); // Slate Blue (Transportation / Gas)
  static const Color categoryHealth = Color(0xFF5C9C80); // Emerald Mint (Health & Fitness)
  static const Color categoryOther = Color(0xFF8395A7); // Slate Gray (Other)
}
