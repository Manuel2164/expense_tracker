import 'dart:io';

import 'package:flutter/material.dart';

import '../data/updater.dart';

enum _Stage { idle, checking, downloading }

/// Settings row that checks GitHub for a newer release and installs it.
class UpdateTile extends StatefulWidget {
  const UpdateTile({super.key});

  @override
  State<UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends State<UpdateTile> {
  _Stage _stage = _Stage.idle;
  double? _progress;
  String? _version;

  @override
  void initState() {
    super.initState();
    installedVersion().then(
      (version) {
        if (mounted) setState(() => _version = version);
      },
      // The version is only a label; the row still works without it.
      onError: (Object _) {},
    );
  }

  Future<void> _check() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _stage = _Stage.checking);
    try {
      final update = await checkForUpdate();
      if (!mounted) return;
      if (update == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('You have the latest version.')),
        );
        return;
      }
      if (await _confirm(update) != true || !mounted) return;

      setState(() {
        _stage = _Stage.downloading;
        _progress = null;
      });
      final apk = await downloadUpdate(
        update,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      await installUpdate(apk);
    } on UpdateException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _stage = _Stage.idle);
    }
  }

  Future<bool?> _confirm(AppUpdate update) {
    // Only Android can install the downloaded APK.
    final canInstall = Platform.isAndroid;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Version ${update.version} is available'),
        content: SingleChildScrollView(
          child: Text(
            canInstall
                ? (update.notes.isEmpty
                      ? 'Your expenses are kept when you update.'
                      : update.notes)
                : 'Updates can only be installed from the Android app.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(canInstall ? 'Later' : 'Close'),
          ),
          if (canInstall)
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Update'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final version = _version;
    return ListTile(
      leading: const Icon(Icons.system_update_outlined),
      title: const Text('Check for updates'),
      subtitle: switch (_stage) {
        _Stage.idle => version == null ? null : Text('Version $version'),
        _Stage.checking => const Text('Checking…'),
        _Stage.downloading => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: LinearProgressIndicator(value: _progress),
        ),
      },
      enabled: _stage == _Stage.idle,
      onTap: _check,
    );
  }
}
