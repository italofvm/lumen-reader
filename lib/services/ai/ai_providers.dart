import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_service.dart';
import 'gemini_service_impl.dart';

const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

class _MissingKeyAIService implements AIService {
  @override
  Future<String> explainText(String text) async {
    return 'Chave da Gemini não configurada. Execute com --dart-define=GEMINI_API_KEY=...';
  }

  @override
  Future<String> summarizeContent(String content) async {
    return 'Chave da Gemini não configurada. Execute com --dart-define=GEMINI_API_KEY=...';
  }

  @override
  Future<String> askBookQuestion({
    required String question,
    required String contextText,
    required String sourceLabel,
  }) async {
    return 'Chave da Gemini não configurada. Execute com --dart-define=GEMINI_API_KEY=...';
  }
}

final aiServiceProvider = Provider<AIService>((ref) {
  if (_apiKey.trim().isEmpty) {
    return _MissingKeyAIService();
  }
  return GeminiServiceImpl(apiKey: _apiKey);
});
