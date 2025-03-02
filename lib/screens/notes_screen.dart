import 'package:flutter/material.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  NotesScreenState createState() => NotesScreenState();
}

class NotesScreenState extends State<NotesScreen> {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Notes are now displayed on the Home screen'),
    );
  }

  void updateNotes(String transcript, String notes) {
    // Method kept for compatibility but no longer used
  }
} 