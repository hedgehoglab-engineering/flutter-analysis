import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../support.dart';

/// STATE-005: a class extending a generated Riverpod notifier base
/// (`_$Something`, from `@riverpod`) must be named with the `Notifier` suffix.
///
/// Riverpod strips the suffix when generating the provider, so any other name
/// makes the generated provider name unpredictable.
class NotifierSuffix extends AnalysisRule {
  static const LintCode code = LintCode(
    'hl_notifier_suffix',
    'STATE-005: Notifier class "{0}" must be named with the "Notifier" suffix.',
    correctionMessage: 'Rename it to "{0}Notifier" (see standards 04).',
    severity: DiagnosticSeverity.WARNING,
  );

  NotifierSuffix()
    : super(
        name: 'hl_notifier_suffix',
        description: 'STATE-005: suffix Riverpod notifier classes Notifier.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (isGeneratedFile(context)) return;
    registry.addClassDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final NotifierSuffix rule;

  _Visitor(this.rule);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (!isRiverpodNotifier(node)) return;
    final name = node.namePart.typeName;
    if (!name.lexeme.endsWith('Notifier')) {
      rule.reportAtToken(name, arguments: [name.lexeme]);
    }
  }
}
