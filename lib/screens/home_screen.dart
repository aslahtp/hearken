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

class HomeScreen extends StatefulWidget {
  final Function(String transcript, String notes)? onNotesUpdated;
  
  const HomeScreen({this.onNotesUpdated, super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  String? _selectedAudioName;
  Map<String, String>? _serverResponse;
  bool _isLoading = false;
  Uint8List? _audioBytes;
  String? _audioUrl;
  bool _isRecording = false;
  bool _isProcessing = false;
  String _recordingStatus = '';
  final GlobalKey<NotesScreenState> _notesKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;  // This ensures the state is kept alive

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

      // Update notes screen with new content
      final notesScreen = _notesKey.currentState;
      if (notesScreen != null) {
        notesScreen.updateNotes(transcript['transcript']!, transcript['notes']!);
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

  void _copyToClipboard() async {
    if (_serverResponse != null) {
      await Clipboard.setData(ClipboardData(text: _serverResponse!['transcript'] ?? 'No transcript available'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Text copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _processAudio(File audioFile) async {
    setState(() {
      _isProcessing = true;
      _recordingStatus = 'Processing audio...';
    });

    try {
      // Upload audio file
      final audioUrl = await SupabaseService().uploadAudio(audioFile);
      
      // Process audio and get transcript and notes
      final result = await SupabaseService().processAudioUrl(audioUrl);
      
      // Update notes through callback
      widget.onNotesUpdated?.call(result['transcript']!, result['notes']!);

      setState(() {
        _recordingStatus = 'Processing complete!';
      });
    } catch (e) {
      setState(() {
        _recordingStatus = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);  // Required by AutomaticKeepAliveClientMixin
    return SingleChildScrollView(  // Make entire content scrollable
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),  // Add some padding at top
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
                child: Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Audio Transcript:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.5,  // Limit height to 50% of screen
                          ),
                          child: SingleChildScrollView(  // Make response text scrollable
                            child: SelectableText(  // Make text selectable
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
                              onPressed: _copyToClipboard,
                              icon: const Icon(Icons.copy),
                              label: const Text('Copy'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),  // Add some padding at bottom
            if (_isProcessing)
              const CircularProgressIndicator()
            else
              IconButton(
                icon: Icon(
                  _isRecording ? Icons.stop_circle : Icons.mic,
                  size: 64,
                  color: _isRecording
                      ? Colors.red
                      : Theme.of(context).colorScheme.primary,
                ),
                onPressed: _isProcessing ? null : _toggleRecording,
              ),
            const SizedBox(height: 16),
            Text(
              _recordingStatus,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  void _toggleRecording() {
    // Implement recording logic here
    // When recording is complete, call _processAudio(audioFile)
  }
} 