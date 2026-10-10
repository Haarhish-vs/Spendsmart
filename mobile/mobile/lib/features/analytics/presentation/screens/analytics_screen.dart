import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_storage.dart';
import '../../services/analytics_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService(ApiClient());

  bool _isLoading = true;
  final String _selectedPeriod = 'month'; // 'month', 'week'

  double _totalExpense = 0;
  double _totalIncome = 0;
  double _netSavings = 0;
  double _lastMonthExpense = 0;
  double _momChange = 0;

  List<dynamic> _categoryBreakdown = [];
  List<dynamic> _weeklyTrends = [];
  List<dynamic> _monthlyTrends = [];

  final List<Color> _chartColors = const [
    AppColors.categoryFood, // #F39C12 (Amber/Orange)
    AppColors.categoryHousing, // #3498DB (Royal Blue)
    AppColors.categoryBills, // #1ABC9C (Teal/Cyan)
    AppColors.categorySavings, // #2ECC71 (Mint Green)
    AppColors.categoryEntertainment, // #9036CA (Purple/Magenta)
    AppColors.categoryTransport, // #57606F (Slate Blue)
    AppColors.categoryHealth, // #5C9C80 (Emerald Mint)
    AppColors.categoryOther, // #8395A7 (Slate Gray)
  ];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final userId = await AppStorage.getUserId();
      if (userId != null) {
        final res = await _analyticsService.getOverview(userId, period: _selectedPeriod);
        if (mounted && res is Map<String, dynamic> && res['success'] == true) {
          final data = res['data'] as Map<String, dynamic>;
          final summary = data['summary'] as Map<String, dynamic>? ?? {};

          setState(() {
            _totalExpense = (summary['total_expense'] as num?)?.toDouble() ?? 0.0;
            _totalIncome = (summary['total_income'] as num?)?.toDouble() ?? 0.0;
            _netSavings = (summary['net_savings'] as num?)?.toDouble() ?? 0.0;
            _lastMonthExpense = (summary['last_month_expense'] as num?)?.toDouble() ?? 0.0;
            _momChange = (summary['mom_change_percentage'] as num?)?.toDouble() ?? 0.0;

            _categoryBreakdown = data['category_breakdown'] as List<dynamic>? ?? [];
            _weeklyTrends = data['weekly_trends'] as List<dynamic>? ?? [];
            _monthlyTrends = data['monthly_trends'] as List<dynamic>? ?? [];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Spending Analytics'),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppDimensions.paddingLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top Summary Card
                    _buildOverviewCard(),
                    const SizedBox(height: AppDimensions.paddingLarge),

                    // 2. Category Breakdown Donut Chart
                    _buildCategoryBreakdownSection(),
                    const SizedBox(height: AppDimensions.paddingLarge),

                    // 3. Weekly Spending Trend Bar Chart
                    _buildWeeklyTrendSection(),
                    const SizedBox(height: AppDimensions.paddingLarge),

                    // 4. Monthly Trend Section
                    if (_monthlyTrends.isNotEmpty) ...[
                      _buildMonthlyTrendSection(),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'THIS MONTH SPENDING',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white70,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_lastMonthExpense > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _momChange <= 0 ? AppColors.success.withValues(alpha: 0.25) : AppColors.error.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _momChange <= 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        size: 12,
                        color: _momChange <= 0 ? Colors.greenAccent : Colors.redAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_momChange.abs().toStringAsFixed(1)}% vs last mo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _momChange <= 0 ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_totalExpense.toStringAsFixed(2)}',
            style: AppTextStyles.displayLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Income', style: AppTextStyles.caption.copyWith(color: Colors.white70)),
                    const SizedBox(height: 2),
                    Text(
                      '₹${_totalIncome.toStringAsFixed(0)}',
                      style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Net Savings', style: AppTextStyles.caption.copyWith(color: Colors.white70)),
                    const SizedBox(height: 2),
                    Text(
                      '₹${_netSavings.toStringAsFixed(0)}',
                      style: AppTextStyles.titleMedium.copyWith(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdownSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Category Breakdown', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
              Text(
                '${_categoryBreakdown.length} Categories',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_categoryBreakdown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No categorized expenses this month', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
              ),
            )
          else ...[
            // Donut Chart
            Center(
              child: SizedBox(
                width: 170,
                height: 170,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    categories: _categoryBreakdown,
                    chartColors: _chartColors,
                    total: _totalExpense,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Total', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                        Text(
                          '₹${_totalExpense.toStringAsFixed(0)}',
                          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Category List with Progress bars
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _categoryBreakdown.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final cat = _categoryBreakdown[index] as Map<String, dynamic>;
                final name = cat['name'] ?? 'Other';
                final total = (cat['total_amount'] as num?)?.toDouble() ?? 0.0;
                final percentage = (cat['percentage'] as num?)?.toDouble() ?? 0.0;
                final color = _chartColors[index % _chartColors.length];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '₹${total.toStringAsFixed(0)}',
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${percentage.toStringAsFixed(1)}%)',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (percentage / 100).clamp(0.0, 1.0),
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyTrendSection() {
    double maxAmount = 100;
    for (final day in _weeklyTrends) {
      final amt = (day['amount'] as num?)?.toDouble() ?? 0.0;
      if (amt > maxAmount) maxAmount = amt;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('This Week Spending', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
              Text('Mon - Sun', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _weeklyTrends.map((d) {
                final dayName = d['day'] ?? '';
                final amt = (d['amount'] as num?)?.toDouble() ?? 0.0;
                final heightFactor = (amt / maxAmount).clamp(0.05, 1.0);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (amt > 0)
                      Text(
                        '₹${amt.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      width: 26,
                      height: 100 * heightFactor,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: amt > 0
                              ? [AppColors.primaryLight, AppColors.primary]
                              : [AppColors.surfaceVariant, AppColors.surfaceVariant],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dayName,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: amt > 0 ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendSection() {
    double maxExp = 100;
    for (final m in _monthlyTrends) {
      final e = (m['expense'] as num?)?.toDouble() ?? 0.0;
      if (e > maxExp) maxExp = e;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('6-Month Trend', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _monthlyTrends.map((m) {
                final monthName = m['month'] ?? '';
                final exp = (m['expense'] as num?)?.toDouble() ?? 0.0;
                final heightFactor = (exp / maxExp).clamp(0.05, 1.0);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (exp > 0)
                      Text(
                        '₹${exp.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.accent),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      width: 32,
                      height: 90 * heightFactor,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF818CF8), AppColors.accent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      monthName,
                      style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<dynamic> categories;
  final List<Color> chartColors;
  final double total;

  _DonutChartPainter({
    required this.categories,
    required this.chartColors,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0 || categories.isEmpty) {
      final paint = Paint()
        ..color = AppColors.surfaceVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20;
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - 12, paint);
      return;
    }

    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2 - 12,
    );

    double startAngle = -math.pi / 2;

    for (int i = 0; i < categories.length; i++) {
      final cat = categories[i] as Map<String, dynamic>;
      final amount = (cat['total_amount'] as num?)?.toDouble() ?? 0.0;
      final sweepAngle = (amount / total) * 2 * math.pi;

      final paint = Paint()
        ..color = chartColors[i % chartColors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round;

      // Draw arc with tiny gap
      canvas.drawArc(rect, startAngle + 0.04, sweepAngle - 0.08, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
