import 'dart:io';
import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart';

class Database {
  final DotEnv _env;
  late Connection _connection;

  Database(this._env);

  Connection get connection => _connection;

  Future<void> initialize() async {
    final endpoint = Endpoint(
      host: _env['DB_HOST'] ?? Platform.environment['DB_HOST'] ?? 'localhost',
      port: int.parse(_env['DB_PORT'] ?? Platform.environment['DB_PORT'] ?? '5432'),
      database: _env['DB_NAME'] ?? Platform.environment['DB_NAME'] ?? 'caliberia_1',
      username: _env['DB_USER'] ?? Platform.environment['DB_USER'] ?? 'caliberia_1',
      password: _env['DB_PASSWORD'] ?? Platform.environment['DB_PASSWORD'] ?? '',
    );

    _connection = await Connection.open(
      endpoint,
      settings: ConnectionSettings(sslMode: SslMode.require),
    );

    await _createTables();
  }

  Future<void> _createTables() async {
    await _connection.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        full_name VARCHAR(255),
        role VARCHAR(50) DEFAULT 'analyst',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        last_login TIMESTAMP
      );
    ''');

    await _connection.execute('''
      CREATE TABLE IF NOT EXISTS analyses (
        id VARCHAR(50) PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        image_base64 TEXT NOT NULL,
        caliber VARCHAR(100),
        ammo_type VARCHAR(100),
        compatible_weapon VARCHAR(200),
        estimated_length VARCHAR(50),
        possible_brands TEXT[],
        confidence DECIMAL(3,2),
        description TEXT,
        ai_provider VARCHAR(50),
        response_time_ms INTEGER,
        notes TEXT DEFAULT '',
        feedback VARCHAR(10) DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    await _connection.execute('''
      CREATE TABLE IF NOT EXISTS audit_log (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id),
        action VARCHAR(100) NOT NULL,
        details TEXT,
        ip_address VARCHAR(45),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    // Insertar usuario admin si no existe
    await _connection.execute(Sql.named('''
      INSERT INTO users (email, password_hash, full_name, role)
      VALUES (@email, @hash, @name, @role)
      ON CONFLICT (email) DO NOTHING
    '''), parameters: {
      'email': 'admin@admin.com',
      'hash': 'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3',
      'name': 'Administrador',
      'role': 'admin',
    });
  }

  Future<void> close() async {
    await _connection.close();
  }
}
