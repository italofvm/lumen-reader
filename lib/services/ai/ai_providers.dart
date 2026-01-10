import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_reader/core/config/app_config.dart';
import 'ai_service.dart';
import 'ai_proxy_service_impl.dart';
import 'gemini_service_impl.dart';

const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

class _MissingKeyAIService implements AIService {
  String _msg() {
    return 'A IA ainda não está disponível neste app.\n\n'
        'Atualize o aplicativo ou tente novamente mais tarde.';
  }

  @override
  Future<String> explainText(String text) async {
    return _msg();
  }

  @override
  Future<String> summarizeContent(String content) async {
    return _msg();
  }

  @override
  Future<String> askBookQuestion({
    required String question,
    required String contextText,
    required String sourceLabel,
  }) async {
    return _msg();
  }
}

final aiServiceProvider = Provider<AIService>((ref) {
  final proxyUrl = AppConfig.aiProxyUrl.trim();
  if (proxyUrl.isNotEmpty && !proxyUrl.contains('SEU-AI-PROXY')) {
    return AIProxyServiceImpl(baseUrl: proxyUrl);
  }
  if (_apiKey.trim().isEmpty) {
    return _MissingKeyAIService();
  }
  return GeminiServiceImpl(apiKey: _apiKey);
});
