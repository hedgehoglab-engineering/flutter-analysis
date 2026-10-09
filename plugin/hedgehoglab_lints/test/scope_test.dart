import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:hedgehoglab_lints/src/rules/max_parameters.dart';
import 'package:hedgehoglab_lints/src/support.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart' as t;
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  t.group('isOwnLibFile', () {
    final posix = p.posix;
    const root = '/work/app';

    t.test('accepts files under the package lib', () {
      t.expect(isOwnLibFile('/work/app/lib/a.dart', root, posix), t.isTrue);
      t.expect(isOwnLibFile('/work/app/lib/src/a.dart', root, posix), t.isTrue);
    });

    t.test('rejects test, bin and root-level files', () {
      t.expect(isOwnLibFile('/work/app/test/a.dart', root, posix), t.isFalse);
      t.expect(isOwnLibFile('/work/app/bin/a.dart', root, posix), t.isFalse);
      t.expect(isOwnLibFile('/work/app/a.dart', root, posix), t.isFalse);
    });

    t.test('rejects a lib directory nested elsewhere in the package', () {
      t.expect(
        isOwnLibFile('/work/app/example/lib/a.dart', root, posix),
        t.isFalse,
      );
      t.expect(
        isOwnLibFile(
          '/work/app/build/ios/SourcePackages/x-1.0.0/lib/a.dart',
          root,
          posix,
        ),
        t.isFalse,
      );
    });

    t.test('rejects build and .dart_tool below lib', () {
      t.expect(
        isOwnLibFile('/work/app/lib/build/a.dart', root, posix),
        t.isFalse,
      );
      t.expect(
        isOwnLibFile('/work/app/lib/.dart_tool/a.dart', root, posix),
        t.isFalse,
      );
    });

    t.test('a build directory above the root does not matter', () {
      t.expect(
        isOwnLibFile('/build/app/lib/a.dart', '/build/app', posix),
        t.isTrue,
      );
    });

    t.group('isBuildOutput', () {
      bool Function(String) pubspecIn(Set<String> dirs) => dirs.contains;

      t.test('a package nested in build/ of another package', () {
        t.expect(
          isBuildOutput(
            '/work/app/build/ios/SourcePackages/x-1.0.0',
            posix,
            pubspecIn({'/work/app'}),
          ),
          t.isTrue,
        );
      });

      t.test('a package nested in .dart_tool/ of another package', () {
        t.expect(
          isBuildOutput(
            '/work/app/.dart_tool/x',
            posix,
            pubspecIn({'/work/app'}),
          ),
          t.isTrue,
        );
      });

      t.test('a project that merely lives under a build directory', () {
        t.expect(
          isBuildOutput('/build/app', posix, pubspecIn({'/build/app'})),
          t.isFalse,
        );
        t.expect(
          isBuildOutput('/work/build/app', posix, pubspecIn({})),
          t.isFalse,
        );
      });

      t.test('an ordinary package', () {
        t.expect(
          isBuildOutput('/work/app', posix, pubspecIn({'/work/app'})),
          t.isFalse,
        );
      });
    });

    t.test('rejects files outside the root', () {
      t.expect(isOwnLibFile('/other/lib/a.dart', root, posix), t.isFalse);
      t.expect(isOwnLibFile('/work/app2/lib/a.dart', root, posix), t.isFalse);
    });
  });

  defineReflectiveSuite(() {
    defineReflectiveTests(ScopeTest);
  });
}

const _tooManyParameters = 'void f(int a, int b, int c, int d, int e) {}\n';

/// The rule must report in the package's own `lib/` and nowhere else. The
/// nested cases reproduce a Swift Package Manager checkout under `build/`,
/// which holds a complete `lib/` of someone else's package.
@reflectiveTest
class ScopeTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = MaxParameters();
    super.setUp();
  }

  String get _spm =>
      '$testPackageRootPath/build/ios/SourcePackages/firebase_analytics-12.6.0';

  Future<void> test_ownLibIsAnalysed() async {
    final path = '$testPackageLibPath/own.dart';
    newFile(path, _tooManyParameters);
    await assertDiagnosticsInFile(path, [lint(5, 1)]);
  }

  Future<void> test_nestedBuildLibIsSkipped() async {
    final path = '$_spm/lib/src/nested.dart';
    newFile(path, _tooManyParameters);
    await assertNoDiagnosticsInFile(path);
  }

  Future<void> test_nestedBuildLibWithOwnPubspecIsSkipped() async {
    newFile('$_spm/pubspec.yaml', 'name: firebase_analytics\n');
    final path = '$_spm/lib/src/nested.dart';
    newFile(path, _tooManyParameters);
    await assertNoDiagnosticsInFile(path);
  }

  Future<void> test_generatedFilesAreSkipped() async {
    final path = '$testPackageLibPath/model.g.dart';
    newFile(path, _tooManyParameters);
    await assertNoDiagnosticsInFile(path);
  }
}
