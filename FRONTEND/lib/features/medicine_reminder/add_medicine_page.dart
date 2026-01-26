import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AddMedicinePage extends StatefulWidget {
  const AddMedicinePage({super.key});

  @override
  State<AddMedicinePage> createState() => _AddMedicinePageState();
}

class _AddMedicinePageState extends State<AddMedicinePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _strengthController = TextEditingController();
  String _selectedForm = 'Tablet';
  String _selectedSchedule = 'Daily';
  final List<TimeOfDay> _selectedTimes = [];

  final List<String> _forms = [
    'Tablet',
    'Syrup',
    'Capsule',
    'Injection',
    'Drops'
  ];
  final List<String> _schedules = ['Daily', 'Weekly', 'Interval'];

  void _addTime() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        _selectedTimes.add(time);
        _selectedTimes.sort((a, b) =>
            (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
      });
    }
  }

  void _saveMedicine() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved (mock)')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Add Medicine",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel("Medicine Name"),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: "e.g., Paracetamol",
              ),
            ),
            const SizedBox(height: 20),
            _buildLabel("Strength"),
            TextField(
              controller: _strengthController,
              decoration: const InputDecoration(
                hintText: "e.g., 500 mg",
              ),
            ),
            const SizedBox(height: 20),
            _buildLabel("Form"),
            DropdownButtonFormField<String>(
              value: _selectedForm,
              items: _forms.map((String form) {
                return DropdownMenuItem<String>(
                  value: form,
                  child: Text(form),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedForm = newValue!;
                });
              },
            ),
            const SizedBox(height: 20),
            _buildLabel("Schedule Type"),
            DropdownButtonFormField<String>(
              value: _selectedSchedule,
              items: _schedules.map((String schedule) {
                return DropdownMenuItem<String>(
                  value: schedule,
                  child: Text(schedule),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedSchedule = newValue!;
                });
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLabel("Times"),
                TextButton.icon(
                  onPressed: _addTime,
                  icon: const Icon(Icons.add_alarm),
                  label: const Text("Add Time"),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _selectedTimes.map((time) {
                return Chip(
                  label: Text(time.format(context)),
                  onDeleted: () {
                    setState(() {
                      _selectedTimes.remove(time);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveMedicine,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "Save Medicine",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}
