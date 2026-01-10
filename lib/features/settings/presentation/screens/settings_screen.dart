import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:lumen_reader/core/theme/theme_provider.dart';
import 'package:lumen_reader/core/theme/app_theme.dart';
import 'package:lumen_reader/core/services/update/app_update_service.dart';
import 'package:lumen_reader/core/services/import/auto_import_service.dart';
import 'package:lumen_reader/features/settings/domain/providers/settings_providers.dart';
import 'package:lumen_reader/features/library/presentation/providers/library_providers.dart';
import 'package:lumen_reader/features/settings/presentation/screens/terms_screen.dart';
import 'package:lumen_reader/features/onboarding/presentation/screens/onboarding_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const MethodChannel _safChannel = MethodChannel('lumen_reader/saf');

  Future<String> _getVersionLabel() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    await AppUpdateService().checkAndPrompt(
      context,
      showUpToDateDialog: true,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);
    final readerSettings = ref.watch(readerSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'Minha estante'),
          SwitchListTile(
            title: const Text('Estante com fundo de madeira'),
            value: readerSettings.isWoodShelf,
            onChanged: (value) => ref
                .read(readerSettingsProvider.notifier)
                .updateIsWoodShelf(value),
          ),
          SwitchListTile(
            title: const Text('Exibir progresso de leitura na capa'),
            value: readerSettings.showProgress,
            onChanged: (value) => ref
                .read(readerSettingsProvider.notifier)
                .updateShowProgress(value),
          ),
          ListTile(
            title: const Text('Pasta principal'),
            subtitle: Text(
              (Platform.isAndroid
                      ? (readerSettings.mainDirectoryUri ?? readerSettings.mainDirectory)
                      : readerSettings.mainDirectory) ??
                  'Não configurada',
            ),
            trailing: const Icon(Icons.folder_open),
            onTap: readerSettings.autoImportEnabled
                ? null
                : () async {
                    final selected = await FilePicker.platform.getDirectoryPath();
                    if (selected == null) return;

                    await ref
                        .read(readerSettingsProvider.notifier)
                        .updateMainDirectory(selected);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pasta principal atualizada com sucesso!'),
                        ),
                      );
                    }
                  },
          ),
          SwitchListTile(
            title: const Text('Importar automaticamente'),
            subtitle: const Text('Importa livros automaticamente da pasta principal'),
            value: readerSettings.autoImportEnabled,
            onChanged: (v) async {
              await ref.read(readerSettingsProvider.notifier).setAutoImportEnabled(v);

              if (!context.mounted) return;

              if (v) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Selecione a pasta para importar automaticamente.'),
                  ),
                );
              }
            },
          ),
          ListTile(
            title: const Text('Selecionar pasta para auto-import'),
            subtitle: Text(
              (Platform.isAndroid
                      ? (readerSettings.mainDirectoryUri ?? 'Não configurada')
                      : (readerSettings.mainDirectory ?? 'Não configurada')),
            ),
            trailing: const Icon(Icons.folder_open),
            enabled: readerSettings.autoImportEnabled,
            onTap: !readerSettings.autoImportEnabled
                ? null
                : () async {
                    if (kIsWeb) return;

                    if (Platform.isAndroid) {
                      try {
                        final uri = await _safChannel.invokeMethod<String>('pickDirectoryUri');
                        if (uri == null || uri.trim().isEmpty) return;
                        await ref
                            .read(readerSettingsProvider.notifier)
                            .updateMainDirectoryUri(uri);
                      } on PlatformException {
                        return;
                      }
                    } else {
                      final selected = await FilePicker.platform.getDirectoryPath();
                      if (selected == null) return;
                      await ref
                          .read(readerSettingsProvider.notifier)
                          .updateMainDirectory(selected);
                    }

                    await AutoImportService(ref).runIfEnabled();

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Importação automática executada.'),
                        ),
                      );
                    }
                  },
          ),
          const Divider(),

          _buildSectionHeader(context, 'Meus Arquivos'),
          SwitchListTile(
            title: const Text('Listar arquivos e pastas ocultos'),
            value: readerSettings.showHiddenFiles,
            onChanged: (value) => ref
                .read(readerSettingsProvider.notifier)
                .updateShowHiddenFiles(value),
          ),
          const Divider(),

          _buildSectionHeader(context, 'Aparência'),
          _buildThemeItem(
            context,
            ref,
            'Claro',
            AppThemeMode.light,
            currentTheme == AppThemeMode.light && !readerSettings.isDarkMode,
          ),
          _buildThemeItem(
            context,
            ref,
            'Escuro', // Replaced "Use o modo escuro AMOLED" with classic "Escuro" option if that was the intent, but screenshot shows "Escuro"
            AppThemeMode.dark,
            // Check if current theme is dark OR (it's manually dark mode but not midnight/sepia which are handled separately)
            // Actually, simply checking if current theme is dark is enough.
            // But wait, the screenshot shows "Meia-noite" checked.
            // Let's assume 'Escuro' maps to AppThemeMode.dark
            currentTheme == AppThemeMode.dark,
          ),
          _buildThemeItem(
            context,
            ref,
            'Sépia',
            AppThemeMode.sepia,
            currentTheme == AppThemeMode.sepia,
          ),
          _buildThemeItem(
            context,
            ref,
            'Meia-noite',
            AppThemeMode.midnight,
            currentTheme == AppThemeMode.midnight,
          ),
          const Divider(),

          _buildSectionHeader(context, 'Texto'),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tamanho da Fonte: ${readerSettings.fontSize.toInt()}'),
                Slider(
                  value: readerSettings.fontSize,
                  min: 12.0,
                  max: 32.0,
                  divisions: 10,
                  onChanged: (double value) {
                    ref
                        .read(readerSettingsProvider.notifier)
                        .setFontSize(value);
                  },
                ),
                const SizedBox(height: 16),
                const Text('Estilo da Fonte'),
                const SizedBox(height: 8),
                ToggleButtons(
                  isSelected: [
                    readerSettings.fontFamily == 'Merriweather',
                    readerSettings.fontFamily != 'Merriweather',
                  ],
                  onPressed: (index) {
                    if (index == 0) {
                      ref
                          .read(readerSettingsProvider.notifier)
                          .setFontFamily('Merriweather');
                    } else {
                      ref
                          .read(readerSettingsProvider.notifier)
                          .setFontFamily('Roboto');
                    }
                  },
                  borderRadius: BorderRadius.circular(8.0),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Icon(Icons.check, size: 16),
                          SizedBox(width: 4),
                          Text('Serifa'),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('Sem Serifa'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: readerSettings.fontFamily,
                  decoration: const InputDecoration(
                    labelText: 'Fonte',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Merriweather', child: Text('Merriweather (Serif)')),
                    DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
                    DropdownMenuItem(value: 'Open Sans', child: Text('Open Sans')),
                    DropdownMenuItem(value: 'Lato', child: Text('Lato')),
                    DropdownMenuItem(value: 'Sora', child: Text('Sora')),
                    DropdownMenuItem(value: 'Inter', child: Text('Inter')),
                    DropdownMenuItem(value: 'Montserrat', child: Text('Montserrat')),
                    DropdownMenuItem(value: 'Poppins', child: Text('Poppins')),
                    DropdownMenuItem(value: 'Source Sans 3', child: Text('Source Sans 3')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    ref.read(readerSettingsProvider.notifier).setFontFamily(value);
                  },
                ),
              ],
            ),
          ),
          const Divider(),

          _buildSectionHeader(context, 'Nuvem & Backup'),
          SwitchListTile(
            title: const Text('Conectar Google Drive'),
            subtitle: Text(
              readerSettings.cloudAccountEmail != null
                  ? 'Conectado: ${readerSettings.cloudAccountEmail}'
                  : 'Sincronizar livros e progresso',
            ),
            value: readerSettings.isCloudSyncEnabled,
            secondary: const Icon(Icons.cloud_upload),
            onChanged: readerSettings.isCloudSyncLoading
                ? null
                : (value) async {
                    final ok = await ref
                        .read(readerSettingsProvider.notifier)
                        .toggleCloudSync(value);

                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? 'Não foi possível conectar ao Google Drive.'
                                : 'Não foi possível desconectar do Google Drive.',
                          ),
                        ),
                      );
                    }
                  },
          ),
          if (readerSettings.isCloudSyncLoading)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const Divider(),

          _buildSectionHeader(context, 'Armazenamento'),
          ListTile(
            leading: const Icon(Icons.cleaning_services),
            title: const Text('Limpar Cache de Capas'),
            onTap: () async {
              await ref.read(libraryProvider.notifier).clearCoversCache();
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Cache limpo!')));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Apagar Todos os Livros',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Apagar todos os livros'),
                    content: const Text(
                      'Isso vai remover todos os livros da sua biblioteca e apagar os arquivos gerenciados pelo app. Deseja continuar?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Apagar'),
                      ),
                    ],
                  );
                },
              );

              if (confirmed != true) return;

              await ref.read(libraryProvider.notifier).clearAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Biblioteca apagada com sucesso.')),
                );
              }
            },
          ),
          const Divider(),

          _buildSectionHeader(context, 'Sobre'),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Ver tutorial'),
            subtitle: const Text('Aprenda a usar o app na primeira vez'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => OnboardingScreen(
                    onFinish: () {
                      ref
                          .read(readerSettingsProvider.notifier)
                          .setOnboardingSeen(true);
                      Navigator.pop(context);
                    },
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('Verificar atualizações'),
            subtitle: const Text('GitHub Releases'),
            onTap: () => _checkForUpdates(context),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Versão'),
            trailing: FutureBuilder<String>(
              future: _getVersionLabel(),
              builder: (context, snapshot) {
                return Text(snapshot.data ?? '...');
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Termos de Uso'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TermsScreen()),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildThemeItem(
    BuildContext context,
    WidgetRef ref,
    String label,
    AppThemeMode mode,
    bool isSelected,
  ) {
    return ListTile(
      title: Text(label),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).primaryColor)
          : null,
      onTap: () {
        ref
            .read(readerSettingsProvider.notifier)
            .updateIsDarkMode(false); // Reset manual override
        ref.read(themeProvider.notifier).setTheme(mode);
      },
    );
  }
}
