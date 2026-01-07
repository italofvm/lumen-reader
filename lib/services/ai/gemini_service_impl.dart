import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_service.dart';

class GeminiServiceImpl implements AIService {
  final String apiKey;
  late final GenerativeModel _model;

  GeminiServiceImpl({required this.apiKey}) {
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
  }

  @override
  Future<String> explainText(String text) async {
    final prompt =
        'Explique de forma clara e concisa o seguinte trecho de um livro: "$text"';
    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);
    return response.text ?? 'Não foi possível gerar uma explicação.';
  }

  @override
  Future<String> summarizeContent(String text) async {
    final prompt = 'Resuma os pontos principais do seguinte conteúdo: "$text"';
    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);
    return response.text ?? 'Não foi possível gerar um resumo.';
  }

  @override
  Future<String> askBookQuestion({
    required String question,
    required String contextText,
    required String sourceLabel,
  }) async {
    final prompt =
        'Você é um assistente de leitura. Responda a pergunta abaixo usando APENAS o contexto fornecido.\n\n'
        'REGRAS:\n'
        '- Se o contexto não for suficiente, diga explicitamente que não encontrou no trecho fornecido.\n'
        '- Ao final, inclua uma seção "Citações" com 1 a 3 trechos curtos do contexto (copiados) e informe a origem como: $sourceLabel.\n\n'
        'PERGUNTA:\n$question\n\n'
        'CONTEXTO ($sourceLabel):\n"""\n$contextText\n"""\n';

    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);
    return response.text ?? 'Não foi possível gerar uma resposta.';
  }
}
