import 'package:flutter/material.dart';
import '../../models/budget_model.dart';

class BudgetStatusBadge extends StatelessWidget {
  final BudgetStatus status;

  const BudgetStatusBadge({
    super.key,
    this.status = BudgetStatus.normal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold),
      ),
    );
  }
}
