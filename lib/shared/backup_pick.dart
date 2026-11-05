// lib/shared/backup_pick.dart
// Choosing a backup file and reading it whole (Settings' Restore, the
// first page's Restore): nothing is touched until it has been read.

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart' show XFile;

import 'package:openfinances/data/backup.dart';
import 'package:openfinances/l10n/generated/app_localizations.dart';
import 'package:openfinances/shared/ui/app_notice.dart';

/// Asks for a backup file (JSON, Excel or an old CSV) and reads it; null
/// when none was picked or it can't be read (a notice says why).
Future<BackupData?> pickBackup(BuildContext context) async {
  final l = AppLocalizations.of(context)!;
  final notice = AppNotice.of(context); // before the awaits
  // file_picker 13: single pick returns the file (or null) directly,
  // readable via XFile even when Android hands back a content:// URI.
  final file = await FilePicker.pickFile(
    dialogTitle: l.pickBackupFile,
    type: FileType.custom,
    allowedExtensions: const ['json', 'csv', 'xlsx'],
  );
  if (file == null) return null;
  final name = file.name.toLowerCase();
  try {
    if (name.endsWith('.json')) {
      return BackupData.fromJson(jsonDecode(await _readTextAuto(file.xFile)));
    } else if (name.endsWith('.xlsx')) {
      return BackupData.fromXlsx(await file.xFile.readAsBytes());
    } else if (name.endsWith('.csv')) {
      return BackupData.fromCsv(await _readTextAuto(file.xFile));
    }
    notice.show(l.invalidFile, kind: NoticeKind.failure);
    return null;
  } catch (_) {
    notice.show(l.invalidBackupFormat, kind: NoticeKind.failure);
    return null;
  }
}

Future<String> _readTextAuto(XFile file) async {
  final b = await file.readAsBytes();

  // UTF-16LE BOM
  if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xFE) {
    final len = (b.length - 2) ~/ 2;
    final units = List<int>.generate(
      len,
      (i) => b[2 + i * 2] | (b[3 + i * 2] << 8),
    );
    return String.fromCharCodes(units);
  }
  // UTF-16BE BOM
  if (b.length >= 2 && b[0] == 0xFE && b[1] == 0xFF) {
    final len = (b.length - 2) ~/ 2;
    final units = List<int>.generate(
      len,
      (i) => (b[2 + i * 2] << 8) | b[3 + i * 2],
    );
    return String.fromCharCodes(units);
  }
  // UTF-8 BOM
  if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) {
    return utf8.decode(b.sublist(3));
  }
  // default: UTF-8
  return utf8.decode(b, allowMalformed: true);
}
