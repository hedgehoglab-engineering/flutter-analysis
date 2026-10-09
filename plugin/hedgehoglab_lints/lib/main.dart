import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules/max_cyclomatic_complexity.dart';
import 'src/rules/max_function_length.dart';
import 'src/rules/max_nesting.dart';
import 'src/rules/max_parameters.dart';
import 'src/rules/no_static_singleton.dart';
import 'src/rules/notifier_suffix.dart';
import 'src/rules/notifier_void_methods.dart';

/// Entry point discovered by the analysis server from `plugins:` in
/// `analysis_options.yaml`.
final plugin = HedgehogLabLintsPlugin();

/// Registers every hedgehog lab rule as a warning rule, so each is enabled as
/// soon as the plugin is, with no per-rule `diagnostics:` entry needed.
class HedgehogLabLintsPlugin extends Plugin {
  @override
  String get name => 'hedgehoglab_lints';

  @override
  void register(PluginRegistry registry) {
    registry
      ..registerWarningRule(NotifierSuffix())
      ..registerWarningRule(NotifierVoidMethods())
      ..registerWarningRule(NoStaticSingleton())
      ..registerWarningRule(MaxFunctionLength())
      ..registerWarningRule(MaxCyclomaticComplexity())
      ..registerWarningRule(MaxNesting())
      ..registerWarningRule(MaxParameters());
  }
}
