import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();


  // Get your API key from: https://makersuite.google.com/app/apikey
  static const String apiKey = 'AIzaSyB_SZOdptCdmM3KMPS2X2mA772DHGOMgOk';
  late final GenerativeModel _model;
  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return; // Prevent re-initialization
    
    if (apiKey == 'YOUR_GEMINI_API_KEY') {
      throw Exception('Please replace the Gemini API key in lib/services/gemini_service.dart');
    }
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );
    _isInitialized = true;
  }

  Future<String> processTranscript(
    String transcript, {
    Function(String stage)? onStageChange,
  }) async {
    try {
      onStageChange?.call('Initializing AI model');
      
      final prompt = '''
        The input is a transcribe of a lecture audio.
        Convert it into a lecture note with markdown format supporting in obsidian.
        Also list if any actionable items such as homework, assignments,refer topics or textbook before next lecture, or tests are mentioned.
        Enclose math notation inside \$\$ and code inside backticks.

        Transcript:
        $transcript
      ''';

      onStageChange?.call('Generating lecture notes');
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      return response.text ?? 'Failed to process transcript';
    } catch (e) {
      throw Exception('Failed to process transcript with Gemini: $e');
    }
  }
} 