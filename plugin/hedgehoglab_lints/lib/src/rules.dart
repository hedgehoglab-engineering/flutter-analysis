import 'package:analyzer/analysis_rule/analysis_rule.dart';

import 'rules/max_cyclomatic_complexity.dart';
import 'rules/max_function_length.dart';
import 'rules/max_nesting.dart';
import 'rules/max_parameters.dart';
import 'rules/no_static_singleton.dart';
import 'rules/notifier_suffix.dart';
import 'rules/notifier_void_methods.dart';

/// Every rule the plugin registers. `main.dart` registers from this list and
/// the tests check `standards.lock.json` against it, so a rule cannot be added
/// to one and forgotten in the other.
List<AnalysisRule> allRules() => [
  NotifierSuffix(),
  NotifierVoidMethods(),
  NoStaticSingleton(),
  MaxFunctionLength(),
  MaxCyclomaticComplexity(),
  MaxNesting(),
  MaxParameters(),
];
