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
  String _processingStage = '';
  Uint8List? _audioBytes;
  String? _audioUrl;
  String _summaryLevel = 'medium';

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
      _processingStage = 'Preparing audio file';
      _serverResponse = null;
    });

    try {
      // Create a temporary file from bytes
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/${_selectedAudioName}');
      await tempFile.writeAsBytes(_audioBytes!);

      setState(() {
        _processingStage = 'Uploading audio';
      });

      // First upload to Supabase
      final publicUrl = await SupabaseService().uploadAudio(tempFile);
      
      // Delete the temporary file
      await tempFile.delete();

      setState(() {
        _processingStage = 'Transcribing audio';
      });

      // Now process the audio URL
      final transcript = await SupabaseService().processAudioUrl(
        publicUrl,
        onAiStageChange: (stage) {
          if (mounted) {
            setState(() {
              _processingStage = stage;
            });
          }
        },
      );

      setState(() {
        _audioUrl = publicUrl;
        _serverResponse = transcript;
        _isLoading = false;
        _processingStage = '';
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
        setState(() {
          _isLoading = false;
          _processingStage = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _copyToClipboard(String type) async {
    if (_serverResponse != null) {
      final textToCopy = switch (type) {
        'transcript' => _serverResponse!['transcript'],
        'notes' => _serverResponse!['notes'],
        'actionableItems' => _serverResponse!['actionableItems'],
        _ => null,
      };
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
                    // Add summary level selector
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Summary Level:',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'short',
                                    label: Text('Short'),
                                    icon: Icon(Icons.short_text),
                                    tooltip: 'Concise summary with key points only',
                                  ),
                                  ButtonSegment(
                                    value: 'medium',
                                    label: Text('Medium'),
                                    icon: Icon(Icons.subject),
                                    tooltip: 'Balanced summary with main points and important details',
                                  ),
                                  ButtonSegment(
                                    value: 'detailed',
                                    label: Text('Detailed'),
                                    icon: Icon(Icons.description),
                                    tooltip: 'Comprehensive summary with detailed information',
                                  ),
                                ],
                                selected: {_summaryLevel},
                                onSelectionChanged: (Set<String> selection) {
                                  setState(() {
                                    _summaryLevel = selection.first;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
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
                      label: Text(_isLoading ? _processingStage : 'Process Audio'),
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
                                                      h1: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                                        fontWeight: FontWeight.bold,
                                                        color: Theme.of(context).colorScheme.primary,
                                                      ),
                                                      h2: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                        fontWeight: FontWeight.bold,
                                                        color: Theme.of(context).colorScheme.secondary,
                                                      ),
                                                      h3: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                        fontWeight: FontWeight.bold,
                                                        color: Theme.of(context).colorScheme.tertiary,
                                                      ),
                                                      p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                        height: 1.5,
                                                      ),
                                                      listBullet: Theme.of(context).textTheme.bodyMedium,
                                                      blockquote: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                        color: Theme.of(context).colorScheme.secondary,
                                                      ),
                                                      code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                        fontFamily: 'monospace',
                                                        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                                                      ),
                                                      codeblockPadding: const EdgeInsets.all(8),
                                                      blockSpacing: 16,
                                                      listIndent: 24,
                                                      blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                      blockquoteDecoration: BoxDecoration(
                                                        border: Border(
                                                          left: BorderSide(
                                                            color: Theme.of(context).colorScheme.secondary,
                                                            width: 4,
                                                          ),
                                                        ),
                                                      ),
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
                                    h1: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    h2: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                    h3: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.tertiary,
                                    ),
                                    p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      height: 1.5,
                                    ),
                                    listBullet: Theme.of(context).textTheme.bodyMedium,
                                    blockquote: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                    code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontFamily: 'monospace',
                                      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                                    ),
                                    codeblockPadding: const EdgeInsets.all(8),
                                    blockSpacing: 16,
                                    listIndent: 24,
                                    blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    blockquoteDecoration: BoxDecoration(
                                      border: Border(
                                        left: BorderSide(
                                          color: Theme.of(context).colorScheme.secondary,
                                          width: 4,
                                        ),
                                      ),
                                    ),
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
                    const SizedBox(height: 16),
                    // Actionable Items Card
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.5),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'To Do Items:',
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
                                            title: const Text('Actionable Items'),
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
                                                    data: _serverResponse!['actionableItems'] ?? 'No actionable items available',
                                                    selectable: true,
                                                    styleSheet: MarkdownStyleSheet(
                                                      h1: Theme.of(context).textTheme.headlineMedium,
                                                      h2: Theme.of(context).textTheme.titleLarge,
                                                      h3: Theme.of(context).textTheme.titleMedium,
                                                      p: Theme.of(context).textTheme.bodyMedium,
                                                      listBullet: Theme.of(context).textTheme.bodyMedium,
                                                      blockquote: Theme.of(context).textTheme.bodyMedium,
                                                      code: Theme.of(context).textTheme.bodyMedium,
                                                    ),
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
                                child: MarkdownBody(
                                  data: _serverResponse!['actionableItems'] ?? 'No actionable items available',
                                  selectable: true,
                                  styleSheet: MarkdownStyleSheet(
                                    h1: Theme.of(context).textTheme.headlineMedium,
                                    h2: Theme.of(context).textTheme.titleLarge,
                                    h3: Theme.of(context).textTheme.titleMedium,
                                    p: Theme.of(context).textTheme.bodyMedium,
                                    listBullet: Theme.of(context).textTheme.bodyMedium,
                                    blockquote: Theme.of(context).textTheme.bodyMedium,
                                    code: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _copyToClipboard('actionableItems'),
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