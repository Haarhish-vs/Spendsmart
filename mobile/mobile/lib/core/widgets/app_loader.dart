import 'package:flutter/material.dart';

class AppLoader extends StatelessWidget {
  final String? message;

  const AppLoader({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator.adaptive(),
          if (message != null) ...[
            const SizedBox(height: 16.0),
            Text(message!),
          ],
        ],
      ),
    );
  }
}
