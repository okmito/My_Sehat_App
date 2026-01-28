import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/services/local_storage_service.dart';
import 'models/journal_entry_model.dart';
import 'journal_entry_page.dart';
import 'widgets/journal_card.dart';

class JournalListPage extends ConsumerStatefulWidget {
  const JournalListPage({super.key});

  @override
  ConsumerState<JournalListPage> createState() => _JournalListPageState();
}

class _JournalListPageState extends ConsumerState<JournalListPage> {
  late Box<JournalEntry> _journalBox;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final localStorage = ref.read(localStorageServiceProvider);
    _journalBox = localStorage.journalBox;
    setState(() {
      _isLoading = false;
    });
  }

  void _createNewEntry() {
    final newEntry = JournalEntry(date: DateTime.now());
    _journalBox.put(newEntry.id, newEntry);
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => JournalEntryPage(entryKey: newEntry.id)),
    );
  }

  void _deleteEntry(String key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Entry",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
            "Are you sure you want to delete this entry? This action cannot be undone.",
            style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                Text("Cancel", style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Delete",
                style: GoogleFonts.outfit(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _journalBox.delete(key);
    }
  }

  void _openEntry(JournalEntry entry) async {
    if (entry.isPrivate) {
      final pin = entry.pin;
      if (pin != null) {
        final authorized = await _promptPin(pin);
        if (!authorized) return;
      }
    }
    if (!mounted) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => JournalEntryPage(entryKey: entry.id)));
  }

  Future<bool> _promptPin(String correctPin) async {
    String enteredPin = "";
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Locked Entry",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Enter PIN to unlock", style: GoogleFonts.outfit()),
              const SizedBox(height: 12),
              TextField(
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                onChanged: (val) => enteredPin = val,
                decoration: const InputDecoration(
                  hintText: "PIN",
                  counterText: "",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (enteredPin == correctPin) {
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Incorrect PIN")));
                }
              },
              child: const Text("Unlock"),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("Daily Journal",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: ValueListenableBuilder(
        valueListenable: _journalBox.listenable(),
        builder: (context, Box<JournalEntry> box, _) {
          if (box.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.book_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text("Start your first journal entry!",
                      style:
                          GoogleFonts.outfit(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }
          final entries = box.values.toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return JournalCard(
                entry: entry,
                onTap: () => _openEntry(entry),
                onDelete: () => _deleteEntry(entry.id),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewEntry,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
