abstract class AIService {
  Future<String> explainText(String text);
  Future<String> summarizeContent(String content);
  Future<String> askBookQuestion({
    required String question,
    required String contextText,
    required String sourceLabel,
  });
}
