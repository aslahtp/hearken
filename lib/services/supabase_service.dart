import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

      final String publicUrl = client.storage.from('audio').getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      if (e.toString().contains('403')) {
        throw Exception(
          'Unauthorized: Please check your Supabase storage permissions. '
          'Make sure the "audio" bucket is public and has proper policies set up.'
        );
      } else if (e.toString().contains('404')) {
        throw Exception(
          'Audio bucket not found. Please verify that:\n'
          '1. You have created a bucket named exactly "audio" (case sensitive)\n'
          '2. The bucket is public\n'
          '3. You have set up the correct storage policies'
        );
      }
      throw Exception('Failed to upload audio: $e');
    }
  }

  Future<String> processAudioUrl(String audioUrl) async {
    try {
      final response = await http.post(
        Uri.parse('https://stirring-terrier-recently.ngrok-free.app/process-audio'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': '*/*',
          'ngrok-skip-browser-warning': '1',
        },
        body: jsonEncode({
          'audio_url': audioUrl,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['transcript'] ?? 'No transcript available';
      } else {
        throw Exception('Failed to process audio: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to process audio: $e');
    }
  }
} 