/// House limits for the metric rules. Change a limit here (one release for
/// every project) rather than per project. An exception is a justified
/// `// ignore:` that a human has approved (see the README).
abstract final class Limits {
  /// Source lines of code in one function or method body, widget `build`
  /// methods excepted.
  static const functionLines = 30;

  /// Source lines of code in a Flutter widget `build` method: a method named
  /// `build` whose declared return type is `Widget` or a subtype. Widget trees
  /// nest deeply by nature, so they keep the looser limit.
  static const widgetBuildLines = 50;

  /// McCabe cyclomatic complexity of one function or method.
  static const cyclomaticComplexity = 20;

  /// Depth of nested control structures (`if`, loops, `switch`, `try`).
  static const nesting = 5;

  /// Formal parameters (positional and named) of one function or method.
  static const parameters = 4;
}
