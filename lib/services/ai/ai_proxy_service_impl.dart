import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_service.dart';

class AIProxyServiceImpl implements AIService {
  final String baseUrl;
  final http.Client _client;

  AIProxyServiceImpl({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri _askUri() {
    var b = baseUrl.trim();
    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    return Uri.parse('$b/v1/ai/ask');
  }

  Future<String> _ask({
    required String question,
    required String contextText,
    required String sourceLabel,
  }) async {
    final res = await _client.post(
      _askUri(),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'question': question,
        'contextText': contextText,
        'sourceLabel': sourceLabel,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('AI proxy erro: HTTP ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) {
      final text = data['text'];
      if (text is String && text.trim().isNotEmpty) return text;
      final err = data['error'];
      if (err is String && err.trim().isNotEmpty) {
        throw Exception(err);
      }
    }

    return 'Não foi possível gerar uma resposta.';
  }

  @override
  Future<String> askBookQuestion({
    required String question,
    required String contextText,
    required String sourceLabel,
  }) {
    return _ask(
      question: question,
      contextText: contextText,
      sourceLabel: sourceLabel,
    );
  }

  @override
  Future<String> explainText(String text) {
    return _ask(
      question: 'Explique de forma clara e concisa o seguinte trecho.',
      contextText: text,
      sourceLabel: 'Trecho selecionado',
    );
  }

  @override
  Future<String> summarizeContent(String content) {
    return _ask(
      question: 'Resuma os pontos principais do conteúdo abaixo.',
      contextText: content,
      sourceLabel: 'Conteúdo',
    );
  }
}
