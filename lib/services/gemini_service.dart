import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  static const String apiKey = 'AIzaSyB_SZOdptCdmM3KMPS2X2mA772DHGOMgOk'; // Replace with your API key
  late final GenerativeModel _model;

  void initialize() {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey
    );
  }

  Future<String> processTranscript(String transcript) async {
    try {
      final prompt = '''
        Convert the following transcript into well-organized notes in markdown format.
        Make it concise, clear, and well-structured with proper headings, bullet points, 
        and emphasis where needed. Highlight key points and organize related information together.

        Transcript:
        $transcript
      ''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      return response.text ?? 'Failed to process transcript';
    } catch (e) {
      throw Exception('Failed to process transcript with Gemini: $e');
    }
  }
} 