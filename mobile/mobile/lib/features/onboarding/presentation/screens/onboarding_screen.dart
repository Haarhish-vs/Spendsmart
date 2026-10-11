import 'package:flutter/material.dart';
import 'package:mobile/app/routes/route_names.dart';
import 'package:mobile/app/theme/app_colors.dart';
import 'package:mobile/app/theme/app_dimensions.dart';
import 'package:mobile/app/theme/app_text_styles.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/widgets/app_button.dart';
import 'package:mobile/core/widgets/app_text_field.dart';
import 'package:mobile/features/onboarding/services/onboarding_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final OnboardingService _onboardingService = OnboardingService(ApiClient());

  int _currentPage = 0;
  bool _isLoading = false;

  // Onboarding form state
  String _employmentStatus = 'employed'; // 'employed' or 'unemployed'
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _dailyBudgetController = TextEditingController();
  final TextEditingController _weeklyBudgetController = TextEditingController();
  final TextEditingController _monthlyBudgetController = TextEditingController();
  String? _selectedBank;

  final List<String> _bankOptions = [
    'HDFC Bank',
    'SBI',
    'ICICI Bank',
    'Axis Bank',
    'Kotak Mahindra Bank',
    'Canara Bank',
    'Bank of Baroda',
    'Punjab National Bank',
    'Union Bank',
    'Indian Bank',
    'IDBI Bank',
    'IndusInd Bank',
    'Yes Bank',
    'Federal Bank',
    'Other',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _salaryController.dispose();
    _dailyBudgetController.dispose();
    _weeklyBudgetController.dispose();
    _monthlyBudgetController.dispose();
    super.dispose();
  }

  void _nextPage() {
    // If unemployed, jump over salary page directly to budget setup
    if (_currentPage == 0 && _employmentStatus == 'unemployed') {
      _pageController.jumpToPage(2);
      setState(() => _currentPage = 2);
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    // If unemployed and going back from budget page (page 2), jump back to employment page (page 0)
    if (_currentPage == 2 && _employmentStatus == 'unemployed') {
      _pageController.jumpToPage(0);
      setState(() => _currentPage = 0);
      return;
    }

    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _submitOnboarding() async {
    if (_selectedBank == null || _selectedBank!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your bank to finish setup'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final double? dailyBudget = double.tryParse(_dailyBudgetController.text.trim());
    final double? weeklyBudget = double.tryParse(_weeklyBudgetController.text.trim());
    final double? monthlyBudget = double.tryParse(_monthlyBudgetController.text.trim());

    if (dailyBudget == null || dailyBudget <= 0 ||
        weeklyBudget == null || weeklyBudget <= 0 ||
        monthlyBudget == null || monthlyBudget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid positive numbers for daily, weekly, and monthly budgets'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final double? monthlyIncome = _employmentStatus == 'employed'
          ? double.tryParse(_salaryController.text.trim())
          : null;

      await _onboardingService.submitOnboarding(
        employmentStatus: _employmentStatus,
        monthlyIncome: monthlyIncome,
        dailyBudget: dailyBudget,
        weeklyBudget: weeklyBudget,
        monthlyBudget: monthlyBudget,
        selectedBank: _selectedBank!,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, RouteNames.home);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SpendSmart Setup'),
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: _prevPage,
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space24,
                vertical: AppDimensions.space12,
              ),
              child: Row(
                children: List.generate(4, (index) {
                  final bool isPassed = index <= _currentPage;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isPassed ? AppColors.primary : AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildEmploymentStep(),
                  _buildSalaryStep(),
                  _buildBudgetStep(),
                  _buildBankStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 1: Employment Status
  Widget _buildEmploymentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Employment Status',
            style: AppTextStyles.heading1,
          ),
          const SizedBox(height: 8),
          Text(
            'Are you employed or unemployed / student?',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          _buildSelectionCard(
            title: 'Employed',
            subtitle: 'Receiving a regular monthly salary or freelance income',
            icon: Icons.work_rounded,
            isSelected: _employmentStatus == 'employed',
            onTap: () => setState(() => _employmentStatus = 'employed'),
          ),
          const SizedBox(height: 16),
          _buildSelectionCard(
            title: 'Unemployed / Student',
            subtitle: 'Managing personal or pocket allowance without fixed salary',
            icon: Icons.school_rounded,
            isSelected: _employmentStatus == 'unemployed',
            onTap: () => setState(() => _employmentStatus = 'unemployed'),
          ),
          const SizedBox(height: 40),
          AppButton(
            label: 'Continue',
            onPressed: _nextPage,
          ),
        ],
      ),
    );
  }

  // STEP 2: Monthly Salary (Employed only)
  Widget _buildSalaryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Income',
            style: AppTextStyles.heading1,
          ),
          const SizedBox(height: 8),
          Text(
            'What is your monthly income? This helps SpendSmart calculate your financial health.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          AppTextField(
            label: 'Monthly Salary (₹)',
            hintText: 'e.g. 30000',
            controller: _salaryController,
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.currency_rupee, color: AppColors.primary),
          ),
          const SizedBox(height: 40),
          AppButton(
            label: 'Continue to Budgets',
            onPressed: () {
              final val = double.tryParse(_salaryController.text.trim());
              if (val == null || val <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid monthly income greater than 0'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              _nextPage();
            },
          ),
        ],
      ),
    );
  }

  // STEP 3: Budget Setup (For Everyone)
  Widget _buildBudgetStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set Your Spending Budgets',
            style: AppTextStyles.heading1,
          ),
          const SizedBox(height: 8),
          Text(
            'Set your target limits to receive timely alerts and keep your spending on track.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          AppTextField(
            label: 'Daily Budget (₹)',
            hintText: 'e.g. 500',
            controller: _dailyBudgetController,
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.today_rounded, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Weekly Budget (₹)',
            hintText: 'e.g. 3000',
            controller: _weeklyBudgetController,
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.view_week_rounded, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Monthly Budget (₹)',
            hintText: 'e.g. 12000',
            controller: _monthlyBudgetController,
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
          ),
          const SizedBox(height: 40),
          AppButton(
            label: 'Continue to Bank Selection',
            onPressed: () {
              final d = double.tryParse(_dailyBudgetController.text.trim());
              final w = double.tryParse(_weeklyBudgetController.text.trim());
              final m = double.tryParse(_monthlyBudgetController.text.trim());

              if (d == null || d <= 0 || w == null || w <= 0 || m == null || m <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid positive numbers for all budgets'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              _nextPage();
            },
          ),
        ],
      ),
    );
  }

  // STEP 4: Bank Selection
  Widget _buildBankStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Your Bank',
                style: AppTextStyles.heading1,
              ),
              const SizedBox(height: 8),
              Text(
                'Select the bank account you use for your expenses. SpendSmart will use this selection to identify relevant bank transaction SMS messages.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
            itemCount: _bankOptions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final bank = _bankOptions[index];
              final isSelected = _selectedBank == bank;
              return InkWell(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                onTap: () => setState(() => _selectedBank = bank),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withAlpha(20) : Colors.white,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_rounded,
                        color: isSelected ? AppColors.primary : AppColors.textMuted,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          bank,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppDimensions.space24),
          child: AppButton(
            label: 'Finish Setup',
            isLoading: _isLoading,
            onPressed: _submitOnboarding,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(20) : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.heading3.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
