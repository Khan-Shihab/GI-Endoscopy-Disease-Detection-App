/// App-wide configuration constants.
class AppConfig {
  /// Base URL for the FastAPI backend.
  ///
  /// - Android emulator -> host machine: http://10.0.2.2:8000
  /// - iOS simulator -> host machine:    http://localhost:8000
  /// - Physical device on same Wi-Fi:    http://<your-machine-LAN-IP>:8000
  /// - Production:                       https://your-deployed-api.com
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http:// 192.168.1.103:8000',
  );

  static const String predictEndpoint = '$apiBaseUrl/predict';
  static const String healthEndpoint = '$apiBaseUrl/health';

  static const Duration requestTimeout = Duration(seconds: 30);
  static const int maxImageSizeMb = 10;

  // ---------------------------------------------------------------------
  // Gemini (AI explanation of the detection result)
  // ---------------------------------------------------------------------
  //
  // ⚠️ SECURITY NOTE — read before shipping a build to anyone:
  // This key is compiled straight into the app binary. Anyone who installs
  // the app can pull it back out (a `strings` pass on the APK/IPA is enough)
  // and use it on your Google AI Studio quota. Two things to do:
  //   1. Rotate this key in https://aistudio.google.com/app/apikey — the one
  //      below was pasted into a chat, so treat it as already compromised.
  //   2. Before a real release, move this call behind your FastAPI backend
  //      (you already have one in backend/main.py) so the key lives on the
  //      server, not in the client. Happy to wire that up if useful.
  //
  // For now this lets you build/test the feature locally.
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyArThmugklm4CPzrhEMZzbnnNhcxTH69pI',
  );

  static const String geminiModel = 'gemini-2.5-flash';

  static const String geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent';
}
