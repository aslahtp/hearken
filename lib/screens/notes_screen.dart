import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/supabase_service.dart';
import 'dart:async';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'dart:io';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  NotesScreenState createState() => NotesScreenState();
}

class NotesScreenState extends State<NotesScreen> {
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    
    // Set up a timer to refresh notes every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadNotes();
      }
    });
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notes = await SupabaseService().getUserNotes();
      if (mounted) {
        setState(() {
          _notes = notes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load notes: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteNote(String noteId) async {
    try {
      await SupabaseService().deleteNote(noteId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note deleted successfully')),
      );
      _loadNotes(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete note: ${e.toString()}')),
      );
    }
  }

  void _viewNoteDetails(Map<String, dynamic> note) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(note['title'] ?? 'Note Details'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Notes'),
                  Tab(text: 'To Do Items'),
                  Tab(text: 'Transcript'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // Notes Tab
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarkdownBody(
                          data: note['notes'] ?? 'No notes available',
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: Theme.of(context).textTheme.bodyMedium,
                            h1: Theme.of(context).textTheme.headlineMedium,
                            h2: Theme.of(context).textTheme.titleLarge,
                            h3: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                // Actionable Items Tab
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarkdownBody(
                          data: note['actionable_items'] ?? 'No actionable items available',
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: Theme.of(context).textTheme.bodyMedium,
                            h1: Theme.of(context).textTheme.headlineMedium,
                            h2: Theme.of(context).textTheme.titleLarge,
                            h3: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                // Transcript Tab
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          note['transcript'] ?? 'No transcript available',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: BottomAppBar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: note['notes'] ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Notes copied to clipboard')),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Notes'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: note['actionable_items'] ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Actionable items copied to clipboard')),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Items'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: note['transcript'] ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Transcript copied to clipboard')),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Transcript'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _exportToPdf(note),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Export PDF'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportToPdf(Map<String, dynamic> note) async {
    try {
      // Create PDF document with barebones text-only approach
      final pdf = pw.Document();
      
      // Get the title and date
      final title = note['title'] ?? 'Untitled Note';
      final createdAt = DateTime.parse(note['created_at'] ?? DateTime.now().toIso8601String());
      final formattedDate = '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
      
      // Get note content
      final noteText = note['notes'] ?? 'No notes available';

      // Create a text-only PDF with automatic page breaks
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build: (context) {
            // Simple list of widgets for content
            final List<pw.Widget> widgets = [];
            
            // Title
            widgets.add(pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ));
            
            // Date
            widgets.add(pw.SizedBox(height: 4));
            widgets.add(pw.Text('Created: $formattedDate',
              style: const pw.TextStyle(fontSize: 10),
            ));
            
            // Divider
            widgets.add(pw.Divider());
            widgets.add(pw.SizedBox(height: 8));
            
            // Notes header
            widgets.add(pw.Text(
              'Notes',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ));
            widgets.add(pw.SizedBox(height: 8));
            
            // Break notes into paragraphs for better handling
            final paragraphs = noteText.split('\n\n');
            for (var paragraph in paragraphs) {
              widgets.add(pw.Text(
                paragraph.trim(),
                style: const pw.TextStyle(fontSize: 10),
              ));
              widgets.add(pw.SizedBox(height: 4));
            }
            
            return widgets;
          },
        ),
      );
      
      // Generate PDF bytes
      final bytes = await pdf.save();
      final sanitizedTitle = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final fileName = '$sanitizedTitle.pdf';
      
      // For Windows/macOS/Linux
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final downloadsPath = '${Platform.environment['HOME']}/Downloads';
        final file = File('$downloadsPath/$fileName');
        await file.writeAsBytes(bytes);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF saved to: ${file.path}'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }
      
      // For mobile platforms, first save to a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);
      
      if (Platform.isAndroid) {
        try {
          // Try to get Downloads folder on Android
          Directory? downloadsDir;
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            // Navigate up to find the Download directory
            final parentDir = externalDir.path.split('/Android')[0];
            downloadsDir = Directory('$parentDir/Download');
            if (await downloadsDir.exists()) {
              final file = File('${downloadsDir.path}/$fileName');
              await file.writeAsBytes(bytes);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('PDF saved to: ${file.path}'),
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
              return;
            }
          }
          
          // If we couldn't save to Downloads, inform the user of the temp location
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF saved to temporary location: ${tempFile.path}\nCopy it to your preferred location.'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } catch (e) {
          // If there's an error saving to Downloads, use the temp file
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not save to Downloads folder. PDF saved to: ${tempFile.path}'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      } else if (Platform.isIOS) {
        // On iOS, save to Documents directory
        final docsDir = await getApplicationDocumentsDirectory();
        final file = File('${docsDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF saved to: ${file.path}'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      // Show an error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotes,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No notes found',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            const Text(
              'Process an audio file in the Home tab to create notes',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotes,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          final note = _notes[index];
          final createdAt = DateTime.parse(note['created_at'] ?? DateTime.now().toIso8601String());
          final formattedDate = '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
          
          return Card(
            margin: const EdgeInsets.only(bottom: 16.0),
            child: InkWell(
              onTap: () => _viewNoteDetails(note),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            note['title'] ?? 'Untitled Note',
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Note'),
                                content: const Text('Are you sure you want to delete this note? This action cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _deleteNote(note['id'].toString());
                                    },
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Created: $formattedDate',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              constraints: BoxConstraints(
                                maxHeight: 80,
                                maxWidth: constraints.maxWidth,
                              ),
                              child: ClipRect(
                                child: OverflowBox(
                                  alignment: Alignment.topLeft,
                                  maxHeight: double.infinity,
                                  child: MarkdownBody(
                                    data: note['notes'] ?? 'No notes available',
                                    selectable: false,
                                    softLineBreak: true,
                                    styleSheet: MarkdownStyleSheet(
                                      p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        height: 1.3,
                                      ),
                                      h1: Theme.of(context).textTheme.titleMedium,
                                      h2: Theme.of(context).textTheme.titleSmall,
                                      h3: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (note['actionable_items'] != null && 
                                note['actionable_items'] != 'No actionable items mentioned in this lecture.')
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 16),
                                  Text(
                                    'Actionable Items:',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    constraints: BoxConstraints(
                                      maxHeight: 60,
                                      maxWidth: constraints.maxWidth,
                                    ),
                                    child: ClipRect(
                                      child: OverflowBox(
                                        alignment: Alignment.topLeft,
                                        maxHeight: double.infinity,
                                        child: MarkdownBody(
                                          data: note['actionable_items'] ?? 'No actionable items available',
                                          selectable: false,
                                          softLineBreak: true,
                                          styleSheet: MarkdownStyleSheet(
                                            p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              height: 1.3,
                                              color: Theme.of(context).colorScheme.tertiary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _exportToPdf(note),
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: const Text('Export PDF'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _viewNoteDetails(note),
                            child: const Text('View Details'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void updateNotes(String transcript, String notes) {
    // Method kept for compatibility but no longer used
    // Notes are now saved directly to Supabase in the HomeScreen
  }
} 