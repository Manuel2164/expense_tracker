import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// The GitHub repository whose releases the app updates from, as `owner/name`.
const updateRepo = 'YOUR_GITHUB_USERNAME/expense_tracker';

/// A release on GitHub that is newer than the installed app.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.notes,
    required this.apkUrl,
  });

  final String version;
  final String notes;
  final Uri apkUrl;
}

/// A failure with a message that is fit to show to the user.
class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Whether [candidate] is a later version than [current]. Accepts release tags
/// like `v1.2.0` and ignores build numbers (`1.2.0+7`).
bool isNewerVersion(String candidate, String current) {
  final a = _versionParts(candidate);
  final b = _versionParts(current);
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

List<int> _versionParts(String version) {
  final core = version.trim().replaceFirst(RegExp('^[vV]'), '');
  final numbers = core.split(RegExp(r'[+\-]')).first.split('.');
  return [
    for (var i = 0; i < 3; i++)
      i < numbers.length ? int.tryParse(numbers[i]) ?? 0 : 0,
  ];
}

Future<String> installedVersion() async =>
    (await PackageInfo.fromPlatform()).version;

/// Returns the latest GitHub release if it is newer than [installed] (the
/// running app's version by default), or null when the app is up to date.
Future<AppUpdate?> checkForUpdate({
  http.Client? client,
  String? installed,
}) async {
  final ownClient = client == null;
  final c = client ?? http.Client();
  try {
    final http.Response response;
    try {
      response = await c
          .get(
            Uri.https('api.github.com', '/repos/$updateRepo/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 15));
    } on Exception {
      throw const UpdateException(
        'Could not reach the update server. Check your connection.',
      );
    }
    if (response.statusCode == 404) {
      throw const UpdateException('No releases have been published yet.');
    }
    if (response.statusCode != 200) {
      throw UpdateException(
        'The update server returned an error (${response.statusCode}).',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final version = json['tag_name'] as String;
    if (!isNewerVersion(version, installed ?? await installedVersion())) {
      return null;
    }
    final assets = (json['assets'] as List).cast<Map<String, dynamic>>();
    final apk = assets
        .where((a) => (a['name'] as String).toLowerCase().endsWith('.apk'))
        .firstOrNull;
    if (apk == null) {
      throw UpdateException('Release $version has no APK attached.');
    }
    return AppUpdate(
      version: version.replaceFirst(RegExp('^[vV]'), ''),
      notes: (json['body'] as String? ?? '').trim(),
      apkUrl: Uri.parse(apk['browser_download_url'] as String),
    );
  } finally {
    if (ownClient) c.close();
  }
}

/// Downloads the APK for [update] into the app's cache, reporting progress
/// from 0 to 1 (or null when the server doesn't say how big the file is).
Future<File> downloadUpdate(
  AppUpdate update, {
  void Function(double? progress)? onProgress,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}${Platform.pathSeparator}expense_tracker-${update.version}.apk',
  );
  final partial = File('${file.path}.part');
  final client = http.Client();
  try {
    final response = await client.send(http.Request('GET', update.apkUrl));
    if (response.statusCode != 200) {
      throw UpdateException(
        'The download failed (${response.statusCode}).',
      );
    }
    final total = response.contentLength;
    var received = 0;
    final sink = partial.openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(
          total == null || total == 0 ? null : received / total,
        );
      }
    } finally {
      await sink.close();
    }
    // Only a complete download gets the .apk name.
    return await partial.rename(file.path);
  } on UpdateException {
    rethrow;
  } on Exception {
    throw const UpdateException(
      'The download was interrupted. Check your connection and try again.',
    );
  } finally {
    client.close();
  }
}

/// Hands the downloaded [apk] to Android's package installer.
Future<void> installUpdate(File apk) async {
  final result = await OpenFilex.open(
    apk.path,
    type: 'application/vnd.android.package-archive',
  );
  if (result.type != ResultType.done) {
    throw UpdateException('Could not open the installer: ${result.message}');
  }
}
