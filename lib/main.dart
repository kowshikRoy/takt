import 'package:flutter/material.dart';
import 'package:takt/onboarding_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeutschApp',
      theme: ThemeData(
        primarySwatch: Colors.red,
        fontFamily: 'Spline Sans',
      ),
      home: const OnboardingScreen(),
    );
  }
}
