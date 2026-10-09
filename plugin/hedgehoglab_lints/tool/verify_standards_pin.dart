// Verifies that every standards lint is still pinned to the standard it was
// written against. Exit 0: all pins hold. Exit 1: a standard changed (or went
// missing), so the lint must be re-reviewed. Exit 2: usage or fetch error.
//
//   dart run tool/verify_standards_pin.dart                      # fetch via gh
//   dart run tool/verify_standards_pin.dart --standards-dir DIR  # a checkout
//   dart run tool/verify_standards_pin.dart --provenance FILE    # Quilltrail's
//                                                                # provenance.json
//
// The default mode fetches `standards/<file>` at the pinned commit with the
// GitHub CLI (`gh`), which needs read access to the catalogue repository.
import 'dart:convert';
import 'dart:io';

import 'standards_pin.dart';

Future<void> main(List<String> args) async {
  var lockPath = 'standards.lock.json';
  String? standardsDir;
  String? provenancePath;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--lock':
        lockPath = _value(args, ++i);
      case '--standards-dir':
        standardsDir = _value(args, ++i);
      case '--provenance':
        provenancePath = _value(args, ++i);
      default:
        _usage('Unknown argument ${args[i]}');
    }
  }
  if (standardsDir != null && provenancePath != null) {
    _usage('Use either --standards-dir or --provenance, not both.');
  }

  final lock = jsonDecode(File(lockPath).readAsStringSync()) as Map;
  final catalog = lock['catalog'] as Map;
  final pinned = [
    for (final e in (lock['rules'] as Map).entries)
      PinnedRule(e.key as String, (e.value as Map).cast<String, dynamic>()),
  ];

  final problems = <String>[];
  if (provenancePath != null) {
    _checkProvenance(provenancePath, catalog, pinned, problems);
  } else {
    final files = <String, Map<String, StandardRule>>{};
    for (final rule in pinned) {
      final rules = files[rule.file] ??= parseRules(
        standardsDir != null
            ? _readLocal(standardsDir, rule.file)
            : _fetch(
                catalog['repository'] as String,
                catalog['commit'] as String,
                rule.file,
              ),
      );
      final actual = rules[rule.id];
      final problem = comparePin(
        rule,
        actualHash: actual?.contentHash,
        actualTitle: actual?.title,
      );
      if (problem != null) problems.add(problem);
    }
  }

  if (problems.isEmpty) return;
  stderr.writeln(problems.take(10).join('\n'));
  exit(1);
}

void _checkProvenance(
  String path,
  Map<dynamic, dynamic> catalog,
  List<PinnedRule> pinned,
  List<String> problems,
) {
  final provenance = jsonDecode(File(path).readAsStringSync()) as Map;
  final baseline = provenance['accepted_baseline'] as Map?;
  if (baseline != null && baseline['commit'] != catalog['commit']) {
    problems.add(
      'Catalogue commit differs: lock ${catalog['commit']}, provenance '
      '${baseline['commit']}.',
    );
  }
  if (provenance['policy_version'] != catalog['policy_version']) {
    problems.add(
      'Policy version differs: lock ${catalog['policy_version']}, provenance '
      '${provenance['policy_version']}.',
    );
  }
  final byId = {
    for (final r in provenance['rules'] as List) (r as Map)['id']: r,
  };
  for (final rule in pinned) {
    final actual = byId[rule.id];
    final problem = comparePin(
      rule,
      actualHash: actual?['content_hash'] as String?,
      actualTitle: actual?['title'] as String?,
    );
    if (problem != null) problems.add(problem);
  }
}

String _readLocal(String dir, String file) {
  final f = File('$dir/$file');
  if (!f.existsSync()) _fail('${f.path} not found.');
  return f.readAsStringSync();
}

String _fetch(String repository, String commit, String file) {
  final result = Process.runSync('gh', [
    'api',
    '-H',
    'Accept: application/vnd.github.raw',
    'repos/$repository/contents/standards/$file?ref=$commit',
  ]);
  if (result.exitCode != 0) {
    _fail(
      'Could not fetch standards/$file at $commit from $repository with gh '
      '(${result.stderr.toString().trim()}). Use --standards-dir or '
      '--provenance for an offline check.',
    );
  }
  return result.stdout as String;
}

String _value(List<String> args, int i) =>
    i < args.length ? args[i] : _usage('${args[i - 1]} needs a value.');

Never _usage(String message) => _fail(
  '$message\nUsage: verify_standards_pin.dart [--lock FILE] '
  '[--standards-dir DIR | --provenance FILE]',
);

Never _fail(String message) {
  stderr.writeln(message);
  exit(2);
}
