import 'package:flutter/material.dart';
import '../../features/ai_plan/presentation/screens/ai_plan_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/budgets/presentation/screens/budgets_screen.dart';
import '../../features/budgets/presentation/screens/create_budget_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/learning/presentation/screens/learning_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/transactions/presentation/screens/add_edit_transaction_screen.dart';
import '../../features/transactions/presentation/screens/transactions_screen.dart';
import 'route_names.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case RouteNames.onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case RouteNames.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case RouteNames.register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case RouteNames.home:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case RouteNames.transactions:
        return MaterialPageRoute(builder: (_) => const TransactionsScreen());
      case RouteNames.addTransaction:
        return MaterialPageRoute(builder: (_) => const AddEditTransactionScreen());
      case RouteNames.budgets:
        return MaterialPageRoute(builder: (_) => const BudgetsScreen());
      case RouteNames.createBudget:
        return MaterialPageRoute(builder: (_) => const CreateBudgetScreen());
      case RouteNames.analytics:
        return MaterialPageRoute(builder: (_) => const AnalyticsScreen());
      case RouteNames.aiPlan:
        return MaterialPageRoute(builder: (_) => const AiPlanScreen());
      case RouteNames.learning:
        return MaterialPageRoute(builder: (_) => const LearningScreen());
      case RouteNames.notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());
      case RouteNames.profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
