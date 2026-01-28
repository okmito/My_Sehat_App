import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'models/medicine_model.dart';
import 'providers/medicine_provider.dart';

class AddMedicinePage extends ConsumerStatefulWidget {
  final MedicineModel? medicine;
  const AddMedicinePage({super.key, this.medicine});

  @override
  ConsumerState<AddMedicinePage> createState() => _AddMedicinePageState();
}

class _AddMedicinePageState extends ConsumerState<AddMedicinePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _strengthController = TextEditingController();
  String? _selectedForm;
  String? _selectedSchedule;
  DateTime? _endDate;
  final List<TimeOfDay> _selectedTimes = [];

  final List<String> _forms = [
    'Tablet',
    'Syrup',
    'Capsule',
    'Injection',
    'Drops'
  ];
  final List<String> _schedules = ['Daily', 'Weekly', 'Interval'];

  @override
  void initState() {
    super.initState();
    if (widget.medicine != null) {
      final med = widget.medicine!;
      _nameController.text = med.name;
      _strengthController.text = med.strength;
      _selectedForm = med.form;
      _selectedSchedule = med.scheduleType;
      _endDate = med.endDate;

      for (var timeStr in med.times) {
        final format = DateFormat("hh:mm a");
        try {
          final dt = format.parse(timeStr);
          _selectedTimes.add(TimeOfDay(hour: dt.hour, minute: dt.minute));
        } catch (e) {
          // Handle parse error if needed
        }
      }
    }
  }

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

  void _selectEndDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null) {
      setState(() {
        _endDate = pickedDate;
      });
    }
  }

  void _saveMedicine() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter medicine name')),
      );
      return;
    }

    if (_selectedForm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select medicine form')),
      );
      return;
    }

    if (_selectedSchedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select schedule type')),
      );
      return;
    }

    if (_selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one time')),
      );
      return;
    }

    // Strength validation
    if (_strengthController.text.isNotEmpty) {
      // Regex to allow only numbers (and maybe a decimal)
      if (!RegExp(r'^\d*\.?\d*$').hasMatch(_strengthController.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Strength must be a number')),
        );
        return;
      }
    }

    // Use existing ID if editing, otherwise generate new one
    final id = widget.medicine?.id ?? const Uuid().v4();
    final createdDate = widget.medicine?.createdDate ?? DateTime.now();
    final history = widget.medicine?.history ?? {};

    final newMedicine = MedicineModel(
      id: id,
      name: _nameController.text,
      strength: _strengthController.text,
      form: _selectedForm!,
      scheduleType: _selectedSchedule!,
      times: _selectedTimes.map((t) {
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
        return DateFormat("hh:mm a").format(dt);
      }).toList(),
      history: history,
      createdDate: createdDate,
      endDate: _endDate,
    );

    if (widget.medicine != null) {
      await ref.read(medicineProvider.notifier).updateMedicine(newMedicine);
    } else {
      await ref.read(medicineProvider.notifier).addMedicine(newMedicine);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(widget.medicine != null
                ? 'Medicine updated successfully!'
                : 'Medicine saved successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.medicine != null ? "Edit Medicine" : "Add Medicine",
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
            _buildLabel("Strength (Optional)"), // Updated label
            TextField(
              controller: _strengthController,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true), // Numeric keyboard
              decoration: const InputDecoration(
                hintText: "e.g., 500 (only numbers)",
              ),
            ),
            const SizedBox(height: 20),
            _buildLabel("Form"),
            DropdownButtonFormField<String>(
              value: _selectedForm,
              hint: const Text("Select Form"),
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
              hint: const Text("Select Schedule"),
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
            _buildLabel("End Date (Optional)"),
            InkWell(
              onTap: _selectEndDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _endDate == null
                          ? "Select End Date"
                          : DateFormat('yyyy-MM-dd').format(_endDate!),
                      style: TextStyle(
                        color:
                            _endDate == null ? Colors.grey[600] : Colors.black,
                        fontSize: 16,
                      ),
                    ),
                    const Icon(Icons.calendar_today, color: Colors.grey),
                  ],
                ),
              ),
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
                final now = DateTime.now();
                final dt = DateTime(
                    now.year, now.month, now.day, time.hour, time.minute);
                final timeStr = DateFormat("hh:mm a").format(dt);
                return Chip(
                  label: Text(timeStr),
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
