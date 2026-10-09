import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart';

import '../limits.dart';
import '../support.dart';

/// Metric: a function or method declares more than [Limits.parameters]
/// parameters. Constructors are not measured (widgets legitimately take many
/// named arguments) and neither are `@override` members, whose signature is
/// dictated by the supertype.
class MaxParameters extends AnalysisRule {
  static const LintCode code = LintCode(
    'hl_max_parameters',
    'Function "{0}" has {1} parameters, over the limit of {2}.',
    correctionMessage: 'Group related parameters into an object.',
    severity: DiagnosticSeverity.WARNING,
  );

  MaxParameters()
    : super(
        name: 'hl_max_parameters',
        description: 'Limits the number of parameters of a function.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!shouldAnalyse(context)) return;
    registerFunctionVisitor(registry, this, _Visitor(this));
  }
}

class _Visitor extends FunctionVisitor {
  final MaxParameters rule;

  _Visitor(this.rule);

  @override
  void onFunction(
    Token name,
    FunctionBody body,
    FormalParameterList? parameters,
    NodeList<Annotation> metadata,
  ) {
    if (parameters == null || hasAnnotation(metadata, 'override')) return;
    final count = parameters.parameters.length;
    if (count > Limits.parameters) {
      rule.reportAtToken(
        name,
        arguments: [name.lexeme, count, Limits.parameters],
      );
    }
  }
}
