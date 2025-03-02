import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import 'dart:io';
import 'notes_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  String? _selectedAudioName;
  Map<String, String>? _serverResponse;
  bool _isLoading = false;
  Uint8List? _audioBytes;
  String? _audioUrl;

  @override
  bool get wantKeepAlive => true;

  Future<void> _pickAudioFile() async {
    try {
      final XTypeGroup audioGroup = XTypeGroup(
        label: 'Audio',
        extensions: ['mp3', 'wav', 'm4a', 'aac', 'wma'],
      );

      final XFile? file = await openFile(
        acceptedTypeGroups: [audioGroup],
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _audioBytes = bytes;
          _selectedAudioName = file.name;
          _audioUrl = null;
          _serverResponse = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking audio file: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _uploadAudioFile() async {
    if (_audioBytes == null || _selectedAudioName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an audio file first')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _serverResponse = null;
    });

    try {
      // Create a temporary file from bytes
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/${_selectedAudioName}');
      await tempFile.writeAsBytes(_audioBytes!);

      // First upload to Supabase
      final publicUrl = await SupabaseService().uploadAudio(tempFile);
      
      // Delete the temporary file
      await tempFile.delete();

      // Now process the audio URL
      final transcript = await SupabaseService().processAudioUrl(publicUrl);

      setState(() {
        _audioUrl = publicUrl;
        _serverResponse = transcript;
      });

      // Show a success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio processed successfully and saved to your notes'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String type) async {
    if (_serverResponse != null) {
      final textToCopy = type == 'transcript' 
          ? _serverResponse!['transcript'] 
          : _serverResponse!['notes'];
      await Clipboard.setData(ClipboardData(text: textToCopy ?? ''));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${type.capitalize()} copied to clipboard'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickAudioFile,
              icon: const Icon(Icons.audio_file),
              label: const Text('Pick Audio File'),
            ),
            if (_selectedAudioName != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Selected: $_selectedAudioName',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _uploadAudioFile,
                      icon: _isLoading 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload),
                      label: Text(_isLoading ? 'Processing...' : 'Process Audio'),
                    ),
                  ],
                ),
              ),
            if (_serverResponse != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Transcript Card
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Audio Transcript:',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.fullscreen),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => Dialog.fullscreen(
                                        child: Scaffold(
                                          appBar: AppBar(
                                            title: const Text('Audio Transcript'),
                                            leading: IconButton(
                                              icon: const Icon(Icons.close),
                                              onPressed: () => Navigator.of(context).pop(),
                                            ),
                                          ),
                                          body: SafeArea(
                                            child: SingleChildScrollView(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  SelectableText(
                                                    _serverResponse!['transcript'] ?? 'No transcript available',
                                                    style: Theme.of(context).textTheme.bodyMedium,
                                                  ),
                                                  const SizedBox(height: 32),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              constraints: BoxConstraints(
                                maxHeight: MediaQuery.of(context).size.height * 0.3,
                              ),
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  _serverResponse!['transcript'] ?? 'No transcript available',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _copyToClipboard('transcript'),
                                  icon: const Icon(Icons.copy),
                                  label: const Text('Copy'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Processed Notes Card
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Lecture Notes:',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.fullscreen),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => Dialog.fullscreen(
                                        child: Scaffold(
                                          appBar: AppBar(
                                            title: const Text('Lecture Notes'),
                                            leading: IconButton(
                                              icon: const Icon(Icons.close),
                                              onPressed: () => Navigator.of(context).pop(),
                                            ),
                                          ),
                                          body: SafeArea(
                                            child: SingleChildScrollView(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  MarkdownBody(
                                                    data: _serverResponse!['notes'] ?? 'No notes available',
                                                    selectable: true,
                                                    styleSheet: MarkdownStyleSheet(
                                                      p: Theme.of(context).textTheme.bodyMedium,
                                                      h1: Theme.of(context).textTheme.headlineMedium,
                                                      h2: Theme.of(context).textTheme.titleLarge,
                                                      h3: Theme.of(context).textTheme.titleMedium,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 32), // Add bottom padding
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              constraints: BoxConstraints(
                                maxHeight: MediaQuery.of(context).size.height * 0.5,
                              ),
                              child: SingleChildScrollView(
                                child: MarkdownBody(
                                  data: _serverResponse!['notes'] ?? 'No notes available',
                                  selectable: true,
                                  styleSheet: MarkdownStyleSheet(
                                    p: Theme.of(context).textTheme.bodyMedium,
                                    h1: Theme.of(context).textTheme.headlineMedium,
                                    h2: Theme.of(context).textTheme.titleLarge,
                                    h3: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _copyToClipboard('notes'),
                                  icon: const Icon(Icons.copy),
                                  label: const Text('Copy'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
} 