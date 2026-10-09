import 'dart:convert';

import 'package:crypto/crypto.dart';

/// One rule parsed from a standards markdown file, the way Quilltrail parses
/// it (`desktop/core/lib/setup/application/resolve_standards.dart`).
class StandardRule {
  StandardRule(this.id, this.title, this.rawTag, this.body);

  final String id;
  final String title;
  final String rawTag;
  final String body;

  String get contentHash => hashRuleContent(title, rawTag, body);
}

/// A rule heading: `### STATE-002 — Title [mandatory]`. Same pattern as
/// Quilltrail's `ruleHeadingPattern`.
final _heading = RegExp(
  r'^###\s+(?:([A-Z][A-Z0-9-]*-[0-9]{3})\s+[—-]\s+)?(.+?)\s*\[([^\]]+)\]\s*$',
  multiLine: true,
);

/// Quilltrail's `content_hash`: SHA-256 of `title \n tag \n trimmed body`
/// (UTF-8), where the body runs from the end of the heading to the next
/// `\n### ` or the end of the file.
String hashRuleContent(String title, String rawTag, String body) =>
    sha256.convert(utf8.encode('$title\n$rawTag\n${body.trim()}')).toString();

/// Rules in [markdown] that carry an ID, keyed by ID.
Map<String, StandardRule> parseRules(String markdown) {
  final rules = <String, StandardRule>{};
  for (final m in _heading.allMatches(markdown)) {
    final id = m.group(1)?.trim();
    if (id == null) continue;
    final next = markdown.indexOf('\n### ', m.end);
    final body = next == -1
        ? markdown.substring(m.end)
        : markdown.substring(m.end, next);
    rules[id] = StandardRule(
      id,
      m.group(2)!.trim(),
      m.group(3)!.trim(),
      body.trim(),
    );
  }
  return rules;
}

/// A pinned rule as recorded in `standards.lock.json`.
class PinnedRule {
  PinnedRule(this.id, Map<String, dynamic> json)
    : file = json['file'] as String,
      title = json['title'] as String,
      contentHash = json['content_hash'] as String,
      lints = [for (final l in json['lints'] as List) l as String];

  final String id;
  final String file;
  final String title;
  final String contentHash;
  final List<String> lints;
}

/// Compares [pinned] with the current rule [actual] (null when the catalogue
/// no longer has it). Returns the problem, or null when the pin still holds.
String? comparePin(
  PinnedRule pinned, {
  String? actualHash,
  String? actualTitle,
}) {
  final lints = pinned.lints.join(', ');
  if (actualHash == null) {
    return '${pinned.id}: not found in the catalogue. Re-review $lints.';
  }
  if (actualHash != pinned.contentHash) {
    return '${pinned.id}: the standard changed (lock ${pinned.contentHash}, '
        'catalogue $actualHash). Re-review $lints, then update '
        'standards.lock.json.';
  }
  if (actualTitle != pinned.title) {
    return '${pinned.id}: title differs ("${pinned.title}" vs '
        '"$actualTitle").';
  }
  return null;
}
