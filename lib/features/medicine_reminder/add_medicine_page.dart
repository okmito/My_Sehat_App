import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'models/medication.dart';
import 'providers/medicine_provider.dart';

class AddMedicinePage extends ConsumerStatefulWidget {
  final Medication? medicine;
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
      _strengthController.text = med.strength ?? '';
      _selectedForm = med.form;
      // Pre-fill schedule info if available
      if (med.schedule != null) {
        _selectedSchedule = med.schedule!.scheduleType;
        if (med.schedule!.endDate != null) {
          _endDate = DateTime.parse(med.schedule!.endDate!);
        }
        for (var timeStr in med.schedule!.times) {
          // Expecting HH:mm format from backend
          try {
            // If format is HH:mm:
            final parts = timeStr.split(':');
            if (parts.length >= 2) {
              _selectedTimes.add(TimeOfDay(
                  hour: int.parse(parts[0]), minute: int.parse(parts[1])));
            } else {
              // Fallback attempt with date format
              final format = DateFormat("HH:mm");
              final dt = format.parse(timeStr);
              _selectedTimes.add(TimeOfDay(hour: dt.hour, minute: dt.minute));
            }
          } catch (e) {
            print("Error parsing time: $timeStr");
          }
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
      if (!RegExp(r'^\d*\.?\d*$').hasMatch(_strengthController.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Strength must be a number')),
        );
        return;
      }
    }

    try {
      // 1. Prepare Medication object
      final newMedicine = Medication(
        id: widget.medicine?.id, // null for new
        name: _nameController.text,
        strength: _strengthController.text.isNotEmpty
            ? _strengthController.text
            : null,
        form: _selectedForm!,
        instructions: null,
      );

      // 2. Prepare Schedule Data
      // Times should be HH:mm for backend
      final timesList = _selectedTimes.map((t) {
        final h = t.hour.toString().padLeft(2, '0');
        final m = t.minute.toString().padLeft(2, '0');
        return "$h:$m";
      }).toList();

      final scheduleData = {
        "schedule_type": _selectedSchedule!
            .toUpperCase(), // Backend likely expects UPPERCASE (DAILY, WEEKLY)
        "times": timesList,
        "end_date": _endDate != null
            ? DateFormat('yyyy-MM-dd').format(_endDate!)
            : null,
      };

      if (widget.medicine != null) {
        await ref.read(medicineProvider.notifier).updateMedicine(
            id: widget.medicine!.id!,
            medication: newMedicine,
            scheduleData: scheduleData);
      } else {
        await ref
            .read(medicineProvider.notifier)
            .addMedicine(medication: newMedicine, scheduleData: scheduleData);
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving medicine: $e'),
              backgroundColor: Colors.red),
        );
      }
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
            _buildLabel("Strength (Optional)"),
            TextField(
              controller: _strengthController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: "e.g., 500 (only numbers)",
              ),
            ),
            const SizedBox(height: 20),
            _buildLabel("Form"),
            DropdownButtonFormField<String>(
              initialValue: _selectedForm,
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
              initialValue: _selectedSchedule,
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
