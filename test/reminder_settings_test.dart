import 'package:flutter_test/flutter_test.dart';
import 'package:soma_app/models/reminder_settings.dart';

void main() {
  group('ReminderSettings & Smart Adaptive Throttling Tests', () {
    test('Default values are correctly configured', () {
      final settings = ReminderSettings();
      expect(settings.sedentaryEnabled, isTrue);
      expect(settings.sedentaryIntervalMinutes, 60);
      expect(settings.sedentaryStepThreshold, 20);
      expect(settings.sedentaryStartHour, 9);
      expect(settings.sedentaryEndHour, 21);
      expect(settings.hydrationEnabled, isTrue);
      expect(settings.hydrationIntervalMinutes, 90);
      expect(settings.continuousScreenTimeEnabled, isTrue);
      expect(settings.continuousScreenTimeLimitMinutes, 45);
      expect(settings.totalUnattendedCount, 0);
      expect(settings.isCircuitBreakerActive, isFalse);
    });

    test('Per-category lock prevents duplicate unattended reminders', () {
      final settings = ReminderSettings();

      expect(settings.canSendReminder('sedentary'), isTrue);
      settings.recordSent('sedentary');

      // Sedentary is now locked because it has not been acknowledged
      expect(settings.canSendReminder('sedentary'), isFalse);
      // Other categories can still be sent
      expect(settings.canSendReminder('hydration'), isTrue);
    });

    test('Global circuit breaker activates on 2 unattended alerts', () {
      final settings = ReminderSettings();

      settings.recordSent('sedentary');
      expect(settings.isCircuitBreakerActive, isFalse);

      settings.recordSent('hydration');
      // Now 2 unattended alerts
      expect(settings.totalUnattendedCount, 2);
      expect(settings.isCircuitBreakerActive, isTrue);

      // All categories should now be blocked
      expect(settings.canSendReminder('continuous_screen'), isFalse);
      expect(settings.canSendReminder('meal_nudge'), isFalse);
    });

    test('Acknowledge all resets locks and unpauses circuit breaker', () {
      final settings = ReminderSettings();

      settings.recordSent('sedentary');
      settings.recordSent('hydration');
      expect(settings.isCircuitBreakerActive, isTrue);

      settings.acknowledgeAll();
      expect(settings.totalUnattendedCount, 0);
      expect(settings.isCircuitBreakerActive, isFalse);
      expect(settings.canSendReminder('sedentary'), isTrue);
      expect(settings.canSendReminder('hydration'), isTrue);
    });

    test('Acknowledge single category decrements count and unblocks category', () {
      final settings = ReminderSettings();

      settings.recordSent('sedentary');
      expect(settings.canSendReminder('sedentary'), isFalse);

      settings.acknowledgeCategory('sedentary');
      expect(settings.totalUnattendedCount, 0);
      expect(settings.canSendReminder('sedentary'), isTrue);
    });

    test('Serialization to and from JSON preserves all settings and state', () {
      final settings = ReminderSettings(
        sedentaryIntervalMinutes: 45,
        hydrationIntervalMinutes: 120,
        continuousScreenTimeLimitMinutes: 30,
        totalUnattendedCount: 1,
        categoryPending: {'sedentary': true},
      );

      final encoded = settings.encode();
      final decoded = ReminderSettings.decode(encoded);

      expect(decoded.sedentaryIntervalMinutes, 45);
      expect(decoded.hydrationIntervalMinutes, 120);
      expect(decoded.continuousScreenTimeLimitMinutes, 30);
      expect(decoded.totalUnattendedCount, 1);
      expect(decoded.categoryPending['sedentary'], isTrue);
    });
  });
}
