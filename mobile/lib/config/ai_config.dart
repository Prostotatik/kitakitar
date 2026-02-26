/// Gemini API key for waste recognition (KitaKitar project).
/// Override via: flutter run --dart-define=GEMINI_API_KEY=your_key
const String geminiApiKey = String.fromEnvironment(
  'GEMINI_API_KEY',
  defaultValue: 'AIzaSyBMWhAcgneK6QodbP_ItqcXY9WIakVVywQ',
);

/// Set to true to always use mock response (plastic 0.05, paper 0.02 + tip). No API call.
const bool useMockResponse = true;
