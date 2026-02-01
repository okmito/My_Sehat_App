import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/mock_data.dart';

class OnlineConsultationTab extends StatefulWidget {
  const OnlineConsultationTab({super.key});

  @override
  State<OnlineConsultationTab> createState() => _OnlineConsultationTabState();
}

class _OnlineConsultationTabState extends State<OnlineConsultationTab> {
  // Booking State
  Doctor? _selectedDoctor;
  DateTime? _selectedDate;
  String? _selectedTime;
  String? _selectedReason;
  bool _isBookingConfirmed = false;

  void _startBooking(Doctor doctor) {
    setState(() {
      _selectedDoctor = doctor;
      _selectedDate = null;
      _selectedTime = null;
      _selectedReason = null;
      _isBookingConfirmed = false;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) =>
              _buildBookingSheet(context, scrollController, setModalState),
        ),
      ),
    );
  }

  Widget _buildBookingSheet(BuildContext context, ScrollController controller,
      StateSetter setModalState) {
    if (_isBookingConfirmed) {
      return _buildConfirmationView();
    }

    return ListView(
      controller: controller,
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text("Book Consultation",
            style:
                GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("with ${_selectedDoctor?.name}",
            style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey[600])),
        const SizedBox(height: 32),

        // Date Selection
        Text("Select Date",
            style:
                GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            itemBuilder: (context, index) {
              final date = DateTime.now().add(Duration(days: index));
              final isSelected = _selectedDate?.day == date.day;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => setModalState(() => _selectedDate = date),
                  child: Container(
                    width: 60,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? null
                          : Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getWeekday(date.weekday),
                          style: GoogleFonts.outfit(
                            color: isSelected ? Colors.white : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          date.day.toString(),
                          style: GoogleFonts.outfit(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Time Selection
        Text("Select Time",
            style:
                GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            "09:00 AM",
            "10:00 AM",
            "11:30 AM",
            "02:00 PM",
            "04:00 PM",
            "06:30 PM"
          ].map((time) {
            final isSelected = _selectedTime == time;
            return ChoiceChip(
              label: Text(time),
              selected: isSelected,
              onSelected: (selected) {
                setModalState(() => _selectedTime = selected ? time : null);
              },
              selectedColor: Theme.of(context).primaryColor,
              labelStyle:
                  TextStyle(color: isSelected ? Colors.white : Colors.black87),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.shade300)),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Reason Selection
        Text("Consultation Reason",
            style:
                GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            "Fever",
            "Cough",
            "Stomach Ache",
            "Headache",
            "General Checkup",
            "Other"
          ].map((reason) {
            final isSelected = _selectedReason == reason;
            return ChoiceChip(
              label: Text(reason),
              selected: isSelected,
              onSelected: (selected) {
                setModalState(() => _selectedReason = selected ? reason : null);
              },
              selectedColor: Theme.of(context).primaryColor,
              labelStyle:
                  TextStyle(color: isSelected ? Colors.white : Colors.black87),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.shade300)),
            );
          }).toList(),
        ),

        const SizedBox(height: 40),

        // Confirm Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: (_selectedDate != null &&
                    _selectedTime != null &&
                    _selectedReason != null)
                ? () {
                    setModalState(() => _isBookingConfirmed = true);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text("Confirm Booking",
                style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationView() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.check_circle, size: 60, color: Colors.green),
          ),
          const SizedBox(height: 24),
          Text("Booking Confirmed!",
              style: GoogleFonts.outfit(
                  fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
              "Your video consultation with ${_selectedDoctor?.name} is scheduled for:",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text("$_selectedTime, ${_formatDate(_selectedDate!)}",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () {
                // Add to booked appointments
                if (_selectedDoctor != null &&
                    _selectedDate != null &&
                    _selectedTime != null &&
                    _selectedReason != null) {
                  setState(() {
                    _bookedAppointments.add(_Appointment(
                      doctor: _selectedDoctor!,
                      date: _selectedDate!,
                      time: _selectedTime!,
                      reason: _selectedReason!,
                    ));
                  });
                }
                Navigator.pop(context);
              },
              child: Text("Close",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  String _getWeekday(int weekday) {
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return days[weekday - 1];
  }

  String _formatDate(DateTime date) {
    return "${_getWeekday(date.weekday)}, ${date.day}/${date.month}";
  }

  // --- New Logic for Appointment Actions ---
  final List<_Appointment> _bookedAppointments = [];

  void _cancelAppointment(_Appointment appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Cancel Appointment",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to cancel this appointment?",
            style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("No", style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _bookedAppointments.remove(appointment);
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text("Yes, Cancel",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _editAppointmentTime(_Appointment appointment) {
    String? newTime = appointment.time;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Edit Time",
                  style: GoogleFonts.outfit(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  "09:00 AM",
                  "10:00 AM",
                  "11:30 AM",
                  "02:00 PM",
                  "04:00 PM",
                  "06:30 PM"
                ].map((time) {
                  final isSelected = newTime == time;
                  return ChoiceChip(
                    label: Text(time),
                    selected: isSelected,
                    onSelected: (selected) {
                      setSheetState(() => newTime = selected ? time : null);
                    },
                    selectedColor: Theme.of(context).primaryColor,
                    labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: Colors.grey.shade300)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: newTime != null
                      ? () {
                          setState(() {
                            appointment.time = newTime!;
                          });
                          Navigator.pop(context);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text("Update Time",
                      style: GoogleFonts.outfit(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_bookedAppointments.isNotEmpty) ...[
          Text("My Appointments",
              style: GoogleFonts.outfit(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._bookedAppointments.map((app) => _AppointmentCard(
                appointment: app,
                onCancel: () => _cancelAppointment(app),
                onEdit: () => _editAppointmentTime(app),
              )),
          const SizedBox(height: 24),
          Divider(color: Colors.grey[200], thickness: 4),
          const SizedBox(height: 24),
        ],

        // "Upcoming" placeholder if needed, but going straight to list for now
        Text("Available Doctors",
            style:
                GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...onlineDoctors.map((doctor) => _DoctorCard(
              doctor: doctor,
              onBook: () => _startBooking(doctor),
            )),
      ],
    );
  }
}

class _Appointment {
  final Doctor doctor;
  final DateTime date;
  String time;
  final String reason;

  _Appointment({
    required this.doctor,
    required this.date,
    required this.time,
    required this.reason,
  });
}

class _AppointmentCard extends StatelessWidget {
  final _Appointment appointment;
  final VoidCallback onCancel;
  final VoidCallback onEdit;

  const _AppointmentCard({
    required this.appointment,
    required this.onCancel,
    required this.onEdit,
  });

  DateTime _parseDateTime(DateTime date, String timeStr) {
    // timeStr e.g. "09:00 AM"
    try {
      final parts = timeStr.trim().split(" ");
      final timeParts = parts[0].split(":");
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      final period = parts[1]; // AM or PM

      if (period == "PM" && hour != 12) hour += 12;
      if (period == "AM" && hour == 12) hour = 0;

      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (e) {
      return date; // Fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointmentDateTime =
        _parseDateTime(appointment.date, appointment.time);
    final now = DateTime.now();
    // Restriction rules:
    // If MORE THAN 1 hour before: Allow
    // If WITHIN 1 hour: Disable
    // "Within 1 hour" means now is > (appointment - 1hr)
    // Or appointment - now <= 1 hour (60 mins)
    // And appointment IS in the future (otherwise its past)

    final difference = appointmentDateTime.difference(now);

    // The user requirement: "If current time is MORE THAN 1 hour before appointment time: Allow"
    // "If current time is WITHIN 1 hour of appointment time: Disable"
    // Assuming appointment is in future.
    final isRestricted = difference.inMinutes <= 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                  image: appointment.doctor.imagePath.isNotEmpty
                      ? DecorationImage(
                          image: AssetImage(appointment.doctor.imagePath),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: appointment.doctor.imagePath.isEmpty
                    ? const Icon(Icons.person_rounded,
                        size: 30, color: Colors.blue)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appointment.doctor.name,
                        style: GoogleFonts.outfit(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                        "${appointment.time}, ${_formatDate(appointment.date)}",
                        style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).primaryColor)),
                    Text(appointment.reason,
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Actions
          if (isRestricted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("Appointments cannot be modified within 1 hour",
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onEdit,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      foregroundColor: Colors.black87,
                    ),
                    child: const Text("Edit Timing"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text("Cancel"),
                  ),
                ),
              ],
            )
        ],
      ),
    );
  }

  String _getWeekday(int weekday) {
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return days[weekday - 1];
  }

  String _formatDate(DateTime date) {
    return "${_getWeekday(date.weekday)}, ${date.day}/${date.month}";
  }
}

class _DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback onBook;

  const _DoctorCard({required this.doctor, required this.onBook});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(20),
              image: doctor.imagePath.isNotEmpty
                  ? DecorationImage(
                      image: AssetImage(doctor.imagePath), fit: BoxFit.cover)
                  : null,
            ),
            child: doctor.imagePath.isEmpty
                ? const Icon(Icons.person_rounded, size: 40, color: Colors.blue)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(doctor.name,
                        style: GoogleFonts.outfit(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(doctor.rating,
                          style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Text(doctor.specialty,
                    style: GoogleFonts.outfit(
                        fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.work_outline, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(doctor.experience,
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: Colors.grey[500])),
                    const Spacer(),
                    Text(doctor.price,
                        style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: onBook,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text("Book Appointment"),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
