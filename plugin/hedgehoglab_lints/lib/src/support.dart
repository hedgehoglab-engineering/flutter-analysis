import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Files produced by code generation. Rules skip them: the author cannot act
/// on a diagnostic there.
bool isGeneratedFile(RuleContext context) {
  final path = context.currentUnit?.file.path ?? '';
  return path.endsWith('.g.dart') || path.endsWith('.freezed.dart');
}

/// Whether the rule should look at this file at all (`lib/`, hand-written).
bool shouldAnalyse(RuleContext context) =>
    context.isInLibDir && !isGeneratedFile(context);

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
