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
  String? _lastAnswer;
  String? _lastError;
  bool _isLoading = false;

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
      _lastError = null;
      _isLoading = true;
      _future = ai.askBookQuestion(
        question: question,
        contextText: widget.contextText,
        sourceLabel: widget.sourceLabel,
      );
    });

    _future!.then((value) {
      if (!mounted) return;
      setState(() {
        _lastAnswer = value;
        _isLoading = false;
      });
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        _lastError = e.toString();
        _isLoading = false;
      });
    });
  }

  List<_AnswerBlock> _parseAnswer(String text) {
    final t = text.trim();
    if (t.isEmpty) return const [];

    final lines = t.split('\n');
    final blocks = <_AnswerBlock>[];

    final buf = StringBuffer();
    bool inCitations = false;

    void flushText() {
      final s = buf.toString().trim();
      buf.clear();
      if (s.isEmpty) return;
      blocks.add(_AnswerBlock.text(s));
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      final normalized = line.trim().toLowerCase();
      final isCitationsHeader =
          normalized == 'citações' || normalized == 'citacoes' ||
          normalized.startsWith('### cita');
      if (isCitationsHeader) {
        flushText();
        inCitations = true;
        continue;
      }

      if (!inCitations) {
        buf.writeln(line);
      } else {
        final l = line.trim();
        if (l.isEmpty) continue;
        blocks.add(_AnswerBlock.citation(l));
      }
    }

    flushText();
    return blocks;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookTitle = widget.title.trim().isEmpty ? 'Livro' : widget.title;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pergunte ao livro',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            bookTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.bookmark, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.sourceLabel,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _ask(),
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Sua pergunta',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _isLoading ? null : _ask,
                    child: const Text('Enviar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                Container(
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
                          'Analisando o trecho e montando a resposta...',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),

              if (_lastError != null && !_isLoading)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Não foi possível responder agora.',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _lastError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _ask,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              if (_lastAnswer != null && !_isLoading)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _AnswerView(blocks: _parseAnswer(_lastAnswer!)),
                  ),
                ),
            ],
          ),
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

class _AnswerBlock {
  final String text;
  final bool isCitation;

  const _AnswerBlock._(this.text, this.isCitation);

  factory _AnswerBlock.text(String text) => _AnswerBlock._(text, false);
  factory _AnswerBlock.citation(String text) => _AnswerBlock._(text, true);
}

class _AnswerView extends StatelessWidget {
  final List<_AnswerBlock> blocks;

  const _AnswerView({required this.blocks});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (blocks.isEmpty) {
      return Center(
        child: Text(
          'Sem resposta.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    final citations = blocks.where((b) => b.isCitation).toList(growable: false);
    final main = blocks.where((b) => !b.isCitation).toList(growable: false);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (main.isNotEmpty)
            SelectableText(
              main.map((b) => b.text).join('\n\n').trim(),
              style: theme.textTheme.bodyMedium,
            ),
          if (citations.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Citações',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...citations.map(
              (c) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: SelectableText(
                  c.text,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
