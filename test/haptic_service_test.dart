import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takt/services/haptic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HapticService', () {
    test('defaults to enabled and persists changes', () async {
      final service = HapticService();
      expect(service.enabled, isTrue);

      await service.setEnabled(false);
      expect(service.enabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('haptics_enabled_v1'), isFalse);

      await service.setEnabled(true);
      expect(service.enabled, isTrue);
    });

    test('static methods execute safely without error', () {
      expect(() => AppHaptics.light(), returnsNormally);
      expect(() => AppHaptics.selection(), returnsNormally);
      expect(() => AppHaptics.medium(), returnsNormally);
      expect(() => AppHaptics.heavy(), returnsNormally);
      expect(() => AppHaptics.success(), returnsNormally);
      expect(() => AppHaptics.error(), returnsNormally);
    });
  });
}
