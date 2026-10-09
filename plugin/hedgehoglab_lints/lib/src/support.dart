import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as p;

/// Files produced by code generation. Rules skip them: the author cannot act
/// on a diagnostic there. Reads the defining unit because `currentUnit` is
/// `null` while node processors are being registered.
bool isGeneratedFile(RuleContext context) {
  final path = context.definingUnit.file.path;
  return path.endsWith('.g.dart') || path.endsWith('.freezed.dart');
}

/// Whether the rule should look at this file at all: hand-written, under the
/// analysed package's own `lib/`.
///
/// `RuleContext.isInLibDir` is not enough. It accepts any path with a `lib`
/// segment, so a Swift Package Manager checkout such as
/// `build/ios/SourcePackages/firebase_analytics-12.6.0/lib/` was analysed
/// whenever `build/` was not excluded. Here the path is resolved against the
/// package root, so only `<root>/lib/**` qualifies, and anything under a
/// `build/` or `.dart_tool/` directory (including one that holds its own
/// `lib/`) is skipped.
bool shouldAnalyse(RuleContext context) {
  if (isGeneratedFile(context)) return false;
  final file = context.definingUnit.file;
  final root = context.package?.root.path;
  if (root == null) return false;
  final pathContext = file.provider.pathContext;
  return isOwnLibFile(file.path, root, pathContext) &&
      !isBuildOutput(
        root,
        pathContext,
        (dir) =>
            file.provider.getFile(pathContext.join(dir, 'pubspec.yaml')).exists,
      );
}

/// Whether the package at [root] lives inside another package's `build/` or
/// `.dart_tool/` directory, which is where checkouts such as Swift Package
/// Manager sources land. Such a package has a `pubspec.yaml` of its own, so
/// the analyzer treats it as the package and [isOwnLibFile] alone would accept
/// its `lib/`. [hasPubspec] says whether a directory holds a `pubspec.yaml`.
bool isBuildOutput(
  String root,
  p.Context pathContext,
  bool Function(String directory) hasPubspec,
) {
  var dir = root;
  while (true) {
    final parent = pathContext.dirname(dir);
    if (parent == dir) return false;
    final name = pathContext.basename(dir);
    if ((name == 'build' || name == '.dart_tool') && hasPubspec(parent)) {
      return true;
    }
    dir = parent;
  }
}

/// Whether [path] is a hand-written source under `<[root]>/lib/` and not under
/// a `build/` or `.dart_tool/` directory at any depth below the root.
bool isOwnLibFile(String path, String root, p.Context pathContext) {
  if (!pathContext.isWithin(root, path)) return false;
  final segments = pathContext.split(pathContext.relative(path, from: root));
  if (segments.first != 'lib') return false;
  return !segments.any((s) => s == 'build' || s == '.dart_tool');
}

/// The last identifier of an annotation name: `riverpod` for `@riverpod`,
/// `@r.riverpod` and `@Riverpod(keepAlive: true)` (as `Riverpod`).
String annotationName(Annotation annotation) {
  final name = annotation.name;
  return name is PrefixedIdentifier ? name.identifier.name : name.name;
}

bool hasAnnotation(NodeList<Annotation> metadata, String name) =>
    metadata.any((a) => annotationName(a) == name);

/// A class annotated `@riverpod`/`@Riverpod(...)` that extends the generated
/// base `_$Something`. Detected syntactically so it works before code
/// generation has run, when `_$Something` does not resolve yet.
bool isRiverpodNotifier(ClassDeclaration node) {
  final superclass = node.extendsClause?.superclass.name.lexeme;
  if (superclass == null || !superclass.startsWith(r'_$')) return false;
  return hasAnnotation(node.metadata, 'riverpod') ||
      hasAnnotation(node.metadata, 'Riverpod');
}

/// Number of distinct source lines in [node] that carry code. Blank lines and
/// comment-only lines do not count.
int sourceLinesOfCode(AstNode node, LineInfo lines) {
  final seen = <int>{};
  for (var t = node.beginToken; !t.isEof; t = t.next!) {
    final first = lines.getLocation(t.offset).lineNumber;
    final last = lines
        .getLocation(t.end > t.offset ? t.end - 1 : t.offset)
        .lineNumber;
    for (var l = first; l <= last; l++) {
      seen.add(l);
    }
    if (t == node.endToken) break;
  }
  return seen.length;
}

/// Visits every named function and method, the units the metric rules measure.
abstract class FunctionVisitor extends SimpleAstVisitor<void> {
  /// Called for each top-level function, local function and method.
  void onFunction(
    Token name,
    FunctionBody body,
    FormalParameterList? parameters,
    NodeList<Annotation> metadata,
  );

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) => onFunction(
    node.name,
    node.functionExpression.body,
    node.functionExpression.parameters,
    node.metadata,
  );

  @override
  void visitMethodDeclaration(MethodDeclaration node) =>
      onFunction(node.name, node.body, node.parameters, node.metadata);
}

/// Registers [visitor] for all named functions and methods.
void registerFunctionVisitor(
  RuleVisitorRegistry registry,
  AbstractAnalysisRule rule,
  FunctionVisitor visitor,
) {
  registry
    ..addFunctionDeclaration(rule, visitor)
    ..addMethodDeclaration(rule, visitor);
}

/// Whether [node] is a Flutter widget `build` method: named `build`, an
/// instance method, with a resolved return type of `Widget` (from
/// `package:flutter`) or a subtype. This covers `StatelessWidget`, `State` and
/// `ConsumerWidget` builds. A Riverpod notifier's `build()` returns state, not a
/// widget, so it is not one.
bool isWidgetBuild(MethodDeclaration node) {
  if (node.name.lexeme != 'build' || node.isStatic) return false;
  final returnType = node.declaredFragment?.element.returnType;
  if (returnType is! InterfaceType) return false;
  return [returnType, ...returnType.allSupertypes].any(_isFlutterWidget);
}

bool _isFlutterWidget(InterfaceType type) {
  final element = type.element;
  return element.name == 'Widget' &&
      element.library.uri.toString().startsWith('package:flutter/');
}
