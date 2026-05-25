import 'package:logger/logger.dart';

/// Logger centralizado para CaliberIA
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
    ),
  );

  static void info(String message) => _logger.i(message);
  static void debug(String message) => _logger.d(message);
  static void warning(String message) => _logger.w(message);
  static void error(String message, [dynamic error, StackTrace? stack]) =>
      _logger.e(message, error: error, stackTrace: stack);

  /// Log específico para IA
  static void aiRequest(String provider, String model) =>
      _logger.i('🤖 [$provider] Solicitando análisis con modelo: $model');

  static void aiResponse(String provider, Duration duration) =>
      _logger.i('✅ [$provider] Respuesta recibida en ${duration.inSeconds}s');

  static void aiError(String provider, String error) =>
      _logger.e('❌ [$provider] Error: $error');

  static void aiRetry(String provider, int attempt) =>
      _logger.w('🔄 [$provider] Reintento #$attempt');
}
