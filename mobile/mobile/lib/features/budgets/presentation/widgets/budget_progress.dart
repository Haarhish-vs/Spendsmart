import 'package:flutter/material.dart';

class BudgetProgress extends StatelessWidget {
  final double progress;

  const BudgetProgress({
    super.key,
    this.progress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: progress.clamp(0.0, 1.0),
    );
  }
}
