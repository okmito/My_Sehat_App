import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/emergency_contact_entity.dart';

class EmergencyContactsNotifier
    extends StateNotifier<List<EmergencyContactEntity>> {
  final Box<Map<dynamic, dynamic>> _box;
  final Uuid _uuid = const Uuid();

  EmergencyContactsNotifier(this._box) : super([]) {
    _loadContacts();
  }

  void _loadContacts() {
    final contacts = <EmergencyContactEntity>[];
    for (var key in _box.keys) {
      final contactMap = _box.get(key);
      if (contactMap != null) {
        contacts.add(EmergencyContactEntity.fromJson(
          Map<String, dynamic>.from(contactMap),
        ));
      }
    }
    state = contacts;
  }

  Future<void> addContact({
    required String name,
    required String phoneNumber,
    String? relationship,
  }) async {
    final newContact = EmergencyContactEntity(
      id: _uuid.v4(),
      name: name,
      phoneNumber: phoneNumber,
      relationship: relationship,
    );
    await _box.put(newContact.id, newContact.toJson());
    state = [...state, newContact];
  }

  Future<void> deleteContact(String id) async {
    await _box.delete(id);
    state = state.where((contact) => contact.id != id).toList();
  }

  Future<void> updateContact(EmergencyContactEntity updatedContact) async {
    await _box.put(updatedContact.id, updatedContact.toJson());
    state = state.map((contact) {
      return contact.id == updatedContact.id ? updatedContact : contact;
    }).toList();
  }
}

final emergencyContactsProvider = StateNotifierProvider<
    EmergencyContactsNotifier, List<EmergencyContactEntity>>(
  (ref) {
    throw UnimplementedError('emergencyContactsProvider must be overridden');
  },
);
