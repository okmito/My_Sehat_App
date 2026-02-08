import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_config.dart';

/// Resolves the backend base URL for SOS calls.
///
/// Uses centralized ApiConfig for Render compatibility.
/// Override with --dart-define=SOS_BASE_URL=... if needed.
String resolveSosBaseUrl() {
  const override = String.fromEnvironment('SOS_BASE_URL');
  if (override.isNotEmpty) return override;

  // Use centralized API config (supports local dev + Render production)
  return ApiConfig.sosUrl;
}

final sosBaseUrlProvider = Provider<String>((_) => resolveSosBaseUrl());
