import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  static const Color _backgroundColor = Color(0xFFF1F1F1);

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleEmailLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen()),
    );
  }

  void _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    var user = await _authService.signInWithGoogle();
    if (mounted) setState(() => _isLoading = false);

    if (user != null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      }
    } else {
      _showError('Google Sign-In failed or cancelled');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDark))
            : SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 50.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 200,
                width: 200,
                child: Lottie.asset('assets/animations/intro.json', repeat: true, animate: true),
              ),
              const SizedBox(height: 20),
              const Text('3D Ausqa', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryDark),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryDark),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 30),

              // Email ile Giriş Butonu
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _handleEmailLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentYellow,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Sign In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 15),

              // Google ile Giriş Butonu (glogo.png kullanılarak)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: _handleGoogleLogin,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryDark),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/glogo.png', height: 24, width: 24),
                      const SizedBox(width: 12),
                      const Text('Continue with Google', style: TextStyle(fontSize: 16, color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                child: const Text("Don't have an account? Sign Up", style: TextStyle(color: AppColors.primaryDark)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}