import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Copy user notification_alert_sound.mp3 to android raw resources', () {
    final rawDir = Directory('android/app/src/main/res/raw');
    if (!rawDir.existsSync()) {
      rawDir.createSync(recursive: true);
    }

    final sourceFile = File('asset/sounds/notification_sounds/notification_alert_sound.mp3');
    expect(sourceFile.existsSync(), isTrue, reason: 'Source MP3 must exist');

    final targetFile = File('android/app/src/main/res/raw/notification_alert_sound.mp3');
    sourceFile.copySync(targetFile.path);

    expect(targetFile.existsSync(), isTrue);
    expect(targetFile.lengthSync(), equals(sourceFile.lengthSync()));
  });
}
