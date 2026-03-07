

import 'package:flutter/material.dart';
import 'package:lokseva/screens/home.dart';
import 'package:lokseva/screens/oauth/login_screen.dart';

class LokSevaApp extends StatelessWidget {
  const LokSevaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LoginScreen(),
      routes: {
        '/home': (context) => Home(),
        '/login': (context) => LoginScreen(),
      },
    );
  }
}
