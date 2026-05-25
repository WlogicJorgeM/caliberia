import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/storage_service.dart';
import '../services/backend_service.dart';

class LoginScreen extends StatefulWidget {
  final Function(String) onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Complete todos los campos');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Intentar login con backend (PostgreSQL)
    final backendUser = await BackendService.login(email, password);
    if (backendUser != null) {
      await StorageService.saveSession(email);
      widget.onLogin(email);
      return;
    }

    // Fallback: auth local
    if (StorageService.validateCredentials(email, password)) {
      await StorageService.saveSession(email);
      widget.onLogin(email);
    } else {
      setState(() {
        _isLoading = false;
        _error = 'Credenciales de acceso inválidas';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.zinc950,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.emerald500.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.emerald500.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.shield,
                      size: 48,
                      color: AppColors.emerald500,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  const Text(
                    'CaliberIA',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'SISTEMA DE ANÁLISIS BALÍSTICO',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.emerald500,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Email
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      labelStyle: TextStyle(color: AppColors.zinc500),
                      prefixIcon:
                          Icon(Icons.person_outline, color: AppColors.zinc500),
                    ),
                    onSubmitted: (_) => _handleSubmit(),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      labelStyle: const TextStyle(color: AppColors.zinc500),
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: AppColors.zinc500),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.zinc500,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    onSubmitted: (_) => _handleSubmit(),
                  ),
                  const SizedBox(height: 12),

                  // Error
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.red500.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.red500.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _error!,
                        style:
                            const TextStyle(color: AppColors.red400, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'ACCEDER AL SISTEMA',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Footer
                  const Text(
                    'v2.0 • Investigación Académica',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.zinc600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
