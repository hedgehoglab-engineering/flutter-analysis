import 'stubs.dart';

class _$CartController {}

class _$CartNotifier {}

// STATE-005: notifier not suffixed `Notifier`.
@riverpod
class CartController extends _$CartController {}

// STATE-007: public notifier method returns a value.
@riverpod
class SavedCartNotifier extends _$CartNotifier {
  Future<bool> onSaveTapped() async => true;
}

// STATE-002: static singleton.
class SettingsStore {
  static final instance = SettingsStore();
  final String name = 'settings';
}

// Metric: too many parameters (limit 4).
int sum(int a, int b, int c, int d, int e) => a + b + c + d + e;

// Metric: nesting too deep (limit 5).
void deep(bool a) {
  if (a) {
    if (a) {
      if (a) {
        if (a) {
          if (a) {
            if (a) {
              print('deep');
            }
          }
        }
      }
    }
  }
}
