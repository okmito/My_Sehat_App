import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/mock_data.dart';

class OfflineVisitTab extends StatefulWidget {
  const OfflineVisitTab({super.key});

  @override
  State<OfflineVisitTab> createState() => _OfflineVisitTabState();
}

class _OfflineVisitTabState extends State<OfflineVisitTab> {
  Hospital? _selectedHospital;

  @override
  Widget build(BuildContext context) {
    if (_selectedHospital != null) {
      return _buildHospitalDetail();
    }
    return _buildHospitalList();
  }

  Widget _buildHospitalList() {
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
        ...nearbyHospitals.map((hospital) => _HospitalCard(
              hospital: hospital,
              onTap: () {
                setState(() {
                  _selectedHospital = hospital;
                });
              },
            )),
      ],
    );
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
                  "10:00 AM",
                  "11:00 AM",
                  "04:00 PM",
                  "05:30 PM",
                  "07:00 PM"
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

  Widget _buildHospitalDetail() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _selectedHospital = null),
                  ),
                  Text(
                    _selectedHospital!.name,
                    style: GoogleFonts.outfit(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 48, bottom: 8),
                child: Text(
                  _selectedHospital!.address,
                  style: GoogleFonts.outfit(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _selectedHospital!.availableDoctors.isEmpty
              ? Center(
                  child: Text("No doctors listed available for booking.",
                      style: GoogleFonts.outfit()))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _selectedHospital!.availableDoctors.length,
                  itemBuilder: (context, index) {
                    final doctor = _selectedHospital!.availableDoctors[index];
                    // We can reuse the OnlineConsultationTab logic structure for booking
                    // For minimal code duplication, we will just instantiate a booking widget
                    // But to follow strictly "Separate widgets where needed" and maintain clean file,
                    // I'll assume we can't easily import private _DoctorCard from other file.
                    // So I will make a Local Doctor Card for Offline.
                    return _OfflineDoctorCard(
                        doctor: doctor,
                        onBook: () {
                          // Reuse the booking logic via composition or copy-paste (Simpler for this task constraint)
                          // Trigger bottom sheet
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24)),
                            ),
                            builder: (context) => _BookingSheet(
                              doctor: doctor,
                              onBooked: (date, time, reason) {
                                setState(() {
                                  _bookedAppointments.add(_Appointment(
                                    doctor: doctor,
                                    date: date,
                                    time: time,
                                    reason: reason,
                                  ));
                                  // Optionally go back to list to see the appointment
                                  _selectedHospital = null;
                                });
                              },
                            ),
                          );
                        });
                  },
                ),
        ),
      ],
    );
  }
}

class _HospitalCard extends StatelessWidget {
  final Hospital hospital;
  final VoidCallback onTap;

  const _HospitalCard({required this.hospital, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.local_hospital_rounded,
                      color: Colors.red, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hospital.name,
                          style: GoogleFonts.outfit(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(hospital.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                              fontSize: 13, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 14, color: Colors.blue[400]),
                          const SizedBox(width: 4),
                          Text(hospital.distance,
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[400])),
                          const Spacer(),
                          const Icon(Icons.star_rounded,
                              size: 16, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(hospital.rating,
                              style: GoogleFonts.outfit(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Similar to Online Doctor Card but for Offline context
class _OfflineDoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback onBook;

  const _OfflineDoctorCard({required this.doctor, required this.onBook});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey[100],
            child: Text(doctor.name[0],
                style: GoogleFonts.outfit(fontSize: 20, color: Colors.grey)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctor.name,
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(doctor.specialty,
                    style: GoogleFonts.outfit(
                        color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 4),
                Text(doctor.availability,
                    style: GoogleFonts.outfit(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onBook,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(0, 36),
            ),
            child: const Text("Book"),
          )
        ],
      ),
    );
  }
}

class _BookingSheet extends StatefulWidget {
  final Doctor doctor;
  final Function(DateTime, String, String) onBooked;
  const _BookingSheet({required this.doctor, required this.onBooked});

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  DateTime? _selectedDate;
  String? _selectedTime;
  String? _selectedReason;
  bool _confirmed = false;

  String _getWeekday(int weekday) {
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return days[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmed) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text("Appointment Confirmed!",
                style: GoogleFonts.outfit(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            Text(
                "Visit ${widget.doctor.name} on $_selectedTime, ${_selectedDate?.day}/${_selectedDate?.month}",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.grey)),
            const SizedBox(height: 32),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: () {
                      if (_selectedDate != null &&
                          _selectedTime != null &&
                          _selectedReason != null) {
                        widget.onBooked(
                            _selectedDate!, _selectedTime!, _selectedReason!);
                      }
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white),
                    child: const Text("Done")))
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Text("Book Visit",
                style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("with ${widget.doctor.name}",
                style:
                    GoogleFonts.outfit(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 24),

            // Date Selection
            Text("Select Date",
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
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
                      onTap: () => setState(() => _selectedDate = date),
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
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              date.day.toString(),
                              style: GoogleFonts.outfit(
                                color:
                                    isSelected ? Colors.white : Colors.black87,
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
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                "10:00 AM",
                "11:00 AM",
                "04:00 PM",
                "05:30 PM",
                "07:00 PM"
              ].map((time) {
                final isSelected = _selectedTime == time;
                return ChoiceChip(
                  label: Text(time),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedTime = selected ? time : null);
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

            // Reason Selection
            Text("Consultation Reason",
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
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
                    setState(() => _selectedReason = selected ? reason : null);
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

            const SizedBox(height: 40),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_selectedDate != null &&
                        _selectedTime != null &&
                        _selectedReason != null)
                    ? () => setState(() => _confirmed = true)
                    : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                child: Text("Confirm Booking",
                    style: GoogleFonts.outfit(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
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

  String _getWeekday(int weekday) {
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return days[weekday - 1];
  }

  String _formatDate(DateTime date) {
    return "${_getWeekday(date.weekday)}, ${date.day}/${date.month}";
  }

  @override
  Widget build(BuildContext context) {
    final appointmentDateTime =
        _parseDateTime(appointment.date, appointment.time);
    final now = DateTime.now();

    final difference = appointmentDateTime.difference(now);
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
}
