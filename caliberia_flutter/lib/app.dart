import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';

class CaliberiaApp extends StatefulWidget {
  const CaliberiaApp({super.key});

  @override
  State<CaliberiaApp> createState() => _CaliberiaAppState();
}

class _CaliberiaAppState extends State<CaliberiaApp> {
  String? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final session = await StorageService.getSession();
    setState(() {
      _user = session;
      _loading = false;
    });
  }

  void _onLogin(String email) {
    setState(() => _user = email);
  }

  void _onLogout() async {
    await StorageService.clearSession();
    setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CaliberIA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _loading
          ? const Scaffold(
              backgroundColor: AppColors.zinc950,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.emerald500),
              ),
            )
          : _user != null
              ? HomeScreen(user: _user!, onLogout: _onLogout)
              : LoginScreen(onLogin: _onLogin),
    );
  }
}
