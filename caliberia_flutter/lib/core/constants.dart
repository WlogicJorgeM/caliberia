/// Constantes de la aplicación
class AppConstants {
  // Auth
  static const int sessionTimeoutMinutes = 60;

  // AI
  static const int aiTimeoutSeconds = 90;
  static const int aiMaxRetries = 3;
  static const int maxImageWidth = 800;
  static const int imageQuality = 60;
  static const int maxImageSizeKB = 500;

  // Storage
  static const int maxHistoryItems = 100;
  static const String dbName = 'caliberia.db';
  static const int dbVersion = 1;

  // UI
  static const Duration animDuration = Duration(milliseconds: 300);
}

/// Proveedores de IA disponibles
enum AIProvider { groq, ollama, auto }
