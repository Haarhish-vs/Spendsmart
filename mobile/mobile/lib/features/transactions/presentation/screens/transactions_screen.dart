import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/routes/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_storage.dart';
import '../../models/category_model.dart';
import '../../services/category_service.dart';
import '../../services/transaction_service.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TransactionService _transactionService = TransactionService(ApiClient());
  final CategoryService _categoryService = CategoryService(ApiClient());

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<dynamic> _transactions = [];
  List<CategoryModel> _categories = [];
  String? _selectedCategoryName;
  String _selectedTypeFilter = 'all'; // 'all', 'expense', 'income'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final userId = await AppStorage.getUserId();
      final catList = await _categoryService.getCategories();

      if (userId != null) {
        final res = await _transactionService.getTransactions(userId);
        if (mounted) {
          setState(() {
            _categories = catList;
            if (res is Map<String, dynamic> && res['success'] == true) {
              _transactions = res['data'] as List<dynamic>? ?? [];
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredTransactions {
    return _transactions.where((tx) {
      final merchant = (tx['merchant'] ?? '').toString().toLowerCase();
      final desc = (tx['description'] ?? '').toString().toLowerCase();
      final type = (tx['transaction_type'] ?? 'expense').toString().toLowerCase();
      final catName = tx['categories'] != null ? (tx['categories']['name'] ?? '') : '';

      // Type filter
      if (_selectedTypeFilter != 'all' && type != _selectedTypeFilter) {
        return false;
      }

      // Category filter
      if (_selectedCategoryName != null && catName != _selectedCategoryName) {
        return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        if (!merchant.contains(_searchQuery) && !desc.contains(_searchQuery)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _deleteTransaction(String id) async {
    final userId = await AppStorage.getUserId();
    if (userId == null || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLarge)),
        title: const Text('Delete Transaction?'),
        content: const Text('Are you sure you want to remove this transaction record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _transactionService.deleteTransaction(id, userId);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction deleted')),
          );
        }
      } catch (_) {}
    }
  }

  IconData _getCategoryIcon(String? iconName) {
    switch ((iconName ?? '').toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    final displayed = _filteredTransactions;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transactions'),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await Navigator.pushNamed(context, RouteNames.addTransaction);
          if (res == true) _loadData();
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical: AppDimensions.space8,
            ),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search merchant or notes...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Type Filter Chips (All, Expense, Income)
                Row(
                  children: [
                    _buildTypeChip('All', 'all'),
                    const SizedBox(width: 8),
                    _buildTypeChip('Expenses', 'expense'),
                    const SizedBox(width: 8),
                    _buildTypeChip('Income', 'income'),
                  ],
                ),
                const SizedBox(height: 8),

                // Category Chips (Horizontal Scroll)
                if (_categories.isNotEmpty)
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            selected: _selectedCategoryName == null,
                            label: const Text('All Categories'),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: _selectedCategoryName == null ? Colors.white : AppColors.textPrimary,
                            ),
                            selectedColor: AppColors.primaryLight,
                            backgroundColor: AppColors.surfaceVariant,
                            onSelected: (_) => setState(() => _selectedCategoryName = null),
                          ),
                        ),
                        ..._categories.map((c) {
                          final isSel = _selectedCategoryName == c.name;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              selected: isSel,
                              avatar: Icon(c.iconData, size: 14, color: isSel ? Colors.white : c.color),
                              label: Text(c.name),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: isSel ? Colors.white : AppColors.textPrimary,
                              ),
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surfaceVariant,
                              onSelected: (_) => setState(() {
                                _selectedCategoryName = isSel ? null : c.name;
                              }),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Transaction List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayed.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            const Text('No transactions found', style: AppTextStyles.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              _searchQuery.isNotEmpty || _selectedCategoryName != null
                                  ? 'Try adjusting your filters'
                                  : 'Transactions from bank SMS or manual entry will appear here',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppDimensions.space16),
                          itemCount: displayed.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final tx = displayed[index] as Map<String, dynamic>;
                            final id = tx['id'] as String;
                            final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                            final merchant = tx['merchant'] ?? 'Transaction';
                            final isExpense = (tx['transaction_type'] ?? 'expense') == 'expense';
                            final dateStr = tx['transaction_date'] as String?;
                            final date = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();
                            final source = tx['source'] ?? 'manual';
                            final desc = tx['description'] as String?;
                            final catData = tx['categories'] as Map<String, dynamic>?;
                            final catName = catData?['name'] ?? 'Other';
                            final iconName = catData?['icon'];

                            return Dismissible(
                              key: Key(id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                                ),
                                child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                              ),
                              onDismissed: (_) => _deleteTransaction(id),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                                  border: Border.all(color: AppColors.border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(AppDimensions.space16),
                                child: Row(
                                  children: [
                                    // Category Avatar
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: isExpense
                                          ? AppColors.error.withValues(alpha: 0.1)
                                          : AppColors.success.withValues(alpha: 0.1),
                                      child: Icon(
                                        _getCategoryIcon(iconName),
                                        size: 20,
                                        color: isExpense ? AppColors.error : AppColors.success,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Title & Metadata
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  merchant,
                                                  style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w600),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: source == 'sms'
                                                      ? AppColors.primary.withValues(alpha: 0.1)
                                                      : AppColors.surfaceVariant,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  source.toString().toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: source == 'sms' ? AppColors.primary : AppColors.textSecondary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                catName,
                                                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                              ),
                                              const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                                              Text(
                                                DateFormat('dd MMM, hh:mm a').format(date),
                                                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                                              ),
                                            ],
                                          ),
                                          if (desc != null && desc.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              desc,
                                              style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                    // Amount
                                    Text(
                                      '${isExpense ? '-' : '+'}₹${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}',
                                      style: AppTextStyles.titleMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isExpense ? AppColors.textPrimary : AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, String value) {
    final isSelected = _selectedTypeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedTypeFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
