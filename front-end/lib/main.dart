import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lokseva/screens/home.dart';
import 'package:lokseva/screens/oauth/login_screen.dart';
import 'package:lokseva/services/api_service.dart';
import 'package:lokseva/services/complete_profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LokSeva',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
          case '/home':
            final profile = settings.arguments as UserProfileResponse;
            return MaterialPageRoute(
              builder: (_) => Home(),
            );
          case '/complete-profile':
            final profile = settings.arguments as UserProfileResponse;
            return MaterialPageRoute(
              builder: (_) => CompleteProfileScreen(initialProfile: profile),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
        }
      },
    );
  }
}