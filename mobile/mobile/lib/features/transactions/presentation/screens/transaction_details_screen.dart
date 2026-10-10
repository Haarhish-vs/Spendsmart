import 'package:flutter/material.dart';

class TransactionDetailsScreen extends StatelessWidget {
  final String? transactionId;

  const TransactionDetailsScreen({
    super.key,
    this.transactionId,
  });

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('SpendSmart Transaction Details'),
      ),
    );
  }
}
