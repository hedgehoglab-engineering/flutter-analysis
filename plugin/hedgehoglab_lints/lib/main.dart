import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules.dart';

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
    for (final rule in allRules()) {
      registry.registerWarningRule(rule);
    }
  }
}
