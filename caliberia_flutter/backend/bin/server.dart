import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:dotenv/dotenv.dart';
import '../lib/database.dart';
import '../lib/routes/auth_routes.dart';
import '../lib/routes/analysis_routes.dart';

void main() async {
  final env = DotEnv(includePlatformEnvironment: true)..load(['.env']);
  final port = int.parse(env['PORT'] ?? '3000');

  // Inicializar base de datos
  final db = Database(env);
  await db.initialize();
  print('✅ Base de datos conectada y tablas creadas');

  // Router
  final router = Router();

  // Health check
  router.get('/api/health', (Request req) {
    return Response.ok('{"status":"ok","version":"2.0.0"}',
        headers: {'Content-Type': 'application/json'});
  });

  // Rutas
  final authRoutes = AuthRoutes(db, env);
  final analysisRoutes = AnalysisRoutes(db);

  router.mount('/api/auth/', authRoutes.router.call);
  router.mount('/api/analysis/', analysisRoutes.router.call);

  // Middleware
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(router.call);

  // Iniciar servidor
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('🚀 CaliberIA Backend corriendo en http://localhost:${server.port}');
}
