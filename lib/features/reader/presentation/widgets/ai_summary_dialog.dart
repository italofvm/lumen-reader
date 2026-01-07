import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/ai/ai_providers.dart';

class AISummaryDialog extends ConsumerStatefulWidget {
  final String content;
  final String title;

  const AISummaryDialog({
    super.key,
    required this.content,
    required this.title,
  });

  @override
  ConsumerState<AISummaryDialog> createState() => _AISummaryDialogState();
}

class _AISummaryDialogState extends ConsumerState<AISummaryDialog> {
  Future<String>? _future;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final aiService = ref.read(aiServiceProvider);
    setState(() {
      _future = aiService.summarizeContent(widget.content.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Resumo: ${widget.title}'),
      content: SizedBox(
        width: 520,
        child: FutureBuilder<String>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Resumindo a página...',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Não foi possível gerar o resumo.',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      snapshot.error.toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _start,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              );
            }

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: SingleChildScrollView(
                child: SelectableText(
                  snapshot.data ?? 'Nenhum resumo gerado.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
