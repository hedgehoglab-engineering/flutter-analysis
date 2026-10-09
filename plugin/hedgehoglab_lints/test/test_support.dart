/// Offset of the first occurrence of [needle] in [code], for `lint(...)`.
int at(String code, String needle) {
  final i = code.indexOf(needle);
  if (i < 0) throw ArgumentError('"$needle" not found in test code');
  return i;
}

/// Stand-ins for `riverpod_annotation` and the generated base class, so the
/// tests do not need code generation. The rules are syntactic and match on
/// `@riverpod` / `@Riverpod(...)` plus an `extends _$Name` clause.
const riverpodStub = r'''
const riverpod = Object();
class Riverpod {
  const Riverpod({bool keepAlive = false});
}
class _$CartNotifier {}
class _$CartController {}
''';
