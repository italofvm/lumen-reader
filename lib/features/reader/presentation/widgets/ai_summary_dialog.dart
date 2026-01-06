import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/ai/ai_providers.dart';

class AISummaryDialog extends ConsumerWidget {
  final String content;
  final String title;

  const AISummaryDialog({
    super.key,
    required this.content,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiService = ref.watch(aiServiceProvider);

    return AlertDialog(
      title: Text('Resumo: $title'),
      content: FutureBuilder<String>(
        future: aiService.summarizeContent(content),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('A Gemini está resumindo o conteúdo...'),
              ],
            );
          } else if (snapshot.hasError) {
            return Text('Erro: ${snapshot.error}');
          } else {
            return SingleChildScrollView(
              child: Text(snapshot.data ?? 'Nenhum resumo gerado.'),
            );
          }
        },
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
