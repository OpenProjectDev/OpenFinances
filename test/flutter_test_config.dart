// The source repository doesn't include the icon files (see ICONS.md), so a
// test that draws a missing one gets a blank image instead of failing.
// Assets that exist are served as usual.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

final _blankPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6'
  'kgAAAABJRU5ErkJggg==',
);

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final folder = Platform.environment['UNIT_TEST_ASSETS'];
  if (folder != null) {
    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      message,
    ) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      final file = File('$folder/$key');
      if (file.existsSync()) {
        return ByteData.sublistView(file.readAsBytesSync());
      }
      if (RegExp(r'^assets/(icons|nav)/.*\.png$').hasMatch(key)) {
        return ByteData.sublistView(_blankPng);
      }
      return null;
    });
  }
  await testMain();
}
