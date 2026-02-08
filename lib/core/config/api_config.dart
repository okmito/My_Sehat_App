import 'dart:io';
import 'package:flutter/foundation.dart';

/// Centralized API Configuration for MySehat
///
/// This file manages all backend API URLs for the application.
/// Toggle between local development and Render production by changing [useProduction].
///
/// RENDER DEPLOYMENT:
/// Set [useProduction] = true before building for production
/// Or use: flutter build --dart-define=PRODUCTION=true
class ApiConfig {
  /// Set to true for Render production deployment
  /// Set to false for local development
  static const bool useProduction =
      bool.fromEnvironment('PRODUCTION', defaultValue: false);

  /// Render Gateway URL (update this after deploying to Render)
  static const String renderGatewayUrl = 'https://mysehat-gateway.onrender.com';

  /// Local development URLs (gateway routes all traffic)
  static String get _localGatewayUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    // Android emulator uses 10.0.2.2 to reach host machine's localhost
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    // iOS simulator and desktop use localhost directly
    return 'http://localhost:8000';
  }

  /// Main gateway base URL - use this for ALL API calls
  static String get gatewayUrl {
    return useProduction ? renderGatewayUrl : _localGatewayUrl;
  }

  // ============================================================================
  // SERVICE ENDPOINTS (all routed through gateway)
  // ============================================================================

  /// Auth API base URL (/auth/*)
  static String get authUrl => gatewayUrl;

  /// Diagnostics API base URL (/diagnostics/*)
  static String get diagnosticsUrl => '$gatewayUrl/diagnostics';

  /// Medicine Reminder API base URL (/medicine-reminder/*)
  static String get medicineUrl => '$gatewayUrl/medicine-reminder';

  /// Mental Health API base URL (/mental-health/*)
  static String get mentalHealthUrl => '$gatewayUrl/mental-health';

  /// SOS Emergency API base URL (/sos/*)
  static String get sosUrl => gatewayUrl;

  /// FHIR API base URL (/fhir/*)
  static String get fhirUrl => '$gatewayUrl/fhir';

  /// Health Records API base URL (/health-records/*)
  static String get healthRecordsUrl => '$gatewayUrl/health-records';

  /// DPDP/Consent API base URL (/api/v1/*)
  static String get dpdpUrl => gatewayUrl;

  // ============================================================================
  // LEGACY COMPATIBILITY (for gradual migration)
  // These match the old port-based URLs for services that haven't migrated yet
  // ============================================================================

  /// @deprecated Use [diagnosticsUrl] instead
  static String get legacyDiagnosticsUrl {
    if (useProduction) return '$gatewayUrl/diagnostics';
    if (kIsWeb) return 'http://localhost:8000/diagnostics';
    if (!kIsWeb && Platform.isAndroid)
      return 'http://10.0.2.2:8000/diagnostics';
    return 'http://localhost:8000/diagnostics';
  }

  /// @deprecated Use [medicineUrl] instead
  static String get legacyMedicineUrl {
    if (useProduction) return '$gatewayUrl/medicine-reminder';
    if (kIsWeb) return 'http://localhost:8000/medicine-reminder';
    if (!kIsWeb && Platform.isAndroid)
      return 'http://10.0.2.2:8000/medicine-reminder';
    return 'http://localhost:8000/medicine-reminder';
  }

  /// @deprecated Use [mentalHealthUrl] instead
  static String get legacyMentalHealthUrl {
    if (useProduction) return '$gatewayUrl/mental-health';
    if (kIsWeb) return 'http://localhost:8000/mental-health';
    if (!kIsWeb && Platform.isAndroid)
      return 'http://10.0.2.2:8000/mental-health';
    return 'http://localhost:8000/mental-health';
  }

  // ============================================================================
  // DEBUG HELPERS
  // ============================================================================

  /// Print current configuration (for debugging)
  static void printConfig() {
    debugPrint(
        '═══════════════════════════════════════════════════════════════');
    debugPrint('MySehat API Configuration');
    debugPrint(
        '═══════════════════════════════════════════════════════════════');
    debugPrint('Mode: ${useProduction ? "PRODUCTION" : "DEVELOPMENT"}');
    debugPrint('Gateway URL: $gatewayUrl');
    debugPrint(
        '───────────────────────────────────────────────────────────────');
    debugPrint('Auth:         $authUrl');
    debugPrint('Diagnostics:  $diagnosticsUrl');
    debugPrint('Medicine:     $medicineUrl');
    debugPrint('Mental Health: $mentalHealthUrl');
    debugPrint('SOS:          $sosUrl');
    debugPrint('FHIR:         $fhirUrl');
    debugPrint('Health Records: $healthRecordsUrl');
    debugPrint('DPDP:         $dpdpUrl');
    debugPrint(
        '═══════════════════════════════════════════════════════════════');
  }
}
