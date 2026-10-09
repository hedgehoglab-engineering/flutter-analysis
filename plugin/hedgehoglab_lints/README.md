# hedgehoglab_lints

An analyzer plugin that enforces hedgehog lab Flutter standards and code-metric limits from `dart analyze`. It costs nothing until a rule is violated, which makes it the cheapest layer to hold a standard at: a developer or coding agent sees the warning in the editor or in CI and fixes it, with no prose in context and no review round trip.

It is built on the `analysis_server_plugin` API (Dart 3.10 / Flutter 3.38 and later; developed against Dart 3.13 / Flutter 3.47), the same system `riverpod_lint` 3 uses. It is separate from the root `netsells_flutter_analysis` lint set and needs nothing from it.

## Rules

All rules are warnings, are enabled as soon as the plugin is, and apply to hand-written files under `lib/` (generated `*.g.dart` and `*.freezed.dart` files are skipped). Standards IDs refer to [standards/04-state-management.md](https://github.com/hedgehoglab-engineering/flutter-standards/blob/main/standards/04-state-management.md); the source does not print numeric IDs, so `STATE-nnn` is the rule's position in that file (001 generate with `@riverpod`, 002 no singletons, 003 `keepAlive`, 004 file grouping, 005 suffix, 006 method naming, 007 void returns).

| Rule | Standard | Reports |
|---|---|---|
| `hl_notifier_suffix` | STATE-005 | A `@riverpod` class extending a generated `_$Name` base whose name does not end in `Notifier`. |
| `hl_notifier_void_methods` | STATE-007 | A public method on such a class declared to return anything other than `void`, `Future<void>` or `FutureOr<void>`. Exempt: `build`, `@override`, static, private, getters, setters, operators, and methods with no declared return type. |
| `hl_no_static_singleton` | STATE-002 | A non-`const` static field that holds an instance of its own class, when it is not `final`, is named `instance`/`shared`/`singleton` (leading underscore allowed), or the class has mutable instance fields. |
| `hl_max_function_length` | metric | More than 50 source lines of code in a function or method (blank and comment-only lines excluded). |
| `hl_max_cyclomatic_complexity` | metric | Cyclomatic complexity above 20: 1 plus each `if`, loop, `case`, `catch`, `?:`, `&&`, `||`, `??`. |
| `hl_max_nesting` | metric | Control flow (`if`, loops, `switch`, `try`) nested more than 5 deep. `else if` does not add depth. |
| `hl_max_parameters` | metric | More than 4 parameters, positional or named. Constructors and `@override` members are not measured. |

STATE-005 and STATE-007 match syntactically (`@riverpod` or `@Riverpod(...)` plus `extends _$Name`), so they work before `build_runner` has run. STATE-002 is deliberately conservative: it only looks at a field whose own type is the enclosing class, so a static `Map` cache, a `const` value, or `static final zero = Money(0)` on an immutable class is not reported. A static field holding some other mutable object would need data-flow analysis and is out of scope. Metric limits are constants in `lib/src/limits.dart` and match the `dart_code_linter` defaults; they are not per-project options (the plugin API has no structured rule configuration, only on/off). Use `// ignore: hl_max_parameters` for a justified exception.

### Why the metrics are our own

`dart_code_linter` 4.4.2 (MIT) does run as a new-style plugin on Dart 3.13, and its metric thresholds are configurable. But the plugin only exposes its lint rules: cyclomatic complexity, nesting, parameters and source lines are reachable only through its own CLI (`dart run dart_code_linter:metrics analyze lib`), not through `dart analyze`. Under `dart analyze` it reported none of them on a function that breaks every limit. That puts them outside the "enforced by the analyzer, zero tokens" path, so the four equivalents here are minimal reimplementations. `dart_code_linter`'s rules can still be enabled alongside this plugin (it is a second `plugins:` entry with its own `version:`).

## Enabling it

In the consuming project's `pubspec.yaml` nothing is needed; the analysis server resolves the plugin itself. Add to `analysis_options.yaml`:

```yaml
plugins:
  hedgehoglab_lints:
    git:
      url: https://github.com/hedgehoglab-engineering/flutter-analysis
      path: plugin/hedgehoglab_lints
      ref: hedgehoglab_lints-v0.1.0
```

For local development use `path: /absolute/or/relative/path/to/hedgehoglab_lints` instead of `git:` (see `example/analysis_options.yaml`). Restart the Dart analysis server after changing the `plugins:` section. The first run resolves the plugin's dependencies and takes about 20 seconds; later runs are fast.

Rules are warning rules, so they are on by default. To switch one off in a project:

```yaml
plugins:
  hedgehoglab_lints:
    git: {...}
    diagnostics:
      hl_max_parameters: false
```

### Observed behaviour on Dart 3.13 / Flutter 3.47

* **Plugins in an `include:`d file are honoured by `dart analyze`.** The upstream docs say plugins cannot be configured in a nested options file, but a `plugins:` section in a file pulled in with `include: package:shared/analysis_options.yaml` was applied (five of five expected warnings, against none with the include removed). Plugin lists from the include and from the project's own file merge, and a project can switch a rule off with `diagnostics:` in its own file. Because the docs say otherwise this is undocumented behaviour that could change, so the safe adoption pattern is to put the `plugins:` block in each project's own `analysis_options.yaml`; sharing it through an include is a convenience to re-verify on each Flutter upgrade.
* **`flutter analyze` is unreliable with plugins on 3.47.0.** It runs the language server and returns before plugin diagnostics arrive. Over six runs on the same project it showed the plugin warnings in three and none in three (the same happens with `dart_code_linter`), while `dart analyze` showed all of them in four of four. Gate CI and agent checks on `dart analyze`; treat `flutter analyze` output as incomplete.

### With riverpod_lint

A project like bnf-flutter that has `riverpod_lint` in `dev_dependencies` but does not enable it needs it listed as a plugin too (the dependency alone does nothing in the new system, and `custom_lint` is no longer involved):

```yaml
plugins:
  riverpod_lint: ^3.1.9
  hedgehoglab_lints:
    git:
      url: https://github.com/hedgehoglab-engineering/flutter-analysis
      path: plugin/hedgehoglab_lints
      ref: hedgehoglab_lints-v0.1.0
```

Both loaded together in a test project. The `riverpod_lint` entry in `dev_dependencies` can be dropped once it is listed here.

## Versioning

The plugin has its own version in `pubspec.yaml`, independent of the root package. Release by tagging `hedgehoglab_lints-vX.Y.Z`; projects pin that tag in `ref:`. New rules are warnings, so adding one can fail a project that gates on warnings: bump the minor version for a new rule or a tighter limit, the patch version for a false-positive fix, and say which projects need work in the release notes.

## Adding a rule

Create `lib/src/rules/<name>.dart` with an `AnalysisRule` subclass (a `static const LintCode` with `severity: DiagnosticSeverity.WARNING`, a `hl_` snake_case name, and the standards ID at the start of the message) and a `SimpleAstVisitor`; register it in `lib/main.dart` with `registerWarningRule`. Add a test class to `test/` extending `AnalysisRuleTest` with a positive case, a negative case and an edge case, add the rule to the table above, and add a violating example to `example/lib/violations.dart` (the CI example job checks that every rule fires there). Only add a rule if it can be made reliable with a syntactic or resolved-type check; if it needs a heuristic, document the heuristic in the class comment and keep it conservative.

## Development

```sh
dart pub get
dart format .
dart analyze
dart test
cd example && dart pub get && dart analyze   # 7 warnings, all from violations*.dart
```
