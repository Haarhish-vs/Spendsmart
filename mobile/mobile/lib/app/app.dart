import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import 'routes/app_router.dart';
import 'routes/route_names.dart';
import 'theme/app_theme.dart';

class SpendSmartApp extends StatelessWidget {
  const SpendSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: RouteNames.splash,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
