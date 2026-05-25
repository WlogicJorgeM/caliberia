import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart';
import '../database.dart';

class AuthRoutes {
  final Database db;
  final DotEnv env;

  AuthRoutes(this.db, this.env);

  Router get router {
    final r = Router();
    r.post('/login', _login);
    r.post('/register', _register);
    r.get('/me', _me);
    return r;
  }

  /// POST /api/auth/login
  Future<Response> _login(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());
      final email = body['email'] as String? ?? '';
      final password = body['password'] as String? ?? '';

      if (email.isEmpty || password.isEmpty) {
        return _jsonResponse(400, {'error': 'Email y contraseña requeridos'});
      }

      final hash = sha256.convert(utf8.encode(password)).toString();

      final result = await db.connection.execute(
        Sql.named('SELECT id, email, full_name, role FROM users WHERE email = @email AND password_hash = @hash'),
        parameters: {'email': email, 'hash': hash},
      );

      if (result.isEmpty) {
        return _jsonResponse(401, {'error': 'Credenciales inválidas'});
      }

      final user = result.first;
      final userId = user[0] as int;
      final userEmail = user[1] as String;
      final fullName = user[2] as String?;
      final role = user[3] as String;

      // Actualizar last_login
      await db.connection.execute(
        Sql.named('UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = @id'),
        parameters: {'id': userId},
      );

      // Generar JWT
      final jwt = JWT({
        'userId': userId,
        'email': userEmail,
        'role': role,
      });
      final token = jwt.sign(
        SecretKey(env['JWT_SECRET'] ?? 'secret'),
        expiresIn: const Duration(hours: 24),
      );

      return _jsonResponse(200, {
        'token': token,
        'user': {
          'id': userId,
          'email': userEmail,
          'fullName': fullName,
          'role': role,
        },
      });
    } catch (e) {
      return _jsonResponse(500, {'error': 'Error interno: $e'});
    }
  }

  /// POST /api/auth/register
  Future<Response> _register(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());
      final email = body['email'] as String? ?? '';
      final password = body['password'] as String? ?? '';
      final fullName = body['fullName'] as String? ?? '';

      if (email.isEmpty || password.isEmpty) {
        return _jsonResponse(400, {'error': 'Email y contraseña requeridos'});
      }

      final hash = sha256.convert(utf8.encode(password)).toString();

      await db.connection.execute(
        Sql.named('INSERT INTO users (email, password_hash, full_name) VALUES (@email, @hash, @name)'),
        parameters: {'email': email, 'hash': hash, 'name': fullName},
      );

      return _jsonResponse(201, {'message': 'Usuario creado exitosamente'});
    } on ServerException {
      return _jsonResponse(409, {'error': 'El email ya está registrado'});
    } catch (e) {
      return _jsonResponse(500, {'error': 'Error interno: $e'});
    }
  }

  /// GET /api/auth/me
  Future<Response> _me(Request req) async {
    final authHeader = req.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return _jsonResponse(401, {'error': 'Token requerido'});
    }

    try {
      final token = authHeader.substring(7);
      final jwt = JWT.verify(token, SecretKey(env['JWT_SECRET'] ?? 'secret'));
      return _jsonResponse(200, jwt.payload);
    } catch (_) {
      return _jsonResponse(401, {'error': 'Token inválido o expirado'});
    }
  }

  Response _jsonResponse(int status, Map<String, dynamic> body) {
    return Response(status,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'});
  }
}
