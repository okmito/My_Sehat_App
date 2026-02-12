import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/api_config.dart';

/// Authentication API Service
///
/// Handles communication with the backend auth API for:
/// - User signup with preferences and consents
/// - User login (phone-based)
/// - Session validation
/// - Persistent login token storage
class AuthApiService {
  // Use centralized API config for Render compatibility
  static String get baseUrl => ApiConfig.authUrl;

  static const String _tokenKey = 'mysehat_auth_token';
  static const String _userKey = 'mysehat_user_data';

  /// Get stored auth token
  static Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Store auth token for persistent login
  static Future<void> storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Clear stored token (logout)
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// Store user data locally
  static Future<void> storeUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(userData));
  }

  /// Get stored user data
  static Future<Map<String, dynamic>?> getStoredUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return jsonDecode(userJson) as Map<String, dynamic>;
    }
    return null;
  }

  /// Sign up a new user
  static Future<AuthResult> signup({
    required String name,
    required String phoneNumber,
    required String language,
    required bool emergencyEnabled,
    required bool medicineReminders,
    required List<ConsentItem> consents,
    int? age,
    String? gender,
    String? bloodGroup,
    List<String>? allergies,
    List<String>? conditions,
    String? emergencyContact,
    String? emergencyPhone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'phone_number': phoneNumber,
          'language': language,
          'emergency_enabled': emergencyEnabled,
          'medicine_reminders': medicineReminders,
          'consents': consents.map((c) => c.toJson()).toList(),
          if (age != null) 'age': age,
          if (gender != null) 'gender': gender,
          if (bloodGroup != null) 'blood_group': bloodGroup,
          if (allergies != null) 'allergies': allergies,
          if (conditions != null) 'conditions': conditions,
          if (emergencyContact != null) 'emergency_contact': emergencyContact,
          if (emergencyPhone != null) 'emergency_phone': emergencyPhone,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Store token for persistent login
        await storeToken(data['access_token']);
        await storeUserData(data['user']);

        return AuthResult(
          success: true,
          token: data['access_token'],
          user: UserData.fromJson(data['user']),
        );
      } else {
        return AuthResult(
          success: false,
          error: data['detail'] ?? 'Signup failed',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Login with phone number
  static Future<AuthResult> login({
    required String phoneNumber,
    String? otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phoneNumber,
          if (otp != null) 'otp': otp,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Store token for persistent login
        await storeToken(data['access_token']);
        await storeUserData(data['user']);

        return AuthResult(
          success: true,
          token: data['access_token'],
          user: UserData.fromJson(data['user']),
        );
      } else {
        return AuthResult(
          success: false,
          error: data['detail'] ?? 'Login failed',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Validate stored session token
  static Future<AuthResult> validateSession() async {
    try {
      final token = await getStoredToken();
      if (token == null) {
        return AuthResult(success: false, error: 'No stored session');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/auth/validate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await storeUserData(data['user']);

        return AuthResult(
          success: true,
          token: data['access_token'],
          user: UserData.fromJson(data['user']),
        );
      } else {
        // Token invalid, clear it
        await clearToken();
        return AuthResult(success: false, error: 'Session expired');
      }
    } catch (e) {
      // Network error, but might have cached data
      final cachedUser = await getStoredUserData();
      if (cachedUser != null) {
        return AuthResult(
          success: true,
          token: await getStoredToken(),
          user: UserData.fromJson(cachedUser),
          offline: true,
        );
      }
      return AuthResult(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Logout
  static Future<bool> logout() async {
    try {
      final token = await getStoredToken();
      if (token != null) {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } catch (e) {
      // Ignore network errors during logout
    }

    // Always clear local storage
    await clearToken();
    return true;
  }

  /// Get current user profile
  static Future<UserData?> getProfile() async {
    try {
      final token = await getStoredToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserData.fromJson(data);
      }
    } catch (e) {
      // Return cached data on error
      final cached = await getStoredUserData();
      if (cached != null) {
        return UserData.fromJson(cached);
      }
    }
    return null;
  }

  /// Update user preferences
  static Future<bool> updatePreferences({
    String? language,
    bool? emergencyEnabled,
    bool? medicineReminders,
    bool? notificationEnabled,
    bool? darkMode,
  }) async {
    try {
      final token = await getStoredToken();
      if (token == null) return false;

      final updates = <String, dynamic>{};
      if (language != null) updates['language'] = language;
      if (emergencyEnabled != null)
        updates['emergency_enabled'] = emergencyEnabled;
      if (medicineReminders != null)
        updates['medicine_reminders'] = medicineReminders;
      if (notificationEnabled != null)
        updates['notification_enabled'] = notificationEnabled;
      if (darkMode != null) updates['dark_mode'] = darkMode;

      final response = await http.put(
        Uri.parse('$baseUrl/auth/preferences'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updates),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Update consent
  static Future<bool> updateConsent({
    required int consentId,
    required bool granted,
    String? consentText,
  }) async {
    try {
      final token = await getStoredToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/auth/consents/$consentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'data_category': 'update', // Will be ignored server-side
          'purpose': 'update', // Will be ignored server-side
          'granted': granted,
          if (consentText != null) 'consent_text': consentText,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

/// Result of authentication operations
class AuthResult {
  final bool success;
  final String? token;
  final UserData? user;
  final String? error;
  final bool offline;

  AuthResult({
    required this.success,
    this.token,
    this.user,
    this.error,
    this.offline = false,
  });
}

/// User data from API
class UserData {
  final int id;
  final String name;
  final String phoneNumber;
  final int? age;
  final String? gender;
  final String? bloodGroup;
  final List<String> allergies;
  final List<String> conditions;
  final String? emergencyContact;
  final String? emergencyPhone;
  final DateTime createdAt;
  final UserPreferences? preferences;
  final List<UserConsent> consents;

  UserData({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.age,
    this.gender,
    this.bloodGroup,
    this.allergies = const [],
    this.conditions = const [],
    this.emergencyContact,
    this.emergencyPhone,
    required this.createdAt,
    this.preferences,
    this.consents = const [],
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'],
      name: json['name'],
      phoneNumber: json['phone_number'],
      age: json['age'],
      gender: json['gender'],
      bloodGroup: json['blood_group'],
      allergies: (json['allergies'] as List?)?.cast<String>() ?? [],
      conditions: (json['conditions'] as List?)?.cast<String>() ?? [],
      emergencyContact: json['emergency_contact'],
      emergencyPhone: json['emergency_phone'],
      createdAt: DateTime.parse(json['created_at']),
      preferences: json['preferences'] != null
          ? UserPreferences.fromJson(json['preferences'])
          : null,
      consents: (json['consents'] as List?)
              ?.map((c) => UserConsent.fromJson(c))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone_number': phoneNumber,
        'age': age,
        'gender': gender,
        'blood_group': bloodGroup,
        'allergies': allergies,
        'conditions': conditions,
        'emergency_contact': emergencyContact,
        'emergency_phone': emergencyPhone,
        'created_at': createdAt.toIso8601String(),
        'preferences': preferences?.toJson(),
        'consents': consents.map((c) => c.toJson()).toList(),
      };
}

/// User preferences
class UserPreferences {
  final String language;
  final bool emergencyEnabled;
  final bool medicineReminders;
  final bool notificationEnabled;
  final bool darkMode;

  UserPreferences({
    required this.language,
    required this.emergencyEnabled,
    required this.medicineReminders,
    required this.notificationEnabled,
    required this.darkMode,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      language: json['language'] ?? 'en',
      emergencyEnabled: json['emergency_enabled'] ?? true,
      medicineReminders: json['medicine_reminders'] ?? true,
      notificationEnabled: json['notification_enabled'] ?? true,
      darkMode: json['dark_mode'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'language': language,
        'emergency_enabled': emergencyEnabled,
        'medicine_reminders': medicineReminders,
        'notification_enabled': notificationEnabled,
        'dark_mode': darkMode,
      };
}

/// User consent record
class UserConsent {
  final int id;
  final String dataCategory;
  final String purpose;
  final bool granted;
  final String? consentText;
  final DateTime createdAt;
  final DateTime? expiresAt;

  UserConsent({
    required this.id,
    required this.dataCategory,
    required this.purpose,
    required this.granted,
    this.consentText,
    required this.createdAt,
    this.expiresAt,
  });

  factory UserConsent.fromJson(Map<String, dynamic> json) {
    return UserConsent(
      id: json['id'],
      dataCategory: json['data_category'],
      purpose: json['purpose'],
      granted: json['granted'],
      consentText: json['consent_text'],
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'data_category': dataCategory,
        'purpose': purpose,
        'granted': granted,
        'consent_text': consentText,
        'created_at': createdAt.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
      };
}

/// Consent item for signup
class ConsentItem {
  final String dataCategory;
  final String purpose;
  final bool granted;
  final String? consentText;

  ConsentItem({
    required this.dataCategory,
    required this.purpose,
    required this.granted,
    this.consentText,
  });

  Map<String, dynamic> toJson() => {
        'data_category': dataCategory,
        'purpose': purpose,
        'granted': granted,
        if (consentText != null) 'consent_text': consentText,
      };
}
