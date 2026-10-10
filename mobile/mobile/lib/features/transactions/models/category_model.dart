import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';

class CategoryModel {
  final String id;
  final String name;
  final String iconName;
  final String categoryType;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.iconName,
    required this.categoryType,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Other',
      iconName: json['icon'] as String? ?? 'category',
      categoryType: json['category_type'] as String? ?? 'expense',
    );
  }

  IconData get iconData {
    switch (iconName.toLowerCase()) {
      case 'fastfood':
      case 'food':
        return Icons.restaurant_rounded;
      case 'shopping_bag':
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'directions_car':
      case 'transport':
        return Icons.directions_car_rounded;
      case 'receipt_long':
      case 'bills':
        return Icons.receipt_long_rounded;
      case 'movie':
      case 'entertainment':
        return Icons.movie_filter_rounded;
      case 'local_grocery_store':
      case 'groceries':
        return Icons.local_grocery_store_rounded;
      case 'fitness_center':
      case 'health':
        return Icons.favorite_rounded;
      case 'attach_money':
      case 'salary':
        return Icons.account_balance_wallet_rounded;
      case 'trending_up':
      case 'investment':
        return Icons.trending_up_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color get color {
    final lower = name.toLowerCase();
    if (lower.contains('food') || lower.contains('grocer') || lower.contains('dining')) {
      return AppColors.categoryFood; // #F39C12
    }
    if (lower.contains('shop') || lower.contains('housing') || lower.contains('rent')) {
      return AppColors.categoryHousing; // #3498DB
    }
    if (lower.contains('transport') || lower.contains('gas') || lower.contains('travel') || lower.contains('fuel')) {
      return AppColors.categoryTransport; // #57606F
    }
    if (lower.contains('bill') || lower.contains('utilit') || lower.contains('recharge')) {
      return AppColors.categoryBills; // #1ABC9C
    }
    if (lower.contains('entertain') || lower.contains('fun') || lower.contains('movie')) {
      return AppColors.categoryEntertainment; // #9036CA
    }
    if (lower.contains('salary') || lower.contains('invest') || lower.contains('saving')) {
      return AppColors.categorySavings; // #2ECC71
    }
    if (lower.contains('health') || lower.contains('fitness') || lower.contains('medical')) {
      return AppColors.categoryHealth; // #5C9C80
    }
    return AppColors.categoryOther; // #8395A7
  }
}
