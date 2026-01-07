import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumen_reader/services/ai/ai_providers.dart';

class AskBookDialog extends ConsumerStatefulWidget {
  final String title;
  final String contextText;
  final String sourceLabel;

  const AskBookDialog({
    super.key,
    required this.title,
    required this.contextText,
    required this.sourceLabel,
  });

  @override
  ConsumerState<AskBookDialog> createState() => _AskBookDialogState();
}

class _AskBookDialogState extends ConsumerState<AskBookDialog> {
  final TextEditingController _controller = TextEditingController();
  Future<String>? _future;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ask() {
    final question = _controller.text.trim();
    if (question.isEmpty) return;

    final ai = ref.read(aiServiceProvider);
    setState(() {
      _future = ai.askBookQuestion(
        question: question,
        contextText: widget.contextText,
        sourceLabel: widget.sourceLabel,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Pergunte ao livro: ${widget.title}'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.sourceLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _ask(),
              decoration: const InputDecoration(
                labelText: 'Sua pergunta',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            if (_future != null)
              Flexible(
                child: FutureBuilder<String>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('A Gemini está analisando o contexto...'),
                        ],
                      );
                    }
                    if (snapshot.hasError) {
                      return SingleChildScrollView(
                        child: Text('Erro: ${snapshot.error}'),
                      );
                    }

                    return SingleChildScrollView(
                      child: Text(snapshot.data ?? 'Sem resposta.'),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
        TextButton(
          onPressed: _ask,
          child: const Text('Perguntar'),
        ),
      ],
    );
  }
}
