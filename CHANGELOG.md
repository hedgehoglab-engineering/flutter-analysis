# 6.0.0

- Rename the package from `netsells_flutter_analysis` to `hedgehoglab_flutter_analysis` and move maintenance to hedgehog lab. The library file is now `hedgehoglab_flutter_analysis.dart`.
- Add `lib/analysis_options.6.0.0.yaml` and point `lib/analysis_options.yaml` at it. Earlier versioned files are unchanged.
- Remove rules that no longer exist, or are deprecated, in Dart 3:
  - Removed: `always_require_non_null_named_parameters`, `avoid_returning_null`, `avoid_returning_null_for_future`, `iterable_contains_unrelated_type`, `list_remove_unrelated_type`, `package_api_docs`, `prefer_equal_for_default_values`
  - Deprecated: `avoid_null_checks_in_equality_operators`, `avoid_private_typedef_functions`, `unnecessary_await_in_return`
- Add `flutter_style_todos`.
- Enable `strict-casts`, `strict-inference` and `strict-raw-types`. BREAKING for projects that adopt 6.0.0: expect new analyser errors until implicit casts, inferred `dynamic` and raw generic types are fixed.
- Exclude generated code (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.mocks.dart`) and the `android`, `ios`, `web`, `windows`, `macos` and `linux` directories.
- Replace the broad `lib/**.*.dart` and `test/**.*.dart` excludes from 5.0.0, which also hid hand-written files with a dotted name.
- Keep `lines_longer_than_80_chars`, matching the default `dart format` page width.
- Require Dart 3.13 or later (verified against Flutter 3.47).
- Modernise CI and drop the pana job.

# 5.0.0

- Upgrade to Flutter 3.10 and Dart 3
- Remove Dart Code Metrics

# 4.0.0

- Upgrade to Flutter 3.7.0
- Upgrade to Dart Code Metrics 5.5.0

# 3.2.0

- Upgrade `dart_code_metrics` dependency

# 3.1.0

- Add the following lints:
  - `depend_on_referenced_packages`
  - `no_leading_underscores_for_library_prefixes`
  - `no_leading_underscores_for_local_identifiers`
  - `unnecessary_constructor_name`
  - `unnecessary_late`
- Update README

# 3.0.0

- BREAKING: Requires Dart 2.17
- Add `use_super_parameters` lint rule

# 2.1.0

- Remove requirement for public member API docs

# 2.0.0

- Add [Dart Code Metrics](https://dartcodemetrics.dev)

# 1.1.0

- Ignore `invalid_annotation_target`
- Remove `library_private_types_in_public_api` rule

# 1.0.0

Initial release
