import 'package:flutter/material.dart';
import '../../app/theme/app_dimensions.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: padding ?? const EdgeInsets.all(AppDimensions.space16),
      child: child,
    );

    if (onTap != null) {
      return Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          onTap: onTap,
          child: content,
        ),
      );
    }

    return Card(child: content);
  }
}
