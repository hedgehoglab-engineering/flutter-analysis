import 'dart:convert';
import 'dart:io';

import 'package:hedgehoglab_lints/src/rules.dart';
import 'package:hedgehoglab_lints/src/rules/no_static_singleton.dart';
import 'package:hedgehoglab_lints/src/rules/notifier_suffix.dart';
import 'package:hedgehoglab_lints/src/rules/notifier_void_methods.dart';
import 'package:test/test.dart';

import '../tool/standards_pin.dart';

/// Offline checks that `standards.lock.json` and the registered rules agree.
/// `tool/verify_standards_pin.dart` checks the lock against the catalogue.
void main() {
  final lock =
      jsonDecode(File('standards.lock.json').readAsStringSync()) as Map;
  final pinned = {
    for (final e in (lock['rules'] as Map).entries)
      e.key as String: PinnedRule(
        e.key as String,
        (e.value as Map).cast<String, dynamic>(),
      ),
  };
  final registered = {for (final r in allRules()) r.name};

  // Rule classes whose messages start with a standards ID, e.g. "STATE-005:".
  final standardsRules = {
    NotifierSuffix.code,
    NotifierVoidMethods.code,
    NoStaticSingleton.code,
  };

  test('the catalogue pin is complete', () {
    final catalog = lock['catalog'] as Map;
    expect(catalog['repository'], matches(r'^[\w.-]+/[\w.-]+$'));
    expect(catalog['commit'], matches(r'^[0-9a-f]{40}$'));
    expect(catalog['tag'], isNotEmpty);
    expect(catalog['policy_version'], isNotEmpty);
  });

  test('every standards rule class ID is in the lock, naming that lint', () {
    for (final code in standardsRules) {
      final id = RegExp(
        r'^([A-Z][A-Z0-9-]*-[0-9]{3}):',
      ).firstMatch(code.problemMessage)?.group(1);
      expect(id, isNotNull, reason: '${code.lowerCaseName} has no ID');
      expect(pinned, contains(id));
      expect(pinned[id]!.lints, contains(code.lowerCaseName));
    }
  });

  test('every lock entry names existing registered lints and a hash', () {
    for (final rule in pinned.values) {
      expect(rule.lints, isNotEmpty, reason: rule.id);
      expect(registered, containsAll(rule.lints), reason: rule.id);
      expect(rule.contentHash, matches(r'^[0-9a-f]{64}$'), reason: rule.id);
      expect(rule.title, isNotEmpty, reason: rule.id);
    }
  });

  test('every lint in the lock belongs to a rule that prints its ID', () {
    for (final rule in pinned.values) {
      final codes = standardsRules.where(
        (c) => rule.lints.contains(c.lowerCaseName),
      );
      expect(codes, isNotEmpty, reason: rule.id);
      for (final code in codes) {
        expect(code.problemMessage, startsWith('${rule.id}:'));
      }
    }
  });

  group('hash algorithm (Quilltrail content_hash)', () {
    const markdown = '''
# Section

### TEST-001 — First rule [mandatory]

Body of the first rule.

### TEST-002 — Second rule [advisory]

Body of the second rule.
More text.
''';

    test('parses IDs, titles, tags and bodies', () {
      final rules = parseRules(markdown);
      expect(rules.keys, ['TEST-001', 'TEST-002']);
      expect(rules['TEST-001']!.title, 'First rule');
      expect(rules['TEST-002']!.rawTag, 'advisory');
      expect(rules['TEST-001']!.body, 'Body of the first rule.');
    });

    test('hashes title, tag and trimmed body with SHA-256', () {
      // Computed independently:
      //   printf 'First rule\nmandatory\nBody of the first rule.' | shasum -a 256
      expect(
        parseRules(markdown)['TEST-001']!.contentHash,
        '7272390566e95ce62446fa044652c4dcccf2705ce75e926f87af106053e1ca0f',
      );
    });

    test('a changed body changes the hash and is reported', () {
      final before = parseRules(markdown)['TEST-002']!;
      final after = parseRules(
        markdown.replaceFirst('More text.', 'Other text.'),
      )['TEST-002']!;
      expect(after.contentHash, isNot(before.contentHash));
      final pin = PinnedRule('TEST-002', {
        'file': 'x.md',
        'title': before.title,
        'content_hash': before.contentHash,
        'lints': ['hl_example'],
      });
      expect(
        comparePin(
          pin,
          actualHash: before.contentHash,
          actualTitle: before.title,
        ),
        isNull,
      );
      expect(
        comparePin(
          pin,
          actualHash: after.contentHash,
          actualTitle: after.title,
        ),
        allOf(
          contains('TEST-002'),
          contains('hl_example'),
          contains('changed'),
        ),
      );
    });
  });
}
