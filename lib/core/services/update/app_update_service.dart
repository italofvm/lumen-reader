import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:lumen_reader/core/config/app_config.dart';
import 'package:lumen_reader/core/services/update/github_update_service.dart';

class AppUpdateService {
  static const MethodChannel _channel = MethodChannel('lumen_reader/update');

  Future<void> checkAndPrompt(
    BuildContext context, {
    bool showUpToDateDialog = false,
    bool allowPrerelease = true,
  }) async {
    try {
      final info = await PackageInfo.fromPlatform();

      final service = GitHubUpdateService(
        owner: AppConfig.githubOwner,
        repo: AppConfig.githubRepo,
      );

      final latest = await service.fetchLatestRelease(
        includePreRelease: allowPrerelease,
      );

      if (!context.mounted) return;

      if (latest == null) {
        if (showUpToDateDialog) {
          await _showMessageDialog(
            context,
            title: 'Atualizações',
            message: 'Nenhuma versão encontrada para atualização.',
          );
        }
        return;
      }

      final hasUpdate = service.isNewer(
        currentVersion: info.version,
        latestTag: latest.tagName,
      );

      if (!hasUpdate) {
        if (showUpToDateDialog) {
          await _showMessageDialog(
            context,
            title: 'Você está atualizado',
            message: 'Sua versão: ${info.version}\nÚltima versão: ${latest.tagName}',
          );
        }
        return;
      }

      final didConfirm = await _showUpdateDialog(
        context,
        currentVersion: info.version,
        latestVersion: latest.tagName,
        canDownloadInApp: _canDownloadInApp(latest),
      );

      if (!context.mounted) return;
      if (didConfirm != true) return;

      await _performUpdate(context, latest);
    } catch (e) {
      if (!context.mounted) return;
      await _showMessageDialog(
        context,
        title: 'Erro ao verificar atualização',
        message: e.toString(),
      );
    }
  }

  bool _canDownloadInApp(GitHubReleaseInfo latest) {
    if (kIsWeb) return false;
    if (!Platform.isAndroid) return false;
    return latest.apkDownloadUrl != null;
  }

  Future<void> _performUpdate(BuildContext context, GitHubReleaseInfo latest) async {
    final url = latest.apkDownloadUrl ?? latest.htmlUrl;

    if (!_canDownloadInApp(latest)) {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      if (context.mounted) {
        await _showMessageDialog(
          context,
          title: 'Atualização',
          message: 'Não foi possível abrir o link de atualização.',
        );
      }
      return;
    }

    final apkUrl = latest.apkDownloadUrl;
    if (apkUrl == null) return;

    final file = await _downloadWithProgressDialog(
      context,
      url: apkUrl,
      filenameHint: 'lumen_reader_${latest.tagName}.apk',
    );

    if (!context.mounted) return;

    if (file == null) {
      await _showMessageDialog(
        context,
        title: 'Atualização',
        message: 'Download cancelado ou falhou.',
      );
      return;
    }

    try {
      await _channel.invokeMethod<void>('installApk', {'path': file.path});
    } catch (e) {
      if (!context.mounted) return;
      await _showMessageDialog(
        context,
        title: 'Não foi possível instalar',
        message: e.toString(),
      );
    }
  }

  Future<File?> _downloadWithProgressDialog(
    BuildContext context, {
    required String url,
    required String filenameHint,
  }) async {
    final progress = ValueNotifier<double?>(null);
    final isCancelling = ValueNotifier<bool>(false);
    final cancelCompleter = Completer<void>();

    BuildContext? dialogCtx;

    Future<File?> downloadFuture() async {
      try {
        final client = http.Client();
        try {
          final req = http.Request('GET', Uri.parse(url));
          final res = await client.send(req);

          if (res.statusCode < 200 || res.statusCode >= 300) {
            throw Exception('HTTP ${res.statusCode}');
          }

          final total = res.contentLength;

          final tmp = await getTemporaryDirectory();
          final safeName = filenameHint.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
          final outPath = p.join(tmp.path, safeName);
          final outFile = File(outPath);

          final sink = outFile.openWrite();
          var received = 0;

          await for (final chunk in res.stream) {
            if (cancelCompleter.isCompleted) {
              await sink.close();
              try {
                if (await outFile.exists()) {
                  await outFile.delete();
                }
              } catch (_) {}
              return null;
            }

            sink.add(chunk);
            received += chunk.length;

            if (total != null && total > 0) {
              progress.value = received / total;
            } else {
              progress.value = null;
            }
          }

          await sink.flush();
          await sink.close();
          return outFile;
        } finally {
          client.close();
        }
      } catch (_) {
        return null;
      }
    }

    final future = downloadFuture();

    if (!context.mounted) return null;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          dialogCtx = ctx;
          return ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (context, value, _) {
              return AlertDialog(
                title: const Text('Baixando atualização'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (value == null)
                      const LinearProgressIndicator()
                    else
                      LinearProgressIndicator(value: value),
                    const SizedBox(height: 12),
                    if (value != null) Text('${(value * 100).toStringAsFixed(0)}%'),
                  ],
                ),
                actions: [
                  ValueListenableBuilder<bool>(
                    valueListenable: isCancelling,
                    builder: (context, cancelling, _) {
                      return TextButton(
                        onPressed: cancelling
                            ? null
                            : () {
                                isCancelling.value = true;
                                if (!cancelCompleter.isCompleted) {
                                  cancelCompleter.complete();
                                }
                                Navigator.of(ctx).pop();
                              },
                        child: const Text('Cancelar'),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );

    final file = await future;

    final ctx = dialogCtx;
    if (ctx != null) {
      try {
        if (ctx.mounted) {
          Navigator.of(ctx).pop();
        }
      } catch (_) {}
    }

    return file;
  }

  Future<bool?> _showUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required String latestVersion,
    required bool canDownloadInApp,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Atualização disponível'),
        content: Text(
          'Nova versão: $latestVersion\nSua versão: $currentVersion\n\n'
          '${canDownloadInApp ? 'Deseja baixar e instalar agora?' : 'Deseja abrir a página de download agora?'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Agora não'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(canDownloadInApp ? 'Atualizar' : 'Abrir'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMessageDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
