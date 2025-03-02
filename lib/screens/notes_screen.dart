import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/supabase_service.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  NotesScreenState createState() => NotesScreenState();
}

class NotesScreenState extends State<NotesScreen> {
  bool _isLoading = false;
  String _markdownContent = '';
  String _rawTranscript = '';
  bool _showRawTranscript = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notes',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Switch(
                value: _showRawTranscript,
                onChanged: (value) {
                  setState(() {
                    _showRawTranscript = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _showRawTranscript ? 'Raw Transcript' : 'Processed Notes',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _showRawTranscript
                          ? SingleChildScrollView(
                              child: Text(_rawTranscript),
                            )
                          : Markdown(
                              data: _markdownContent,
                              selectable: true,
                            ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void updateNotes(String transcript, String notes) {
    setState(() {
      _rawTranscript = transcript;
      _markdownContent = notes;
    });
  }
} 