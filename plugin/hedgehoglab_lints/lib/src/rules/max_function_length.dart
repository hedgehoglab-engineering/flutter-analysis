import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../limits.dart';
import '../support.dart';

/// Metric: a function or method body has too many source lines of code (blank
/// and comment-only lines excluded). Flutter widget `build` methods (see
/// [isWidgetBuild]) are allowed [Limits.widgetBuildLines]; everything else,
/// including a Riverpod notifier's `build()`, [Limits.functionLines].
class MaxFunctionLength extends AnalysisRule {
  static const LintCode code = LintCode(
    'hl_max_function_length',
    'Function "{0}" has {1} lines of code, over the {3} limit of {2}.',
    correctionMessage: 'Extract part of the body into a well-named function.',
    severity: DiagnosticSeverity.WARNING,
  );

  MaxFunctionLength()
    : super(
        name: 'hl_max_function_length',
        description: 'Limits the source lines of code in a function.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!shouldAnalyse(context)) return;
    final visitor = _Visitor(this, context);
    registry
      ..addFunctionDeclaration(this, visitor)
      ..addMethodDeclaration(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final MaxFunctionLength rule;
  final RuleContext context;

  _Visitor(this.rule, this.context);

  @override
  void visitMethodDeclaration(MethodDeclaration node) =>
      _check(node.name, node.body, widgetBuild: isWidgetBuild(node));

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) =>
      _check(node.name, node.functionExpression.body, widgetBuild: false);

  void _check(Token name, FunctionBody body, {required bool widgetBuild}) {
    final unit = context.currentUnit?.unit;
    if (unit == null) return;
    final limit = widgetBuild ? Limits.widgetBuildLines : Limits.functionLines;
    final lines = sourceLinesOfCode(body, unit.lineInfo);
    if (lines > limit) {
      rule.reportAtToken(
        name,
        arguments: [
          name.lexeme,
          lines,
          limit,
          widgetBuild ? 'widget build' : 'function',
        ],
      );
    }
  }
}
