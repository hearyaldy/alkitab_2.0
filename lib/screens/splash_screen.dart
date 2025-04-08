import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(seconds: 3), () {
      context.go('/home'); // Navigate to home after 3 seconds
    });

    return Scaffold(
      backgroundColor: Colors.blue, // You can customize the background color
      body: Center(
        child: Text(
          'Alkitab 2.0',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
