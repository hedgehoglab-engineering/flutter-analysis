import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:hedgehoglab_lints/src/rules/max_cyclomatic_complexity.dart';
import 'package:hedgehoglab_lints/src/rules/max_function_length.dart';
import 'package:hedgehoglab_lints/src/rules/max_nesting.dart';
import 'package:hedgehoglab_lints/src/rules/max_parameters.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'test_support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MaxFunctionLengthTest);
    defineReflectiveTests(MaxCyclomaticComplexityTest);
    defineReflectiveTests(MaxNestingTest);
    defineReflectiveTests(MaxParametersTest);
  });
}

/// A function whose body has [lines] source lines including both braces.
String _functionOfLines(int lines) =>
    'void f() {\n${'  print(1);\n' * (lines - 2)}}\n';

@reflectiveTest
class MaxFunctionLengthTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = MaxFunctionLength();
    super.setUp();
  }

  Future<void> test_overLimit() async {
    final code = _functionOfLines(51);
    await assertDiagnostics(code, [
      lint(at(code, 'f()'), 1, messageContainsAll: ['51', '50']),
    ]);
  }

  Future<void> test_atLimit() async =>
      assertNoDiagnostics(_functionOfLines(50));

  /// Edge: blank lines and comments do not count towards the limit.
  Future<void> test_blankAndCommentLinesIgnored() async {
    final code =
        'void f() {\n${'  // note\n\n' * 40}${'  print(1);\n' * 48}}\n';
    await assertNoDiagnostics(code);
  }

  Future<void> test_methodsAreMeasured() async {
    final body = '  print(1);\n' * 50;
    final code = 'class A {\n  void run() {\n$body  }\n}\n';
    await assertDiagnostics(code, [lint(at(code, 'run'), 3)]);
  }
}

@reflectiveTest
class MaxCyclomaticComplexityTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = MaxCyclomaticComplexity();
    super.setUp();
  }

  String _ifs(int n) =>
      'void f(int a) {\n${'  if (a == 1) print(1);\n' * n}}\n';

  Future<void> test_overLimit() async {
    final code = _ifs(20); // 1 + 20 = 21
    await assertDiagnostics(code, [
      lint(at(code, 'f('), 1, messageContainsAll: ['21', '20']),
    ]);
  }

  Future<void> test_atLimit() async => assertNoDiagnostics(_ifs(19));

  /// `&&`, `||`, `??`, `?:`, `case` and `catch` each add a path; `default`
  /// does not. Base complexity here is 1 + 4 operators + 12 cases + catch = 18.
  String _mixed(int extraIfs) =>
      '''
int f(int a, int? b, bool c) {
  var x = a > 0 && c || b != null ? 1 : 2;
  x += b ?? 0;
  switch (a) {
${List.generate(12, (i) => '    case $i:').join('\n')}
      x++;
    default:
      x--;
  }
  try {
    x++;
  } catch (e) {
    x--;
  }
${'  if (c) x++;\n' * extraIfs}  return x;
}
''';

  Future<void> test_operatorsAndCasesCount_underLimit() async =>
      assertNoDiagnostics(_mixed(2)); // 20

  Future<void> test_operatorsAndCasesCount_overLimit() async {
    final code = _mixed(3); // 21
    await assertDiagnostics(code, [lint(at(code, 'f('), 1)]);
  }
}

@reflectiveTest
class MaxNestingTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = MaxNesting();
    super.setUp();
  }

  String _nested(int depth) {
    final open = List.generate(depth, (_) => 'if (a) {').join('\n');
    return 'void f(bool a) {\n$open\nprint(1);\n${'}\n' * depth}}\n';
  }

  Future<void> test_overLimit() async {
    final code = _nested(6);
    await assertDiagnostics(code, [
      lint(at(code, 'f('), 1, messageContainsAll: ['6', '5']),
    ]);
  }

  Future<void> test_atLimit() async => assertNoDiagnostics(_nested(5));

  /// Edge: a long `else if` chain is flat, and sequential blocks do not add.
  Future<void> test_elseIfChainIsFlat() async {
    final chain = List.generate(10, (i) => 'if (a == $i) {}').join(' else ');
    await assertNoDiagnostics('void f(int a) {\n$chain\n}\n');
  }

  Future<void> test_loopsSwitchAndTryNest() async {
    const code = '''
void f(List<int> xs, bool a) {
  for (final x in xs) {
    while (a) {
      try {
        switch (x) {
          case 1:
            if (a) {
              do {} while (a);
            }
        }
      } catch (_) {}
    }
  }
}
''';
    await assertDiagnostics(code, [lint(at(code, 'f('), 1)]);
  }
}

@reflectiveTest
class MaxParametersTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = MaxParameters();
    super.setUp();
  }

  Future<void> test_overLimit() async {
    const code = 'void f(int a, int b, int c, int d, int e) {}\n';
    await assertDiagnostics(code, [
      lint(at(code, 'f('), 1, messageContainsAll: ['5', '4']),
    ]);
  }

  Future<void> test_atLimit() async =>
      assertNoDiagnostics('void f(int a, int b, int c, int d) {}\n');

  /// Edge: named parameters count towards the limit.
  Future<void> test_namedParametersCount() async {
    const code =
        'void f({int a = 0, int b = 0, int c = 0, int d = 0, '
        'int e = 0}) {}\n';
    await assertDiagnostics(code, [lint(at(code, 'f('), 1)]);
  }

  /// Edge: constructors and `@override` members are not measured.
  Future<void> test_constructorsAndOverridesAreExempt() async {
    // Only the declaration of `run` on Base is reported.
    const code = '''
class Base {
  void run(int a, int b, int c, int d, int e) {}
}
class Widget extends Base {
  Widget(int a, int b, int c, int d, int e);
  @override
  void run(int a, int b, int c, int d, int e) {}
}
''';
    await assertDiagnostics(code, [lint(at(code, 'run'), 3)]);
  }

  Future<void> test_notAppliedOutsideLib() async {
    final path = '$testPackageTestPath/a_test.dart';
    newFile(path, 'void f(int a, int b, int c, int d, int e) {}\n');
    await assertNoDiagnosticsInFile(path);
  }
}
