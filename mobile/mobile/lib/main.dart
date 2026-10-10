import 'package:flutter/material.dart';
import 'app/app.dart';
import 'features/notifications/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.initialize();
  runApp(const SpendSmartApp());
}
