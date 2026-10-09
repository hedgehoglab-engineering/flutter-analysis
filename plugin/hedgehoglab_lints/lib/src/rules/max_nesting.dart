import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../limits.dart';
import '../support.dart';

/// Metric: control structures (`if`, loops, `switch`, `try`) nested deeper than
/// [Limits.nesting]. An `else if` continues its chain and adds no depth.
class MaxNesting extends AnalysisRule {
  static const LintCode code = LintCode(
    'hl_max_nesting',
    'Function "{0}" nests control flow {1} levels deep, over the limit of {2}.',
    correctionMessage: 'Use early returns or extract the inner block.',
    severity: DiagnosticSeverity.WARNING,
  );

  MaxNesting()
    : super(
        name: 'hl_max_nesting',
        description: 'Limits the nesting depth of control flow.',
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
  final MaxNesting rule;

  _Visitor(this.rule);

  @override
  void onFunction(
    Token name,
    FunctionBody body,
    FormalParameterList? parameters,
    NodeList<Annotation> metadata,
  ) {
    final depth = _Depth();
    body.accept(depth);
    if (depth.max > Limits.nesting) {
      rule.reportAtToken(
        name,
        arguments: [name.lexeme, depth.max, Limits.nesting],
      );
    }
  }
}

class _Depth extends RecursiveAstVisitor<void> {
  int _current = 0;
  int max = 0;

  void _nest(AstNode node) {
    _current++;
    if (_current > max) max = _current;
    node.visitChildren(this);
    _current--;
  }

  @override
  void visitIfStatement(IfStatement node) {
    // Visit the else branch at this level so `else if` chains stay flat.
    _current++;
    if (_current > max) max = _current;
    node.expression.accept(this);
    node.thenStatement.accept(this);
    _current--;
    node.elseStatement?.accept(this);
  }

  @override
  void visitForStatement(ForStatement node) => _nest(node);

  @override
  void visitWhileStatement(WhileStatement node) => _nest(node);

  @override
  void visitDoStatement(DoStatement node) => _nest(node);

  @override
  void visitSwitchStatement(SwitchStatement node) => _nest(node);

  @override
  void visitTryStatement(TryStatement node) => _nest(node);
}
