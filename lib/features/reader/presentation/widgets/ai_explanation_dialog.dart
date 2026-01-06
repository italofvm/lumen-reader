import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/ai/ai_providers.dart';

class AIExplanationDialog extends ConsumerWidget {
  final String selectedText;

  const AIExplanationDialog({super.key, required this.selectedText});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiService = ref.watch(aiServiceProvider);

    return AlertDialog(
      title: const Text('Explicação da IA'),
      content: FutureBuilder<String>(
        future: aiService.explainText(selectedText),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('A Gemini está processando...'),
              ],
            );
          } else if (snapshot.hasError) {
            return Text('Erro: ${snapshot.error}');
          } else {
            return SingleChildScrollView(
              child: Text(snapshot.data ?? 'Nenhuma resposta.'),
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
