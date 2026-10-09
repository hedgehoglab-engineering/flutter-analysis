import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:hedgehoglab_lints/src/rules/no_static_singleton.dart';
import 'package:hedgehoglab_lints/src/rules/notifier_suffix.dart';
import 'package:hedgehoglab_lints/src/rules/notifier_void_methods.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'test_support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NotifierSuffixTest);
    defineReflectiveTests(NotifierVoidMethodsTest);
    defineReflectiveTests(NoStaticSingletonTest);
  });
}

@reflectiveTest
class NotifierSuffixTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = NotifierSuffix();
    super.setUp();
  }

  Future<void> test_missingSuffix() async {
    const code =
        '''
$riverpodStub
@riverpod
class CartController extends _\$CartController {}
''';
    await assertDiagnostics(code, [
      lint(
        at(code, 'CartController extends'),
        'CartController'.length,
        messageContainsAll: ['STATE-005'],
      ),
    ]);
  }

  Future<void> test_withSuffix() async {
    await assertNoDiagnostics('''
$riverpodStub
@riverpod
class CartNotifier extends _\$CartNotifier {}
''');
  }

  Future<void> test_keepAliveAnnotationIsRecognised() async {
    const code =
        '''
$riverpodStub
@Riverpod(keepAlive: true)
class CartController extends _\$CartController {}
''';
    await assertDiagnostics(code, [
      lint(at(code, 'CartController extends'), 'CartController'.length),
    ]);
  }

  /// Edge: without `@riverpod` the class is not a generated notifier, so its
  /// name is not this rule's business even though the base starts with `_$`.
  Future<void> test_notAnnotatedIsIgnored() async {
    await assertNoDiagnostics('''
$riverpodStub
class CartController extends _\$CartController {}
''');
  }

  /// Edge: an ordinary subclass of a normal class is never touched.
  Future<void> test_ordinaryClassIsIgnored() async {
    await assertNoDiagnostics('''
class Base {}
class CartController extends Base {}
''');
  }
}

@reflectiveTest
class NotifierVoidMethodsTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = NotifierVoidMethods();
    super.setUp();
  }

  Future<void> test_returnsValue() async {
    const code =
        '''
$riverpodStub
@riverpod
class CartNotifier extends _\$CartNotifier {
  Future<bool> onSaveTapped() async => true;
  int onCountRequested() => 1;
}
''';
    await assertDiagnostics(code, [
      lint(
        at(code, 'onSaveTapped'),
        'onSaveTapped'.length,
        messageContainsAll: ['STATE-007', 'Future<bool>'],
      ),
      lint(at(code, 'onCountRequested'), 'onCountRequested'.length),
    ]);
  }

  Future<void> test_voidAndFutureVoidAreFine() async {
    await assertNoDiagnostics('''
import 'dart:async';
$riverpodStub
@riverpod
class CartNotifier extends _\$CartNotifier {
  void onClearTapped() {}
  Future<void> onSaveTapped() async {}
  FutureOr<void> onRefresh() {}
}
''');
  }

  /// Edge: everything the standard does not cover must stay quiet.
  Future<void> test_exemptMembers() async {
    await assertNoDiagnostics('''
$riverpodStub
@riverpod
class CartNotifier extends _\$CartNotifier {
  int build() => 0;
  int get total => 1;
  set total(int value) {}
  int _private() => 1;
  static int helper() => 1;
  @override
  String toString() => '';
  bool operator ==(Object other) => true;
  onUntyped() => 1;
}
''');
  }

  Future<void> test_nonNotifierClassIsIgnored() async {
    await assertNoDiagnostics('''
class Repo {
  Future<bool> save() async => true;
}
''');
  }
}

@reflectiveTest
class NoStaticSingletonTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = NoStaticSingleton();
    super.setUp();
  }

  Future<void> test_staticFinalInstance() async {
    const code = '''
class SettingsStore {
  static final instance = SettingsStore();
  final String name = 'a';
}
''';
    await assertDiagnostics(code, [
      lint(
        at(code, 'instance'),
        'instance'.length,
        messageContainsAll: ['STATE-002'],
      ),
    ]);
  }

  Future<void> test_lazyNullableHolder() async {
    const code = '''
class SettingsStore {
  static SettingsStore? _instance;
  SettingsStore._();
  factory SettingsStore() => _instance ??= SettingsStore._();
}
''';
    await assertDiagnostics(code, [
      lint(at(code, '_instance;'), '_instance'.length),
    ]);
  }

  Future<void> test_namedPrivateConstructorWithMutableState() async {
    const code = '''
class Cart {
  static final Cart _cart = Cart._();
  Cart._();
  int count = 0;
}
''';
    await assertDiagnostics(code, [lint(at(code, '_cart ='), '_cart'.length)]);
  }

  Future<void> test_constIsFine() async {
    await assertNoDiagnostics('''
class Spacing {
  const Spacing();
  static const standard = Spacing();
}
''');
  }

  /// Edge: an immutable value object with a shared default is not a
  /// singleton, and a static cache of another type is out of scope.
  Future<void> test_immutableDefaultAndOtherTypesAreFine() async {
    await assertNoDiagnostics('''
class Money {
  final int pence;
  Money(this.pence);
  static final zero = Money(0);
  static final Map<String, int> cache = {};
}
''');
  }

  Future<void> test_outsideLibIsIgnored() async {
    final path = '$testPackageTestPath/store_test.dart';
    newFile(path, '''
class Store {
  static final instance = Store();
}
''');
    await assertNoDiagnosticsInFile(path);
  }
}
