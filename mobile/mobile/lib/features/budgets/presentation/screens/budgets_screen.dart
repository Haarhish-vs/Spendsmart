import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_storage.dart';
import '../../services/budget_service.dart';
import 'create_budget_screen.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  final BudgetService _budgetService = BudgetService(ApiClient());

  bool _isLoading = true;
  List<dynamic> _budgets = [];
  List<dynamic> _alerts = [];
  String _selectedFilter = 'all'; // 'all', 'daily', 'weekly', 'monthly', 'category'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final userId = await AppStorage.getUserId();
      if (userId != null) {
        final bRes = await _budgetService.getBudgets(userId);
        final aRes = await _budgetService.getBudgetAlerts(userId);

        if (mounted) {
          setState(() {
            if (bRes is Map<String, dynamic> && bRes['success'] == true) {
              _budgets = bRes['data'] as List<dynamic>? ?? [];
            }
            if (aRes is Map<String, dynamic> && aRes['success'] == true) {
              _alerts = aRes['data'] as List<dynamic>? ?? [];
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

  List<dynamic> get _filteredBudgets {
    if (_selectedFilter == 'all') return _budgets;
    if (_selectedFilter == 'category') {
      return _budgets.where((b) => b['category_id'] != null).toList();
    }
    return _budgets.where((b) => b['period'] == _selectedFilter).toList();
  }

  Future<void> _deleteBudget(String id) async {
    final userId = await AppStorage.getUserId();
    if (userId == null || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Budget?'),
        content: const Text('Are you sure you want to remove this budget limit?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _budgetService.deleteBudget(id, userId);
        _loadData();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _filteredBudgets;

    // Check if any budget has exceeded or warned
    final warningBudgets = _budgets.where((b) => (b['status'] == 'warning' || b['status'] == 'exceeded')).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Budgets & Alerts'),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateBudgetScreen()),
          );
          if (res == true) _loadData();
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Set Budget', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.paddingLarge),
                children: [
                  // 1. Overspending Warning Banner
                  if (warningBudgets.isNotEmpty) ...[
                    _buildWarningBanner(warningBudgets),
                    const SizedBox(height: AppDimensions.paddingLarge),
                  ],

                  // 2. Filter Tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterTab('All Budgets', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterTab('Daily', 'daily'),
                        const SizedBox(width: 8),
                        _buildFilterTab('Weekly', 'weekly'),
                        const SizedBox(width: 8),
                        _buildFilterTab('Monthly', 'monthly'),
                        const SizedBox(width: 8),
                        _buildFilterTab('Category-wise', 'category'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingLarge),

                  // 3. Budgets List
                  if (displayed.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, size: 56, color: AppColors.textMuted.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text('No budgets configured', style: AppTextStyles.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "Set Budget" to create custom category or period limits',
                              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...displayed.map((b) => _buildBudgetCard(b as Map<String, dynamic>)),

                  // 4. Overspending Alerts Log Section
                  if (_alerts.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.paddingLarge),
                    Text('Recent Threshold Alerts', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._alerts.take(5).map((a) => _buildAlertLogItem(a as Map<String, dynamic>)),
                  ],
                  const SizedBox(height: 60),
                ],
              ),
            ),
    );
  }

  Widget _buildWarningBanner(List<dynamic> warningBudgets) {
    final exceededCount = warningBudgets.where((b) => b['status'] == 'exceeded').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: exceededCount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(
          color: exceededCount > 0 ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            exceededCount > 0 ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
            color: exceededCount > 0 ? AppColors.error : AppColors.warning,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exceededCount > 0 ? 'Overspending Alert!' : 'Budget Warning',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: exceededCount > 0 ? AppColors.error : const Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  exceededCount > 0
                      ? '$exceededCount of your budgets have exceeded their limit.'
                      : 'You have reached 80% or more of your budget limits.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
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

  Widget _buildBudgetCard(Map<String, dynamic> b) {
    final id = b['id'] as String;
    final name = b['name'] ?? 'Budget';
    final amount = (b['amount'] as num?)?.toDouble() ?? 0.0;
    final spent = (b['spent_amount'] as num?)?.toDouble() ?? 0.0;
    final remaining = (b['remaining_amount'] as num?)?.toDouble() ?? 0.0;
    final percent = (b['percentage_used'] as num?)?.toDouble() ?? 0.0;
    final status = b['status'] as String? ?? 'safe';
    final period = (b['period'] ?? 'monthly').toString().toUpperCase();

    Color statusColor;
    String statusLabel;
    if (status == 'exceeded') {
      statusColor = AppColors.error;
      statusLabel = 'Exceeded';
    } else if (status == 'warning') {
      statusColor = AppColors.warning;
      statusLabel = 'Warning (80%)';
    } else {
      statusColor = AppColors.success;
      statusLabel = 'On Track';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: status == 'exceeded' ? AppColors.error.withValues(alpha: 0.5) : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: statusColor.withValues(alpha: 0.12),
                    child: Icon(
                      status == 'exceeded'
                          ? Icons.error_outline_rounded
                          : (status == 'warning' ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded),
                      size: 20,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                      Text(period, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontSize: 10)),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMuted),
                    onSelected: (action) async {
                      if (action == 'edit') {
                        final res = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CreateBudgetScreen(initialBudget: b)),
                        );
                        if (res == true) _loadData();
                      } else if (action == 'delete') {
                        _deleteBudget(id);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit Limit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Amounts & Progress Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spent', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  Text(
                    '₹${spent.toStringAsFixed(0)} / ₹${amount.toStringAsFixed(0)}',
                    style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Remaining', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  Text(
                    '₹${remaining.toStringAsFixed(0)}',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: status == 'exceeded' ? AppColors.error : AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${percent.toStringAsFixed(1)}% Used',
              style: AppTextStyles.caption.copyWith(color: statusColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertLogItem(Map<String, dynamic> alert) {
    final msg = alert['message'] ?? 'Budget alert';
    final alertType = alert['alert_type'] ?? 'warning';
    final isExceeded = alertType == 'exceeded';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            isExceeded ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
            color: isExceeded ? AppColors.error : AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
