import 'package:flutter/material.dart';
import '../../app/theme/app_dimensions.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: AppDimensions.buttonHeight,
        child: Center(
          child: CircularProgressIndicator.adaptive(),
        ),
      );
    }

    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon!,
        label: Text(label),
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
