import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../support.dart';

/// STATE-002: no app state in a singleton.
///
/// Deliberately conservative. In `lib/`, a `static` field of class `C` that
/// is not `const` and holds a `C` (declared type `C` or `C?`, or initialised
/// by constructing `C`, including `C._()` and `C.named()`) is reported when
/// any of these holds:
///
/// * it is not `final` (a mutable holder, as in `static C? _instance`);
/// * it is named like a singleton accessor (`instance`, `_instance`,
///   `shared`, `singleton`, with or without a leading underscore);
/// * `C` has a non-final, non-static instance field (mutable state).
///
/// Not reported: `const` fields, `static final empty = C()` on an immutable
/// value class, static fields of other types (a cache `Map`, a `Logger`), and
/// anything outside `lib/` or in generated files. Static fields holding some
/// other mutable object are out of scope: that needs data-flow analysis and
/// would produce false positives.
class NoStaticSingleton extends AnalysisRule {
  static const LintCode code = LintCode(
    'hl_no_static_singleton',
    'STATE-002: Static field "{0}" holds an instance of its own class, a '
        'singleton.',
    correctionMessage: 'Expose it through a Riverpod provider instead.',
    severity: DiagnosticSeverity.WARNING,
  );

  NoStaticSingleton()
    : super(
        name: 'hl_no_static_singleton',
        description: 'STATE-002: do not hold app state in a singleton.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!shouldAnalyse(context)) return;
    registry.addClassDeclaration(this, _Visitor(this));
  }
}

const _singletonNames = {'instance', 'shared', 'singleton'};

class _Visitor extends SimpleAstVisitor<void> {
  final NoStaticSingleton rule;

  _Visitor(this.rule);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final body = node.body;
    if (body is! BlockClassBody) return;
    final className = node.namePart.typeName.lexeme;
    final fields = body.members.whereType<FieldDeclaration>().toList();
    final hasMutableState = fields.any(
      (f) => !f.isStatic && !f.fields.isFinal && !f.fields.isConst,
    );
    for (final field in fields.where((f) => f.isStatic)) {
      for (final variable in field.fields.variables) {
        if (_isSingleton(field.fields, variable, className, hasMutableState)) {
          rule.reportAtToken(variable.name, arguments: [variable.name.lexeme]);
        }
      }
    }
  }

  bool _isSingleton(
    VariableDeclarationList list,
    VariableDeclaration variable,
    String className,
    bool classHasMutableState,
  ) {
    if (list.isConst) return false;
    if (!_holdsOwnClass(list, variable, className)) return false;
    final name = variable.name.lexeme.replaceFirst(RegExp('^_+'), '');
    return !list.isFinal ||
        _singletonNames.contains(name) ||
        classHasMutableState;
  }

  bool _holdsOwnClass(
    VariableDeclarationList list,
    VariableDeclaration variable,
    String className,
  ) {
    final type = list.type;
    if (type is NamedType && type.name.lexeme == className) return true;
    final init = variable.initializer;
    return init is InstanceCreationExpression &&
        init.constructorName.type.name.lexeme == className;
  }
}
