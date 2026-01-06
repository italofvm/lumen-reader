import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_service.dart';
import 'gemini_service_impl.dart';

// You should set your API key here or via env variable
const String _tempApiKey =
    'AIzaSyAYNEvC_vqefzmEKkuabVC4-S-mH-lynt0'; // Provided by user

final aiServiceProvider = Provider<AIService>((ref) {
  return GeminiServiceImpl(apiKey: _tempApiKey);
});
