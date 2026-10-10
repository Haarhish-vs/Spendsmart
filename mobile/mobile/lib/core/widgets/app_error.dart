import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import 'app_button.dart';

class AppError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppError({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 48.0,
            ),
            const SizedBox(height: 16.0),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16.0),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16.0),
              AppButton(
                label: 'Retry',
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
