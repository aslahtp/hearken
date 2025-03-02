import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'gemini_service.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const String supabaseUrl = 'https://cvlqvckhpevzzynfxvka.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN2bHF2Y2tocGV2enp5bmZ4dmthIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA3NjczNDUsImV4cCI6MjA1NjM0MzM0NX0.ozptCqMkD-MutucMfTqV2ps-aWHkEEtyxBCc2WLwpes';
  //static const String backendUrl = 'http://176.20.0.92:5000';

  Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  SupabaseClient get client => Supabase.instance.client;

  // Authentication methods
  Future<void> signUp({
    required String email,
    required String password,
    required String role,
    required String fullName,
  }) async {
    final AuthResponse res = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': role,
      },
    );

    if (res.user != null) {
      // Create profile after successful signup
      await client.from('profiles').upsert({
        'id': res.user!.id,
        'email': email,
        'full_name': fullName,
        'role': role,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  Future<User?> getCurrentUser() async {
    return client.auth.currentUser;
  }

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<String> uploadAudio(File audioFile) async {
    try {
      final String fileName = const Uuid().v4();
      final String filePath = 'audio/$fileName.mp3';
      
      await client.storage.from('audio').upload(
        filePath,
        audioFile,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: false,
        ),
      );

      // Get a signed URL that will be valid for 1 hour
      final String signedUrl = await client.storage.from('audio')
          .createSignedUrl(filePath, 3600); // 3600 seconds = 1 hour
      return signedUrl;
    } catch (e) {
      if (e.toString().contains('Unauthorized') || e.toString().contains('403')) {
        throw Exception(
          'Storage permission denied. Please ensure:\n'
          '1. You are signed in\n'
          '2. The "audio" bucket exists in Supabase storage\n'
          '3. The bucket has proper policies set up for authenticated users\n'
          '4. You have enabled storage in your Supabase project'
        );
      } else if (e.toString().contains('404')) {
        throw Exception(
          'Audio bucket not found. Please verify that:\n'
          '1. You have created a bucket named exactly "audio" (case sensitive)\n'
          '2. The bucket is set to "authenticated" access level\n'
          '3. Storage is enabled in your Supabase project settings'
        );
      }
      throw Exception('Failed to upload audio: $e');
    }
  }

  Future<Map<String, String>> processAudioUrl(String audioUrl) async {
    try {
      print('Processing audio URL: $audioUrl'); // Debug log
      
      // First verify the audio URL is accessible
      final audioResponse = await http.get(Uri.parse(audioUrl));
      if (audioResponse.statusCode != 200) {
        throw Exception('Audio file not accessible: Status ${audioResponse.statusCode}');
      }

      final response = await http.post(
        Uri.parse('https://stirring-terrier-recently.ngrok-free.app/process-audio'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': '1',
        },
        body: jsonEncode({
          'audio_url': audioUrl,
        }),
      );

      print('Response status code: ${response.statusCode}'); // Debug log
      print('Response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final transcript = responseData['transcript'] ?? 'No transcript available';
        
        // For now, return the transcript as both transcript and notes
        // until Gemini service is properly integrated
        return {
          'transcript': transcript,
          'notes': transcript,
        };
      } else if (response.statusCode == 404) {
        throw Exception('Processing endpoint not available. Please check if the Flask server is running and ngrok is configured correctly.');
      } else {
        throw Exception('Failed to process audio: Status ${response.statusCode}');
      }
    } catch (e) {
      print('Error processing audio: $e'); // Debug log
      throw Exception('Failed to process audio: $e');
    }
  }
} 