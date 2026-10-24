import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/routes/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/app_storage.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  String _fullName = '';
  String _email = '';
  String _userId = '';
  String? _selectedBank;
  DateTime? _trackingStart;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final name = await AppStorage.getUserFullName() ?? 'SpendSmart User';
    final email = await AppStorage.getUserEmail() ?? '';
    final userId = await AppStorage.getUserId() ?? '';
    final bank = await AppStorage.getSelectedBank();
    final tracking = await AppStorage.getTrackingStartDate();

    if (mounted) {
      setState(() {
        _fullName = name;
        _email = email;
        _userId = userId;
        _selectedBank = bank;
        _trackingStart = tracking;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to sign out of SpendSmart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, RouteNames.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Account & Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.space20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // User Avatar & Name Card
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.space24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(60),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white.withAlpha(40),
                          child: Text(
                            _fullName.isNotEmpty ? _fullName[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _fullName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (_email.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _email,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withAlpha(200),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Account Configuration Card
                  const Text('Configuration & Settings', style: AppTextStyles.heading3),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.account_balance_rounded, color: AppColors.primary),
                          title: const Text('Selected Bank'),
                          subtitle: Text(_selectedBank ?? 'Not configured'),
                          trailing: const Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 20),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                          title: const Text('Tracking Start Date'),
                          subtitle: Text(
                            _trackingStart != null
                                ? dateFormat.format(_trackingStart!)
                                : 'All matching transactions',
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.tune_rounded, color: AppColors.primary),
                          title: const Text('Reconfigure Bank & Budgets'),
                          subtitle: const Text('Update salary, bank, or spending limits'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.pushNamed(context, RouteNames.onboarding);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Privacy & Data Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                      border: Border.all(color: AppColors.primary.withAlpha(40)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.security_rounded, color: AppColors.primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Private & Isolated Workspace',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your bank SMS debits, daily budgets, and FCM push notifications are cryptographically tied to your unique user identity.',
                                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Logout Button
                  AppButton(
                    label: 'Sign Out',
                    icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                    onPressed: _confirmLogout,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
