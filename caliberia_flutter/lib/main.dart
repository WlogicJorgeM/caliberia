import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'core/app_logger.dart';
import 'providers/analysis_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno
  await dotenv.load(fileName: '.env');

  // Orientación vertical
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Status bar transparente
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  AppLogger.info('CaliberIA v2.0 iniciando...');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AnalysisProvider()),
      ],
      child: const CaliberiaApp(),
    ),
  );
}
