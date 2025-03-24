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
    String summaryLevel = 'medium',
    Function(String stage)? onStageChange,
  }) async {
    try {
      onStageChange?.call('Initializing AI model');
      
      // Adjust instructions based on summary level
      String levelInstructions = '';
      switch (summaryLevel) {
        case 'short':
          levelInstructions = 'Create a very concise summary of the key points. Keep it brief but capture the essential information.';
          break;
        case 'medium':
          levelInstructions = 'Create a balanced summary of the main points and supporting details.';
          break;
        case 'detailed':
          levelInstructions = 'Create a comprehensive summary that captures detailed information, examples, and explanations.';
          break;
        default:
          levelInstructions = 'Create a balanced summary of the main points and supporting details.';
      }
      
      final prompt = '''
        The input is a transcribe of a lecture audio.
        $levelInstructions
        Format the response in the following structure using proper markdown headers (# for h1, ## for h2, ### for h3):
        
        # Lecture Notes
        [Convert the transcript into lecture notes with markdown format.
        Use proper markdown headers:
        - Use # for main sections
        - Use ## for subsections
        - Use ### for sub-subsections
        - Use * or - for bullet points
        Enclose math notation inside \$\$ and code inside backticks.]

        # Actionable Items
        [List any actionable items such as homework, assignments, refer topics or textbook before next lecture, or tests that are mentioned.
        If no actionable items are mentioned, write "No actionable items mentioned in this lecture."]

        Transcript:
        $transcript
      ''';

      onStageChange?.call('Generating ${summaryLevel} lecture notes');
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      return response.text ?? 'Failed to process transcript';
    } catch (e) {
      throw Exception('Failed to process transcript with Gemini: $e');
    }
  }
} 