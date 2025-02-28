import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'package:http/http.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  String? _selectedAudioName;
  String? _serverResponse;
  bool _isLoading = false;
  Uint8List? _audioBytes;

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
      final uri = Uri.parse('http://176.20.0.92:5000/process-audio');
      
      final request = http.MultipartRequest('POST', uri);
      
      // Add MIME type based on file extension
      String mimeType = 'audio/mpeg'; // default to mp3
      if (_selectedAudioName!.endsWith('.wav')) {
        mimeType = 'audio/wav';
      } else if (_selectedAudioName!.endsWith('.m4a')) {
        mimeType = 'audio/m4a';
      } else if (_selectedAudioName!.endsWith('.aac')) {
        mimeType = 'audio/aac';
      }

      // Create form data
      request.fields['filename'] = _selectedAudioName!;
      
      final multipartFile = http.MultipartFile.fromBytes(
        'audio',
        _audioBytes!,
        filename: _selectedAudioName,
        contentType: MediaType.parse(mimeType),
      );

      request.files.add(multipartFile);

      // Don't set Content-Type header manually, let it be set automatically
      request.headers.addAll({
        'Accept': '*/*',
      });

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          _serverResponse = responseData['transcript'] ?? responseData['message'];
        });
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to upload file: ${response.statusCode}');
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
      await Clipboard.setData(ClipboardData(text: _serverResponse!));
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
                              _serverResponse!,
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
          ],
        ),
      ),
    );
  }
} 