/// Tolerant readers for backup values. Backups come from JSON (typed),
/// Excel (mostly strings) and older app versions, so every field may arrive
/// as a string, a number or not at all.
library;

/// Where backups are saved (a folder the user picked; none: Download) and
/// its name. In full backups like any setting (the owner, 2026-11-04); Android's
/// access to the folder doesn't come with them: the next backup asks for it.
const String kBackupFolderPrefsKey = 'backupFolder';
const String kBackupFolderNamePrefsKey = 'backupFolderName';

String? backupString(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

int? backupInt(Object? v) {
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) {
    final s = v.trim();
    return int.tryParse(s) ?? double.tryParse(s)?.round();
  }
  return null;
}

bool? backupBool(Object? v) {
  if (v is bool) return v;
  if (v is int) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
  }
  return null;
}

/// ISO-8601 text (with or without offset) or epoch milliseconds, as UTC.
DateTime? backupDateUtc(Object? v) {
  if (v is DateTime) return v.toUtc();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
  if (v is double) {
    return DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
  }
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return null;
    final ms = int.tryParse(s);
    if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return DateTime.tryParse(s)?.toUtc();
  }
  return null;
}
