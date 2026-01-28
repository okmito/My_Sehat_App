import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resolves the backend base URL for SOS calls.
///
/// - Uses compile-time env `--dart-define=SOS_BASE_URL=...` when provided.
/// - Defaults to emulator-friendly hosts for Android/iOS/desktop.
String resolveSosBaseUrl() {
  const override = String.fromEnvironment('SOS_BASE_URL');
  if (override.isNotEmpty) return override;

  if (kIsWeb) {
    return 'http://localhost:8000';
  }

  if (!kIsWeb && Platform.isAndroid) {
    return 'http://10.0.2.2:8000';
  }

  return 'http://localhost:8000';
}

final sosBaseUrlProvider = Provider<String>((_) => resolveSosBaseUrl());
