import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../limits.dart';
import '../support.dart';

/// Metric: McCabe cyclomatic complexity above [Limits.cyclomaticComplexity].
///
/// Counted as 1 plus each `if`, loop, `case` (not `default`), `catch`,
/// conditional expression, `&&`, `||` and `??` in the body, closures included.
class MaxCyclomaticComplexity extends AnalysisRule {
  static const LintCode code = LintCode(
    'hl_max_cyclomatic_complexity',
    'Function "{0}" has a cyclomatic complexity of {1}, over the limit of {2}.',
    correctionMessage: 'Split the branching into smaller functions.',
    severity: DiagnosticSeverity.WARNING,
  );

  MaxCyclomaticComplexity()
    : super(
        name: 'hl_max_cyclomatic_complexity',
        description: 'Limits the cyclomatic complexity of a function.',
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
  final MaxCyclomaticComplexity rule;

  _Visitor(this.rule);

  @override
  void onFunction(
    Token name,
    FunctionBody body,
    FormalParameterList? parameters,
    NodeList<Annotation> metadata,
  ) {
    final counter = _Counter();
    body.accept(counter);
    final complexity = counter.count + 1;
    if (complexity > Limits.cyclomaticComplexity) {
      rule.reportAtToken(
        name,
        arguments: [name.lexeme, complexity, Limits.cyclomaticComplexity],
      );
    }
  }
}

class _Counter extends RecursiveAstVisitor<void> {
  int count = 0;

  void _hit(AstNode node) {
    count++;
    node.visitChildren(this);
  }

  @override
  void visitIfStatement(IfStatement node) => _hit(node);

  @override
  void visitIfElement(IfElement node) => _hit(node);

  @override
  void visitForStatement(ForStatement node) => _hit(node);

  @override
  void visitForElement(ForElement node) => _hit(node);

  @override
  void visitWhileStatement(WhileStatement node) => _hit(node);

  @override
  void visitDoStatement(DoStatement node) => _hit(node);

  @override
  void visitSwitchCase(SwitchCase node) => _hit(node);

  @override
  void visitSwitchPatternCase(SwitchPatternCase node) => _hit(node);

  @override
  void visitSwitchExpressionCase(SwitchExpressionCase node) => _hit(node);

  @override
  void visitCatchClause(CatchClause node) => _hit(node);

  @override
  void visitConditionalExpression(ConditionalExpression node) => _hit(node);

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final type = node.operator.type;
    if (type == TokenType.AMPERSAND_AMPERSAND ||
        type == TokenType.BAR_BAR ||
        type == TokenType.QUESTION_QUESTION) {
      count++;
    }
    super.visitBinaryExpression(node);
  }
}
