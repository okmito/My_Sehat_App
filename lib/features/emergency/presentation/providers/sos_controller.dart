import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/sos_remote_data_source.dart';
import '../../data/models/hospital_model.dart';
import '../../data/models/sos_event_model.dart';
import '../../domain/entities/emergency_contact_entity.dart';
import '../providers/emergency_contacts_provider.dart';

class SOSState {
  final bool isSending;
  final bool isPolling;
  final bool isContacting;
  final bool isFetchingHospitals;
  final SOSEventModel? currentEvent;
  final Position? userPosition;
  final List<HospitalModel> hospitals;
  final String? errorMessage;
  final bool hasContactedPrimary;

  const SOSState({
    this.isSending = false,
    this.isPolling = false,
    this.isContacting = false,
    this.isFetchingHospitals = false,
    this.currentEvent,
    this.userPosition,
    this.hospitals = const [],
    this.errorMessage,
    this.hasContactedPrimary = false,
  });

  SOSState copyWith({
    bool? isSending,
    bool? isPolling,
    bool? isContacting,
    bool? isFetchingHospitals,
    SOSEventModel? currentEvent,
    Position? userPosition,
    List<HospitalModel>? hospitals,
    String? errorMessage,
    bool? hasContactedPrimary,
  }) {
    return SOSState(
      isSending: isSending ?? this.isSending,
      isPolling: isPolling ?? this.isPolling,
      isContacting: isContacting ?? this.isContacting,
      isFetchingHospitals: isFetchingHospitals ?? this.isFetchingHospitals,
      currentEvent: currentEvent ?? this.currentEvent,
      userPosition: userPosition ?? this.userPosition,
      hospitals: hospitals ?? this.hospitals,
      errorMessage: errorMessage,
      hasContactedPrimary: hasContactedPrimary ?? this.hasContactedPrimary,
    );
  }
}

class SOSController extends StateNotifier<SOSState> {
  SOSController(this._ref, this._remote) : super(const SOSState());

  final Ref _ref;
  final SOSRemoteDataSource _remote;
  Timer? _poller;

  Future<Position> _getOrRequestPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }

    return Geolocator.getCurrentPosition();
  }

  Future<void> prepare() async {
    try {
      if (state.userPosition != null) return;
      // ignore: avoid_print
      print('[SOS] Preparing: requesting location & hospitals');
      state = state.copyWith(isFetchingHospitals: true, errorMessage: null);
      final position = await _getOrRequestPosition();
      final hospitals = await _remote.getNearbyHospitals(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      state = state.copyWith(
        userPosition: position,
        hospitals: hospitals,
        isFetchingHospitals: false,
      );
    } catch (e) {
      state = state.copyWith(
        isFetchingHospitals: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> triggerSOS({String emergencyType = 'Medical'}) async {
    try {
      // ignore: avoid_print
      print('[SOS] Triggering SOS...');
      state = state.copyWith(isSending: true, errorMessage: null);
      final position = await _getOrRequestPosition();
      final user = _ref.read(authStateProvider).value;
      final userId = user?.id ?? user?.phoneNumber ?? 'guest-user';

      final sosEvent = await _remote.createSOS(
        userId: userId,
        latitude: position.latitude,
        longitude: position.longitude,
        emergencyType: emergencyType,
      );

      state = state.copyWith(
        isSending: false,
        currentEvent: sosEvent,
        userPosition: position,
        errorMessage: null,
      );

      // ignore: avoid_print
      print('[SOS] SOS created with id: ${sosEvent.id}');
      _startPolling();
      _maybeContactPrimary();
    } catch (e) {
      // ignore: avoid_print
      print('[SOS] Trigger error: $e');
      state = state.copyWith(isSending: false, errorMessage: e.toString());
      rethrow;
    }
  }

  void _startPolling() {
    _poller?.cancel();
    state = state.copyWith(isPolling: true);
    _poller = Timer.periodic(const Duration(seconds: 3), (_) => pollLatest());
  }

  Future<void> pollLatest() async {
    final current = state.currentEvent;
    if (current == null) return;

    try {
      final updated = await _remote.getSOSStatus(current.id);
      state = state.copyWith(currentEvent: updated, errorMessage: null);
      if (updated.isResolved) {
        _poller?.cancel();
        state = state.copyWith(isPolling: false);
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> refreshHospitals() async {
    try {
      final position = state.userPosition ?? await _getOrRequestPosition();
      state = state.copyWith(isFetchingHospitals: true, userPosition: position);
      final hospitals = await _remote.getNearbyHospitals(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      state = state.copyWith(
        hospitals: hospitals,
        isFetchingHospitals: false,
      );
    } catch (e) {
      state = state.copyWith(
        isFetchingHospitals: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _maybeContactPrimary() async {
    final contacts = _ref.read(emergencyContactsProvider);
    if (contacts.isEmpty || state.hasContactedPrimary) return;

    final EmergencyContactEntity primary = contacts.first;
    final uri = Uri(scheme: 'tel', path: primary.phoneNumber);

    state = state.copyWith(isContacting: true);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        state = state.copyWith(hasContactedPrimary: true);
      }
    } finally {
      state = state.copyWith(isContacting: false);
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }
}

final sosControllerProvider =
    StateNotifierProvider<SOSController, SOSState>((ref) {
  return SOSController(ref, ref.watch(sosRemoteDataSourceProvider));
});
