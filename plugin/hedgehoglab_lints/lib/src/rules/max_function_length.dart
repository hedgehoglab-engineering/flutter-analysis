import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart';

import '../limits.dart';
import '../support.dart';

/// Metric: a function or method body has more than [Limits.functionLines]
/// source lines of code (blank and comment-only lines excluded).
class MaxFunctionLength extends AnalysisRule {
  static const LintCode code = LintCode(
    'hl_max_function_length',
    'Function "{0}" has {1} lines of code, over the limit of {2}.',
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
    registerFunctionVisitor(registry, this, _Visitor(this, context));
  }
}

class _Visitor extends FunctionVisitor {
  final MaxFunctionLength rule;
  final RuleContext context;

  _Visitor(this.rule, this.context);

  @override
  void onFunction(
    Token name,
    FunctionBody body,
    FormalParameterList? parameters,
    NodeList<Annotation> metadata,
  ) {
    final unit = context.currentUnit?.unit;
    if (unit == null) return;
    final lines = sourceLinesOfCode(body, unit.lineInfo);
    if (lines > Limits.functionLines) {
      rule.reportAtToken(
        name,
        arguments: [name.lexeme, lines, Limits.functionLines],
      );
    }
  }
}
