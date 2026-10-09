import 'dart:convert';

import 'package:expense_tracker/data/updater.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

MockClient releaseClient(String tag, {List<String> assets = const []}) =>
    MockClient(
      (request) async => http.Response(
        jsonEncode({
          'tag_name': tag,
          'body': 'Bug fixes',
          'assets': [
            for (final name in assets)
              {
                'name': name,
                'browser_download_url': 'https://example.com/$name',
              },
          ],
        }),
        200,
      ),
    );

void main() {
  group('isNewerVersion', () {
    test('compares each part numerically', () {
      expect(isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(isNewerVersion('1.10.0', '1.9.0'), isTrue);
      expect(isNewerVersion('2.0.0', '1.9.9'), isTrue);
      expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0.0', '1.0.1'), isFalse);
    });

    test('accepts tag prefixes, build numbers and short versions', () {
      expect(isNewerVersion('v1.1.0', '1.0.0+4'), isTrue);
      expect(isNewerVersion('v1.0.0+9', '1.0.0+1'), isFalse);
      expect(isNewerVersion('1.1', '1.0.5'), isTrue);
    });
  });

  group('checkForUpdate', () {
    test('returns the APK of a newer release', () async {
      final update = await checkForUpdate(
        client: releaseClient('v1.2.0', assets: ['notes.txt', 'app.apk']),
        installed: '1.0.0',
      );
      expect(update!.version, '1.2.0');
      expect(update.notes, 'Bug fixes');
      expect(update.apkUrl, Uri.parse('https://example.com/app.apk'));
    });

    test('returns null when already up to date', () async {
      final update = await checkForUpdate(
        client: releaseClient('v1.0.0', assets: ['app.apk']),
        installed: '1.0.0',
      );
      expect(update, isNull);
    });

    test('fails clearly when the release has no APK', () {
      expect(
        checkForUpdate(client: releaseClient('v1.2.0'), installed: '1.0.0'),
        throwsA(isA<UpdateException>()),
      );
    });

    test('fails clearly when nothing has been released', () {
      expect(
        checkForUpdate(
          client: MockClient((_) async => http.Response('{}', 404)),
          installed: '1.0.0',
        ),
        throwsA(isA<UpdateException>()),
      );
    });
  });
}
