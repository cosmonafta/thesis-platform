import 'package:flutter/material.dart';
import 'package:mobile_app/screens/home_screen.dart';




class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Conversational Test App',
home: const HomeScreen(),    );
  }
}