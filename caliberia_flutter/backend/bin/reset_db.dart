import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart';

void main() async {
  final env = DotEnv(includePlatformEnvironment: true)..load(['.env']);

  final connection = await Connection.open(
    Endpoint(
      host: env['DB_HOST'] ?? '',
      port: int.parse(env['DB_PORT'] ?? '5432'),
      database: env['DB_NAME'] ?? '',
      username: env['DB_USER'] ?? '',
      password: env['DB_PASSWORD'] ?? '',
    ),
    settings: ConnectionSettings(sslMode: SslMode.require),
  );

  await connection.execute('DELETE FROM analyses');
  await connection.execute('DELETE FROM audit_log');
  print('✅ Base de datos reseteada - todas las tablas vaciadas');
  
  final count = await connection.execute('SELECT COUNT(*) FROM analyses');
  print('Análisis restantes: ${count.first[0]}');

  await connection.close();
}
