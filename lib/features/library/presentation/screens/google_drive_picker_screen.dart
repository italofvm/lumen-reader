import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:lumen_reader/core/services/cloud/google_drive_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:hive_flutter/hive_flutter.dart';

class GoogleDrivePickerScreen extends StatefulWidget {
  const GoogleDrivePickerScreen({super.key});

  @override
  State<GoogleDrivePickerScreen> createState() =>
      _GoogleDrivePickerScreenState();
}

class _GoogleDrivePickerScreenState extends State<GoogleDrivePickerScreen> {
  final GoogleDriveService _driveService = GoogleDriveService();
  GoogleSignInAccount? _user;
  List<drive.File> _files = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkSignIn();
  }

  Future<void> _checkSignIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await _driveService.signInSilently();
      if (!mounted) return;

      if (user != null) {
        setState(() => _user = user);
        await _loadFiles();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao conectar ao Google Drive: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await _driveService.signIn();
      if (!mounted) return;

      if (user != null) {
        setState(() => _user = user);
        await _loadFiles();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login cancelado ou não autorizado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro no login do Google: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final files = await _driveService.listDriveFiles();
      if (!mounted) return;
      setState(() {
        _files = files;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao listar arquivos do Drive: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadAndImport(drive.File driveFile) async {
    if (driveFile.id == null || driveFile.name == null) return;

    setState(() => _isLoading = true);
    try {
      final driveApi = await _driveService.getDriveApi();
      if (driveApi == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível autenticar no Google Drive. Tente conectar novamente.',
              ),
            ),
          );
        }
        return;
      }

      final response =
          await driveApi.files.get(
                driveFile.id!,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final appDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory(p.join(appDir.path, 'books'));
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }

      final fileName = driveFile.name!;
      final bookId = DateTime.now().millisecondsSinceEpoch.toString();
      final extension = fileName.split('.').last.toLowerCase();
      final targetPath = p.join(booksDir.path, '$bookId.$extension');

      final file = File(targetPath);
      final ios = file.openWrite();
      await response.stream.pipe(ios);
      await ios.close();

      if (mounted) {
        Navigator.pop(
          context,
          <String, String>{'path': targetPath, 'name': fileName},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao baixar arquivo: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performBackup() async {
    setState(() => _isLoading = true);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final libraryFile = File(p.join(appDir.path, 'library_box.hive'));
      final settingsFile = File(p.join(appDir.path, 'settings.hive'));

      if (await libraryFile.exists()) {
        await _driveService.uploadFile(
          libraryFile,
          'lumen_backup_library.hive',
        );
      }
      if (await settingsFile.exists()) {
        await _driveService.uploadFile(
          settingsFile,
          'lumen_backup_settings.hive',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup concluído com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro no backup: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performRestore() async {
    setState(() => _isLoading = true);
    try {
      final libraryBackup = await _driveService.getFileByName(
        'lumen_backup_library.hive',
      );
      final settingsBackup = await _driveService.getFileByName(
        'lumen_backup_settings.hive',
      );

      if (libraryBackup == null && settingsBackup == null) {
        throw 'Nenhum backup encontrado no Google Drive.';
      }

      final appDir = await getApplicationDocumentsDirectory();

      // Close boxes before restoring
      await Hive.close();

      if (libraryBackup != null) {
        await _driveService.downloadFile(
          libraryBackup.id!,
          p.join(appDir.path, 'library_box.hive'),
        );
      }
      if (settingsBackup != null) {
        await _driveService.downloadFile(
          settingsBackup.id!,
          p.join(appDir.path, 'settings.hive'),
        );
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Restauração concluída'),
            content: const Text(
              'Por favor, reinicie o aplicativo para carregar as novas configurações.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Ideally we would trigger a restart here, but for now just tell the user
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro na restauração: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Drive')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Conecte sua conta Google para importar livros.'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _handleSignIn,
                    icon: const Icon(Icons.login),
                    label: const Text('Conectar Google Drive'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Backup/Restore Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).primaryColor.withAlpha((0.05 * 255).round()),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _performBackup,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Fazer Backup'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _performRestore,
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('Restaurar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _files.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Nenhum arquivo PDF ou EPUB encontrado.',
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: _loadFiles,
                                child: const Text('Recarregar'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _files.length,
                          itemBuilder: (context, index) {
                            final file = _files[index];
                            return ListTile(
                              leading: Icon(
                                file.mimeType == 'application/pdf'
                                    ? Icons.picture_as_pdf
                                    : Icons.menu_book,
                              ),
                              title: Text(file.name ?? 'Sem nome'),
                              subtitle: Text(
                                file.size != null
                                    ? '${(int.parse(file.size!) / 1024 / 1024).toStringAsFixed(2)} MB'
                                    : 'Tamanho desconhecido',
                              ),
                              onTap: () => _downloadAndImport(file),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
