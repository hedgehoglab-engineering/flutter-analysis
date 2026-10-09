import 'stubs.dart';

class _$CartNotifier {}

@riverpod
class CartNotifier extends _$CartNotifier {
  int build() => 0;

  Future<void> onSaveTapped() async {}

  void onClearTapped() {}
}

class Money {
  const Money(this.pence);

  final int pence;
  static const zero = Money(0);
}

int add(int a, int b) => a + b;
