import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';

class CaliberIAApp extends StatefulWidget {
  const CaliberIAApp({super.key});

  @override
  State<CaliberIAApp> createState() => _CaliberIAAppState();
}

class _CaliberIAAppState extends State<CaliberIAApp> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _user;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final session = await StorageService.getSession();
    setState(() {
      _isAuthenticated = session != null;
      _user = session;
      _isLoading = false;
    });
  }

  void _onLogin(String email) {
    setState(() {
      _isAuthenticated = true;
      _user = email;
    });
  }

  void _onLogout() async {
    await StorageService.clearSession();
    setState(() {
      _isAuthenticated = false;
      _user = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CaliberIA',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: _isLoading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _isAuthenticated
              ? HomeScreen(user: _user!, onLogout: _onLogout)
              : LoginScreen(onLogin: _onLogin),
    );
  }
}
