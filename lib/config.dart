import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, kReleaseMode;

String _normalizeApiBase(String value) =>
    value.trim().replaceAll(RegExp(r'/+$'), '');

String _validateApiBase(String base) {
  final normalized = _normalizeApiBase(base);
  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    throw StateError(
      'API_BASE must be an absolute URL (example: https://api.example.com/api).',
    );
  }

  if (kReleaseMode && uri.scheme.toLowerCase() != 'https') {
    throw StateError(
      'API_BASE must use HTTPS in release builds. Received: $normalized',
    );
  }

  return normalized;
}

String _resolveApiBase() {
  const fromEnv = String.fromEnvironment('API_BASE', defaultValue: '');
  final resolved = fromEnv.isNotEmpty ? fromEnv : _resolveFallbackApiBase();
  return _validateApiBase(resolved);
}

String _resolveFallbackApiBase() {
  if (kIsWeb) {
    return 'http://localhost:3001/api';
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    // Android emulator maps host machine localhost to 10.0.2.2.
    return 'http://10.0.2.2:3001/api';
  }

  return 'http://localhost:3001/api';
}

final String kDefaultApiBase = _resolveApiBase();
