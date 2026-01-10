import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_reader/core/services/notifications/local_notification_service.dart';

final localNotificationServiceProvider = Provider<LocalNotificationService>((ref) {
  return LocalNotificationService();
});
