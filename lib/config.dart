import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

String _resolveApiBase() {
  const fromEnv = String.fromEnvironment('API_BASE', defaultValue: '');
  if (fromEnv.isNotEmpty) {
    return fromEnv;
  }

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
