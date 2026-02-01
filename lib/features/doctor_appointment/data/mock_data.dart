class Doctor {
  final String name;
  final String specialty;
  final String experience;
  final String rating;
  final String price;
  final String availability;
  final String imagePath; // Placeholder for now

  Doctor({
    required this.name,
    required this.specialty,
    required this.experience,
    required this.rating,
    required this.price,
    required this.availability,
    this.imagePath = "",
  });
}

class Hospital {
  final String name;
  final String address;
  final String distance;
  final String rating;
  final List<Doctor> availableDoctors;

  Hospital({
    required this.name,
    required this.address,
    required this.distance,
    required this.rating,
    required this.availableDoctors,
  });
}

final List<Doctor> onlineDoctors = [
  Doctor(
    name: "Dr. Sarah Smith",
    specialty: "General Physician",
    experience: "8 years",
    rating: "4.8",
    price: "\$30",
    availability: "Available Today",
  ),
  Doctor(
    name: "Dr. James Wilson",
    specialty: "Psychiatrist",
    experience: "12 years",
    rating: "4.9",
    price: "\$50",
    availability: "Next Slot: 4:00 PM",
  ),
  Doctor(
    name: "Dr. Emily Chen",
    specialty: "Dermatologist",
    experience: "5 years",
    rating: "4.7",
    price: "\$40",
    availability: "Available Today",
  ),
  Doctor(
    name: "Dr. Michael Ross",
    specialty: "Pediatrician",
    experience: "15 years",
    rating: "4.9",
    price: "\$35",
    availability: "Tomorrow",
  ),
];

final List<Hospital> nearbyHospitals = [
  Hospital(
    name: "City General Hospital",
    address: "123 Main St, Downtown",
    distance: "2.5 km",
    rating: "4.5",
    availableDoctors: [
      Doctor(
          name: "Dr. A. Kumar",
          specialty: "Cardiologist",
          experience: "20y",
          rating: "4.8",
          price: "\$60",
          availability: "Mon-Fri"),
      Doctor(
          name: "Dr. B. Singh",
          specialty: "Orthopedic",
          experience: "10y",
          rating: "4.5",
          price: "\$50",
          availability: "Mon-Sat"),
    ],
  ),
  Hospital(
    name: "Sunshine Clinic",
    address: "456 Oak Ave, Westside",
    distance: "4.1 km",
    rating: "4.2",
    availableDoctors: [
      Doctor(
          name: "Dr. C. Roy",
          specialty: "Dentist",
          experience: "6y",
          rating: "4.6",
          price: "\$30",
          availability: "Daily"),
    ],
  ),
  Hospital(
    name: "Metro Health Center",
    address: "789 Pine Rd, Northside",
    distance: "5.8 km",
    rating: "4.0",
    availableDoctors: [],
  ),
];
