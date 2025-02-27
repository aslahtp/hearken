import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedAudioPath;
  String? _selectedAudioName;

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
        setState(() {
          _selectedAudioPath = file.path;
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

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: _pickAudioFile,
            icon: const Icon(Icons.audio_file),
            label: const Text('Pick Audio File'),
          ),
          if (_selectedAudioName != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Selected: $_selectedAudioName',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
        ],
      ),
    );
  }
} 