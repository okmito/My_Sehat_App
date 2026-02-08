import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_config.dart';

/// Resolves the backend base URL for Health Record API calls.
///
/// Uses centralized ApiConfig for Render compatibility.
/// Override with --dart-define=HEALTH_RECORD_BASE_URL=... if needed.
String resolveHealthRecordBaseUrl() {
  const override = String.fromEnvironment('HEALTH_RECORD_BASE_URL');
  if (override.isNotEmpty) return override;

  // Use centralized API config (supports local dev + Render production)
  return '${ApiConfig.healthRecordsUrl}/api/v1';
}

final healthRecordBaseUrlProvider =
    Provider<String>((_) => resolveHealthRecordBaseUrl());
