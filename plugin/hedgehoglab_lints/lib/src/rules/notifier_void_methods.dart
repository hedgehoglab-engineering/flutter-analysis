import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../support.dart';

/// STATE-007: public methods on a Riverpod notifier must not return a value.
///
/// The view reads `state`; a return value is a second source of truth.
/// Exempt: `build` (it returns the initial state by contract), `@override`
/// members, static members, getters, setters and operators. A method with no
/// declared return type is not reported (`always_declare_return_types` covers
/// that).
class NotifierVoidMethods extends AnalysisRule {
  static const LintCode code = LintCode(
    'hl_notifier_void_methods',
    'STATE-007: Public notifier method "{0}" must return void or '
        'Future<void>, not "{1}".',
    correctionMessage: 'Put the outcome in state and return nothing.',
    severity: DiagnosticSeverity.WARNING,
  );

  NotifierVoidMethods()
    : super(
        name: 'hl_notifier_void_methods',
        description: 'STATE-007: public notifier methods return no value.',
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
  final NotifierVoidMethods rule;

  _Visitor(this.rule);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (!isRiverpodNotifier(node)) return;
    final body = node.body;
    if (body is! BlockClassBody) return;
    for (final member in body.members) {
      if (member is MethodDeclaration) _check(member);
    }
  }

  void _check(MethodDeclaration method) {
    final name = method.name.lexeme;
    if (name.startsWith('_') ||
        name == 'build' ||
        method.isStatic ||
        method.isGetter ||
        method.isSetter ||
        method.isOperator ||
        hasAnnotation(method.metadata, 'override')) {
      return;
    }
    final declared = method.returnType;
    if (declared == null) return;
    final type = declared.type;
    if (type == null || _returnsNothing(type)) return;
    rule.reportAtToken(method.name, arguments: [name, type.getDisplayString()]);
  }

  /// `void`, `Future<void>` or `FutureOr<void>`.
  bool _returnsNothing(DartType type) {
    if (type is VoidType) return true;
    if (type is InterfaceType &&
        (type.isDartAsyncFuture || type.isDartAsyncFutureOr)) {
      return type.typeArguments.single is VoidType;
    }
    return false;
  }
}
