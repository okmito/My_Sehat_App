import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resolves the backend base URL for Health Record API calls.
String resolveHealthRecordBaseUrl() {
  const override = String.fromEnvironment('HEALTH_RECORD_BASE_URL');
  if (override.isNotEmpty) return override;

  if (kIsWeb) {
    return 'http://localhost:8004/api/v1';
  }

  if (!kIsWeb && Platform.isAndroid) {
    return 'http://10.0.2.2:8004/api/v1';
  }

  return 'http://localhost:8004/api/v1';
}

final healthRecordBaseUrlProvider =
    Provider<String>((_) => resolveHealthRecordBaseUrl());
