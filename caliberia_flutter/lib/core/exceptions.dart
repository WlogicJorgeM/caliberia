/// Excepciones personalizadas para CaliberIA
class CaliberiaException implements Exception {
  final String message;
  final String? details;
  CaliberiaException(this.message, {this.details});

  @override
  String toString() => details != null ? '$message: $details' : message;
}

class AIServiceException extends CaliberiaException {
  final String provider;
  AIServiceException(String message, {required this.provider, String? details})
      : super(message, details: details);
}

class AIUnavailableException extends AIServiceException {
  AIUnavailableException({required String provider})
      : super('Servicio de IA no disponible', provider: provider);
}

class AIParseException extends AIServiceException {
  final String rawResponse;
  AIParseException({required String provider, required this.rawResponse})
      : super('No se pudo interpretar la respuesta del modelo',
            provider: provider, details: rawResponse);
}

class AITimeoutException extends AIServiceException {
  AITimeoutException({required String provider})
      : super('El modelo tardó demasiado en responder', provider: provider);
}

class StorageException extends CaliberiaException {
  StorageException(String message, {String? details})
      : super(message, details: details);
}

class AuthException extends CaliberiaException {
  AuthException(String message) : super(message);
}
