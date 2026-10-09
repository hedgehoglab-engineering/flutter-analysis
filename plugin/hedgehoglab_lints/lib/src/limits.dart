/// House limits for the metric rules. They match the defaults of
/// dart_code_linter so a team moving between the two sees the same numbers.
/// Change a limit here (one release for every project) rather than per
/// project; use `// ignore:` for a justified one-off.
abstract final class Limits {
  /// Source lines of code in one function or method body.
  static const functionLines = 50;

  /// McCabe cyclomatic complexity of one function or method.
  static const cyclomaticComplexity = 20;

  /// Depth of nested control structures (`if`, loops, `switch`, `try`).
  static const nesting = 5;

  /// Formal parameters (positional and named) of one function or method.
  static const parameters = 4;
}
