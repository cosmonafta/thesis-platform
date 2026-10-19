import 'package:flutter/material.dart';
import 'package:mobile_app/screens/admin_screen.dart';
import 'package:mobile_app/screens/conversation_screen.dart';
import 'package:mobile_app/screens/experiment_pairing_screen.dart';
import 'package:mobile_app/screens/home_screen.dart';
import 'package:mobile_app/screens/instructions.dart';
import 'package:mobile_app/screens/lobby_screen.dart';
import 'package:mobile_app/screens/qualification_screen.dart';
import 'package:mobile_app/screens/training_screen.dart';



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