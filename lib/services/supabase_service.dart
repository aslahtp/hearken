import 'dart:io';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/gemini_service.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  
  final GeminiService _geminiService = GeminiService();
  
  SupabaseService._internal() {
    // Initialize Gemini service when SupabaseService is created
    _geminiService.initialize();
  }

  static const String supabaseUrl = 'https://cvlqvckhpevzzynfxvka.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN2bHF2Y2tocGV2enp5bmZ4dmthIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA3NjczNDUsImV4cCI6MjA1NjM0MzM0NX0.ozptCqMkD-MutucMfTqV2ps-aWHkEEtyxBCc2WLwpes';
  //static const String backendUrl = 'http://176.20.0.92:5000';

  // Add a retry mechanism for initialization
  Future<void> initialize() async {
    int retryCount = 0;
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    while (retryCount < maxRetries) {
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey,
          headers: {
            'X-Client-Info': 'hearken-db',
          },
          storageOptions: const StorageClientOptions(
            retryAttempts: 3,
          ),
        );
        return; // Success, exit the retry loop
      } catch (e) {
        retryCount++;
        if (retryCount == maxRetries) {
          if (e.toString().contains('Failed host lookup')) {
            throw Exception(
              'Unable to connect to Supabase. Please check your internet connection and try again.\n'
              'If the problem persists, please ensure you have a stable internet connection.'
            );
          }
          throw Exception('Failed to initialize Supabase: $e');
        }
        await Future.delayed(retryDelay);
      }
    }
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

  // Improved connectivity check with timeout and multiple attempts
  Future<bool> checkConnectivity() async {
    int attempts = 0;
    const maxAttempts = 3; // Increased from 2 to 3 attempts
    
    while (attempts < maxAttempts) {
      try {
        // Try to connect to Supabase
        final response = await http.get(
          Uri.parse('$supabaseUrl/rest/v1/?apikey=$supabaseAnonKey'),
          headers: {
            'X-Client-Info': 'hearken-db',
            'Content-Type': 'application/json',
          },
        ).timeout(
          const Duration(seconds: 8), // Increased timeout from 5 to 8 seconds
          onTimeout: () => throw TimeoutException('Connection timed out'),
        );
        
        // If we get a successful response, return true
        return response.statusCode >= 200 && response.statusCode < 300;
      } catch (e) {
        print('Connectivity check attempt ${attempts + 1} failed: $e');
        attempts++;
        if (attempts == maxAttempts) {
          return false;
        }
        // Increase delay between attempts
        await Future.delayed(Duration(seconds: attempts));
      }
    }
    return false;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Check connectivity with a more informative error
      final isConnected = await checkConnectivity();
      if (!isConnected) {
        throw Exception(
          'Exception: Failed to sign in: Exception: Unable to connect to the server. Please:\n'
          '1. Check if you have an active internet connection\n'
          '2. Try switching between WiFi and mobile data\n'
          '3. Wait a few moments and try again'
        );
      }

      // Try to sign in with a longer timeout
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      ).timeout(
        const Duration(seconds: 15), // Increased from 10 to 15 seconds
        onTimeout: () => throw TimeoutException('Sign in request timed out'),
      );
      return response;
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception(
          'The connection timed out. Please check your internet connection and try again.'
        );
      }
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
          'Unable to connect to the server. Please:\n'
          '1. Check if you have an active internet connection\n'
          '2. Try switching between WiFi and mobile data\n'
          '3. Wait a few moments and try again'
        );
      }
      // Pass through the original error message
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

  Future<Map<String, String>> processAudioUrl(
    String audioUrl, {
    Function(String stage)? onAiStageChange,
  }) async {
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
        
        // Use the already initialized Gemini service
        final markdownNotes = await _geminiService.processTranscript(
          transcript,
          onStageChange: onAiStageChange,
        );
        
        // Save the transcript and notes to Supabase
        final currentUser = client.auth.currentUser;
        if (currentUser != null) {
          await saveNoteToDatabase(
            title: 'Note ${DateTime.now().toString().substring(0, 16)}',
            transcript: transcript,
            notes: markdownNotes,
            audioUrl: audioUrl,
          );
        }
        
        return {
          'transcript': transcript,
          'notes': markdownNotes,
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
  
  // Save note to Supabase database
  Future<void> saveNoteToDatabase({
    required String title,
    required String transcript,
    required String notes,
    required String audioUrl,
  }) async {
    try {
      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      await client.from('notes').insert({
        'user_id': currentUser.id,
        'title': title,
        'transcript': transcript,
        'notes': notes,
        'audio_url': audioUrl,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      print('Note saved successfully to database');
    } catch (e) {
      print('Error saving note to database: $e');
      throw Exception('Failed to save note: $e');
    }
  }
  
  // Get all notes for the current user
  Future<List<Map<String, dynamic>>> getUserNotes() async {
    try {
      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await client
          .from('notes')
          .select()
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching notes: $e');
      throw Exception('Failed to fetch notes: $e');
    }
  }
  
  // Get a specific note by ID
  Future<Map<String, dynamic>> getNoteById(String noteId) async {
    try {
      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await client
          .from('notes')
          .select()
          .eq('id', noteId)
          .eq('user_id', currentUser.id)
          .single();
      
      return response;
    } catch (e) {
      print('Error fetching note: $e');
      throw Exception('Failed to fetch note: $e');
    }
  }
  
  // Delete a note
  Future<void> deleteNote(String noteId) async {
    try {
      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      await client
          .from('notes')
          .delete()
          .eq('id', noteId)
          .eq('user_id', currentUser.id);
      
      print('Note deleted successfully');
    } catch (e) {
      print('Error deleting note: $e');
      throw Exception('Failed to delete note: $e');
    }
  }
} 