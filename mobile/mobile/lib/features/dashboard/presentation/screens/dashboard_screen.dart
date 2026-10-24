import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/app/routes/route_names.dart';
import 'package:mobile/app/theme/app_colors.dart';
import 'package:mobile/app/theme/app_dimensions.dart';
import 'package:mobile/app/theme/app_text_styles.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/utils/app_storage.dart';
import 'package:mobile/core/utils/formatters.dart';
import 'package:mobile/core/widgets/app_card.dart';
import 'package:mobile/core/widgets/empty_state.dart';
import 'package:mobile/features/notifications/services/push_notification_service.dart';
import 'package:mobile/features/transactions/services/sms_parser_service.dart';
import 'package:mobile/features/transactions/services/transaction_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TransactionService _transactionService = TransactionService(ApiClient());
  late final SmsParserService _smsParserService;

  bool _isLoading = true;
  bool _isSyncingSms = false;
  String? _errorMessage;
  String? _selectedBank;
  String? _userId;

  // Real financial state retrieved directly from database
  double _todaySpent = 0;
  double _weekSpent = 0;
  double _monthSpent = 0;
  double _dailyBudget = 0;
  double _weeklyBudget = 0;
  double _monthlyBudget = 0;
  List<dynamic> _recentTransactions = [];

  bool _smsPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _smsParserService = SmsParserService(_transactionService);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.handlePendingInitialMessage();
    });
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _userId = await AppStorage.getUserId();
    _selectedBank = await AppStorage.getSelectedBank();
    _smsPermissionGranted = await _smsParserService.hasSmsPermission();

    await _fetchSummary();
    PushNotificationService.syncDeviceToken();

    if (mounted) setState(() => _isLoading = false);

    // If permission not yet granted, request with explanation dialog
    if (!_smsPermissionGranted) {
      _promptSmsPermission();
    } else {
      _syncSmsTransactions();
    }
  }

  Future<void> _fetchSummary() async {
    // If userId not stored locally, attempt to initialize via backend
    if (_userId == null) {
      try {
        final initRes = await ApiClient().get('/profile/init');
        if (initRes is Map<String, dynamic> && initRes['data']?['id'] != null) {
          _userId = initRes['data']['id'] as String;
          await AppStorage.setUserId(_userId!);

          final bank = (initRes['data']?['selected_bank'] ??
              initRes['data']?['user_metadata']?['selected_bank']) as String?;
          if (bank != null && bank.isNotEmpty) {
            _selectedBank = bank;
            await AppStorage.setSelectedBank(bank);
          }

          final tracking = (initRes['data']?['tracking_start'] ??
              initRes['data']?['user_metadata']?['tracking_start']) as String?;
          if (tracking != null && tracking.isNotEmpty) {
            await AppStorage.setTrackingStartDate(tracking);
          }

          await AppStorage.setIsOnboarded(true);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Could not connect to SpendSmart backend. Tap to retry.';
          });
        }
        return;
      }
    }

    if (_userId == null) return;

    try {
      final response = await _transactionService.getDashboardSummary(_userId!);
      if (response is Map<String, dynamic> && response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;

        // Refresh selected bank from backend if available
        final serverBank = data['selected_bank'] as String?;
        if (serverBank != null && serverBank.isNotEmpty) {
          _selectedBank = serverBank;
          await AppStorage.setSelectedBank(serverBank);
        }

        if (mounted) {
          setState(() {
            _errorMessage = null;
            _todaySpent = (data['today_spent'] as num?)?.toDouble() ?? 0.0;
            _weekSpent = (data['week_spent'] as num?)?.toDouble() ?? 0.0;
            _monthSpent = (data['month_spent'] as num?)?.toDouble() ?? 0.0;
            _dailyBudget = (data['daily_budget'] as num?)?.toDouble() ?? 0.0;
            _weeklyBudget = (data['weekly_budget'] as num?)?.toDouble() ?? 0.0;
            _monthlyBudget = (data['monthly_budget'] as num?)?.toDouble() ?? 0.0;
            _recentTransactions = data['recent_transactions'] as List<dynamic>? ?? [];
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = response['message'] ?? 'Failed to load financial data from server';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _promptSmsPermission() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final bankDisplay = (_selectedBank != null && _selectedBank!.isNotEmpty) ? _selectedBank! : 'your selected bank';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        ),
        title: Row(
          children: const [
            Icon(Icons.sms_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Bank SMS Access'),
          ],
        ),
        content: Text(
          'SpendSmart uses bank SMS messages to automatically track your expenses. Only relevant debit transactions from $bankDisplay will be processed.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('Later', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final granted = await _smsParserService.requestSmsPermission();
              setState(() => _smsPermissionGranted = granted);
              if (granted) {
                _syncSmsTransactions();
              }
            },
            child: const Text('Allow Access'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncSmsTransactions() async {
    if (_isSyncingSms) return;
    setState(() => _isSyncingSms = true);

    try {
      final count = await _smsParserService.syncInboxTransactions();
      await _fetchSummary();

      if (mounted) {
        if (count > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count new bank debit transaction(s) processed!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingSms = false);
    }
  }

  void _showDiagnosticsModal() {
    final diagnostics = _smsParserService.recentDiagnostics;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(AppDimensions.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('SMS Diagnostics', style: AppTextStyles.heading2),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Safe diagnostics showing why recent SMS messages were matched or rejected. No sensitive data is displayed.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              const Divider(height: 24),
              Expanded(
                child: diagnostics.isEmpty
                  ? const Center(
                      child: Text(
                        'No SMS sync events recorded yet.\nTap Sync icon on dashboard to scan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: diagnostics.length,
                      separatorBuilder: (_, index) => const Divider(height: 12),
                      itemBuilder: (_, index) {
                        final log = diagnostics[diagnostics.length - 1 - index]; // latest first
                        final isSuccess = log.reasonCode == 'TRANSACTION_SAVED';
                        final isDuplicate = log.reasonCode == 'DUPLICATE_TRANSACTION';
                        final color = isSuccess
                            ? AppColors.success
                            : (isDuplicate ? Colors.orange : AppColors.error);

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isSuccess
                                  ? Icons.check_circle_outline
                                  : (isDuplicate ? Icons.copy_rounded : Icons.cancel_outlined),
                              color: color,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        log.reasonCode,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: color,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('hh:mm:ss a').format(log.timestamp),
                                        style: AppTextStyles.caption,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    log.safeMessage,
                                    style: AppTextStyles.bodySmall,
                                  ),
                                  if (log.amount != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Amount: ${Formatters.currency(log.amount!)}',
                                      style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SpendSmart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'SMS Diagnostics',
            onPressed: _showDiagnosticsModal,
          ),
          IconButton(
            icon: _isSyncingSms
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            tooltip: 'Sync Bank SMS',
            onPressed: _syncSmsTransactions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _syncSmsTransactions();
                await _fetchSummary();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppDimensions.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // API Failure Banner
                    if (_errorMessage != null) ...[
                      _buildErrorBanner(),
                      const SizedBox(height: 16),
                    ],

                    // Bank Active Banner
                    _buildBankStatusBanner(),
                    const SizedBox(height: 16),

                    // Today's Expense Card
                    _buildTodayExpenseCard(),
                    const SizedBox(height: 24),

                    // Budget Progress Section
                    const Text('Budget Overview', style: AppTextStyles.heading2),
                    const SizedBox(height: 12),
                    _buildBudgetUsageCard(
                      title: 'Daily Budget',
                      spent: _todaySpent,
                      budget: _dailyBudget,
                      icon: Icons.today_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildBudgetUsageCard(
                      title: 'Weekly Budget',
                      spent: _weekSpent,
                      budget: _weeklyBudget,
                      icon: Icons.view_week_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildBudgetUsageCard(
                      title: 'Monthly Budget',
                      spent: _monthSpent,
                      budget: _monthlyBudget,
                      icon: Icons.calendar_month_rounded,
                    ),
                    const SizedBox(height: 28),

                    // Recent Transactions Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recent Transactions', style: AppTextStyles.heading2),
                        TextButton(
                          onPressed: () async {
                            await Navigator.pushNamed(context, RouteNames.transactions);
                            _fetchSummary();
                          },
                          child: const Text('View All >', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildRecentTransactionsList(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final res = await Navigator.pushNamed(context, RouteNames.addTransaction);
          if (res == true) {
            _fetchSummary();
          }
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        backgroundColor: AppColors.surface,
        elevation: 8,
        onTap: (index) async {
          if (index == 1) {
            await Navigator.pushNamed(context, RouteNames.transactions);
            _fetchSummary();
          } else if (index == 2) {
            await Navigator.pushNamed(context, RouteNames.analytics);
            _fetchSummary();
          } else if (index == 3) {
            await Navigator.pushNamed(context, RouteNames.budgets);
            _fetchSummary();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_rounded),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Budgets',
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(20),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.error.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? 'Network error occurred',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchSummary().then((_) {
                if (mounted) setState(() => _isLoading = false);
              });
            },
            child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBankStatusBanner() {
    final hasBank = _selectedBank != null && _selectedBank!.isNotEmpty;
    final bankTitle = hasBank ? _selectedBank! : 'Not Selected';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connected Bank: $bankTitle',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  !hasBank
                      ? 'Please complete bank selection in onboarding'
                      : (_smsPermissionGranted
                          ? 'Automated SMS debit sync active'
                          : 'SMS permission needed for automated sync'),
                  style: AppTextStyles.caption.copyWith(
                    color: !hasBank
                        ? AppColors.error
                        : (_smsPermissionGranted ? AppColors.success : AppColors.warning),
                  ),
                ),
              ],
            ),
          ),
          if (!hasBank)
            TextButton(
              onPressed: () => Navigator.pushNamed(context, RouteNames.onboarding),
              child: const Text('Set Bank'),
            )
          else if (!_smsPermissionGranted)
            TextButton(
              onPressed: _promptSmsPermission,
              child: const Text('Enable'),
            ),
        ],
      ),
    );
  }

  Widget _buildTodayExpenseCard() {
    final hasBudget = _dailyBudget > 0;
    final isExceeded = hasBudget && _todaySpent > _dailyBudget;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Expenses",
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat('dd MMM yyyy').format(DateTime.now()),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            Formatters.currency(_todaySpent),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                hasBudget
                    ? (isExceeded ? Icons.warning_rounded : Icons.check_circle_outline)
                    : Icons.info_outline,
                size: 16,
                color: hasBudget
                    ? (isExceeded ? Colors.amberAccent : Colors.lightGreenAccent)
                    : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                hasBudget
                    ? (isExceeded
                        ? 'Exceeded daily limit by ${Formatters.currency(_todaySpent - _dailyBudget)}'
                        : '${Formatters.currency(_dailyBudget - _todaySpent)} remaining today')
                    : 'No daily budget limit set',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetUsageCard({
    required String title,
    required double spent,
    required double budget,
    required IconData icon,
  }) {
    final hasBudget = budget > 0;
    final progress = hasBudget ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final isExceeded = hasBudget && spent > budget;
    final isWarning = hasBudget && progress >= 0.8 && !isExceeded;

    Color statusColor = AppColors.success;
    if (isExceeded) {
      statusColor = AppColors.error;
    } else if (isWarning) {
      statusColor = AppColors.warning;
    } else if (!hasBudget) {
      statusColor = AppColors.textMuted;
    }

    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: AppTextStyles.heading3),
              ),
              Text(
                hasBudget
                    ? '${Formatters.currency(spent)} / ${Formatters.currency(budget)}'
                    : '${Formatters.currency(spent)} (No limit set)',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isExceeded ? AppColors.error : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              hasBudget
                  ? (isExceeded
                      ? 'Over budget by ${(progress * 100).toStringAsFixed(0)}%'
                      : '${(progress * 100).toStringAsFixed(0)}% used')
                  : 'Tap Budgets tab to set a limit',
              style: AppTextStyles.caption.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsList() {
    if (_recentTransactions.isEmpty) {
      final bankDisplay = (_selectedBank != null && _selectedBank!.isNotEmpty) ? _selectedBank! : 'your selected bank';

      return AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: EmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'No transactions yet',
            subtitle: 'Debit SMS from $bankDisplay will appear here automatically.',
            action: OutlinedButton.icon(
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Scan SMS Now'),
              onPressed: _syncSmsTransactions,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentTransactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tx = _recentTransactions[index] as Map<String, dynamic>;
        final merchant = tx['merchant'] ?? tx['description'] ?? 'Expense';
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final rawDate = tx['transaction_date'];
        DateTime txDate = DateTime.now();
        if (rawDate != null) {
          txDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
        }
        final formattedDate = DateFormat('dd MMM, hh:mm a').format(txDate.toLocal());
        final isSms = tx['source'] == 'sms';

        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant.toString().toUpperCase(),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(formattedDate, style: AppTextStyles.caption),
                        if (isSms) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SMS',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '- ${Formatters.currency(amount)}',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
