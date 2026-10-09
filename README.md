# hedgehog lab Flutter Analysis

The standard Dart and Flutter analyser configuration used at hedgehog lab. A project adopts it with one `include:` line, and gets the same lint rules, strict language modes and generated-code excludes as every other hedgehog lab project.

This package is a maintained fork of [netsells/flutter-analysis](https://github.com/netsells/flutter-analysis), which was itself inspired by [very_good_analysis](https://pub.dev/packages/very_good_analysis). See [Attribution](#attribution).

## Adopting it

Add the package as a git dependency, pinned to a tag, in `pubspec.yaml`:

```yaml
dev_dependencies:
  hedgehoglab_flutter_analysis:
    git:
      url: https://github.com/hedgehoglab-engineering/flutter-analysis.git
      ref: 6.0.0
```

Then use this as the project's `analysis_options.yaml`:

```yaml
include: package:hedgehoglab_flutter_analysis/analysis_options.6.0.0.yaml

analyzer:
  exclude:
    - build/**
    - android/**
    - ios/**
    - web/**
    - windows/**
    - macos/**
    - linux/**

plugins:
  hedgehoglab_lints:
    git:
      url: https://github.com/hedgehoglab-engineering/flutter-analysis
      path: plugin/hedgehoglab_lints
      ref: hedgehoglab_lints-v0.1.0
```

The seven excludes repeat what 6.0.0 already excludes, on purpose. Flutter 3.47's `flutter pub get` checks the project's own `analysis_options.yaml` for exactly these seven entries (it does not follow `include:`), and rewrites the file to add any that are missing (see `analysis_options_migration.dart` in `flutter_tools`). Keeping them in the project file stops the rewrite. Drop the `plugins:` block if the project is not adopting the [analyzer plugin](#analyzer-plugin).

Run `flutter pub get`, then `flutter analyze`. Expect new findings on the first run: 6.0.0 turns on `strict-casts`, `strict-inference` and `strict-raw-types`.

Requires Dart 3.13 or later. The package is not published to pub.dev.

## What 6.0.0 contains

- The rule set from 5.0.0, minus rules that no longer exist or are deprecated in Dart 3, plus `flutter_style_todos`. See the [CHANGELOG](CHANGELOG.md) for the exact list.
- `strict-casts`, `strict-inference` and `strict-raw-types`.
- Excludes for generated code (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.mocks.dart`) and the platform directories.
- Severity overrides inherited from Netsells (`missing_return` and `missing_required_param` as errors, `close_sinks` and `invalid_annotation_target` ignored).
- `lines_longer_than_80_chars` stays on. It matches the default `dart format` page width, and it catches what the formatter cannot wrap (long strings and comments). A project that sets a different `page_width` should override the rule in its own `analysis_options.yaml`.

## Versioning policy

Each release that changes rules adds a new versioned file, `lib/analysis_options.X.Y.Z.yaml`. Earlier files are never edited, so a project that includes `analysis_options.6.0.0.yaml` gets the same rules for as long as it pins that file.

- Projects pin both the git `ref` and the versioned file in the `include:` line. Upgrading is a deliberate change to both, reviewed like any other dependency bump.
- `lib/analysis_options.yaml` always points at the latest version. Including it means rules can change under you on the next `pub upgrade`, so avoid it in projects with a clean-analyser CI gate.
- New or tightened rules (and anything that makes a clean project fail) get a new major or minor version. Removing a rule the SDK no longer supports is also a new version, because the old file stops being accurate on newer SDKs.

## Migrating

### From netsells_flutter_analysis

1. Replace the dependency with the git dependency above.
2. Change the include to `package:hedgehoglab_flutter_analysis/analysis_options.6.0.0.yaml`.
3. Fix new findings from the strict language modes. If a project cannot absorb them at once, include `analysis_options.5.0.0.yaml` first (the Netsells rules, unchanged) and move to 6.0.0 in a separate change.

### From an inline copy of the rules

1. Add the dependency and replace the copied `linter:` block with the include line.
2. Keep only project-specific `analyzer:` entries (extra excludes or severity changes) and `linter.rules` overrides. Anything that duplicates 6.0.0 can go.
3. Make sure the project file lists the seven excludes shown under "Adopting it". Run `flutter analyze` and compare with the previous result. The usual differences are the strict modes and the generated-code excludes.

## Suppressing lints

Some rules are undesirable in particular places. Suppress at the line, file or project level.

A line:

```dart
// ignore: public_member_api_docs
class A {}
```

A file:

```dart
// ignore_for_file: public_member_api_docs
```

A project: override the rule in the project's `analysis_options.yaml` after the `include:` line.

```yaml
linter:
  rules:
    lines_longer_than_80_chars: false
```

## Analyzer plugin

`plugin/hedgehoglab_lints/` is a separate package: an analyzer plugin that turns code-metric limits and the mechanically checkable Flutter standards into warnings from `dart analyze`. See its [README](plugin/hedgehoglab_lints/README.md). It is independent of the lint set above.

## Developing this package

CI formats and analyses the package and the `example` project with `--fatal-infos`, and fails on any undefined, removed or deprecated lint. Before adding a rule, check its status on [dart.dev](https://dart.dev/tools/linter-rules/all). Run the same checks locally:

```sh
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos .
dart analyze --fatal-infos example
```

## Attribution

Created by [Netsells](https://netsells.co.uk) and released under the MIT licence. The original copyright notice is retained in [LICENSE](LICENSE), with hedgehog lab's alongside it.
