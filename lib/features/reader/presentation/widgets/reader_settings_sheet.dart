import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_reader/features/settings/domain/providers/settings_providers.dart';

class ReaderSettingsSheet extends ConsumerWidget {
  const ReaderSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configurações de Leitura',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),

                  // Brightness
                  Row(
                    children: [
                      const Icon(Icons.brightness_medium),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Slider(
                          value: settings.brightness,
                          onChanged: (val) => notifier.setBrightness(val),
                        ),
                      ),
                    ],
                  ),

                  // Zoom
                  Row(
                    children: [
                      const Icon(Icons.zoom_in),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Slider(
                          value: settings.zoom,
                          min: 0.5,
                          max: 3.0,
                          onChanged: (val) => notifier.setZoom(val),
                        ),
                      ),
                      Text('${(settings.zoom * 100).toInt()}%'),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Direção da Leitura',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  ToggleButtons(
                    isSelected: [!settings.isHorizontal, settings.isHorizontal],
                    onPressed: (index) {
                      notifier.setIsHorizontal(index == 1);
                    },
                    borderRadius: BorderRadius.circular(8),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Icon(Icons.swap_vert),
                            SizedBox(width: 8),
                            Text('Vertical'),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Icon(Icons.swap_horiz),
                            SizedBox(width: 8),
                            Text('Horizontal'),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'Animação de Página',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  ToggleButtons(
                    isSelected: [
                      settings.pageTransition == 'slide',
                      settings.pageTransition == 'fade',
                      settings.pageTransition == 'stack',
                      settings.pageTransition == 'none',
                    ],
                    onPressed: (index) {
                      final transitions = ['slide', 'fade', 'stack', 'none'];
                      notifier.setPageTransition(transitions[index]);
                    },
                    borderRadius: BorderRadius.circular(8),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.slideshow),
                            Text('Slide', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.blur_on),
                            Text('Fade', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.layers),
                            Text('Stack', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flash_off),
                            Text('Nenhum', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'Modo de Cor',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ColorModeButton(
                        mode: 'normal',
                        color: Colors.white,
                        isSelected: settings.colorMode == 'normal',
                        onTap: () => notifier.setColorMode('normal'),
                      ),
                      _ColorModeButton(
                        mode: 'sepia',
                        color: const Color(0xFFF4ECD8),
                        isSelected: settings.colorMode == 'sepia',
                        onTap: () => notifier.setColorMode('sepia'),
                      ),
                      _ColorModeButton(
                        mode: 'paper',
                        color: const Color(0xFFFAF9F6),
                        isSelected: settings.colorMode == 'paper',
                        onTap: () => notifier.setColorMode('paper'),
                      ),
                      _ColorModeButton(
                        mode: 'dark',
                        color: const Color(0xFF121212),
                        isSelected: settings.colorMode == 'dark',
                        onTap: () => notifier.setColorMode('dark'),
                      ),
                      _ColorModeButton(
                        mode: 'midnight',
                        color: Colors.black,
                        isSelected: settings.colorMode == 'midnight',
                        onTap: () => notifier.setColorMode('midnight'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorModeButton extends StatelessWidget {
  final String mode;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorModeButton({
    required this.mode,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 4,
                spreadRadius: 1,
              ),
          ],
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
              )
            : null,
      ),
    );
  }
}
