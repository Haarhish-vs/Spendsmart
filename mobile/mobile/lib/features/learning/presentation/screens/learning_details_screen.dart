import 'package:flutter/material.dart';

class LearningDetailsScreen extends StatelessWidget {
  final String? resourceId;

  const LearningDetailsScreen({
    super.key,
    this.resourceId,
  });

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('SpendSmart Learning Resource Details'),
      ),
    );
  }
}
