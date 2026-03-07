// =============================================================================
// LOGIN SCREEN
// =============================================================================

import 'package:flutter/material.dart';
import 'package:lokseva/screens/home.dart';
import 'package:lokseva/services/auth_service.dart';
import 'package:lokseva/services/user_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  /// Handle Google Sign-In button press
  Future<void> _handleSignIn() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Complete sign-in flow (Firebase + Backend sync)
      final result = await _authService.signInWithGoogle();

      if (! mounted) return;

      // Check if profile is complete
      if (result.isNewUser || ! result.userProfile.isComplete) {
        // New user or incomplete profile - go to profile completion
        _showSnackBar("Welcome!  Please complete your profile.");
        Navigator.pushReplacementNamed(
          context,
          '/complete-profile',
          arguments: result.userProfile,
        );
      } else {
        // Existing user with complete profile - go to home
        _showSnackBar("Welcome back, ${result.userProfile.name}!");
        UserState().setUser(result.userProfile);
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (context) => Home(),
        ));
      }

    } on AuthException catch (e) {
      _showSnackBar(e. message, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red. shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: AlignmentGeometry.topCenter,
            end: AlignmentGeometry.bottomCenter,
            colors: [Color.fromARGB(255, 50, 0, 66), Colors.black])
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Title
                const Text(
                  "LokSeva",
                  style:  TextStyle(
                    fontSize:  56,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurpleAccent,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Your Gateway to Public Services",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 80),

                // Google Sign-In Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    icon: _isLoading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const ImageIcon(
                      AssetImage("assets/icons/google.png"),
                      size: 24,
                    ),
                    label: Text(_isLoading ? "Signing in..." : "Sign in with Google"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors. deepPurpleAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      )),
                    onPressed: _isLoading ? null : _handleSignIn))
              ])),
        ),
      ));
  }
}