import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
 
  // FIREBASE KEYS HERE:
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "API_KEY_IS_HIDDEN_FOR_SECURITY", // REPLACE WITH YOUR FIREBASE API KEY
  authDomain: "civiclens-ssh36.firebaseapp.com",
  projectId: "civiclens-ssh36",
  storageBucket: "civiclens-ssh36.firebasestorage.app",
  messagingSenderId: "1051389680609",
  appId: "1:1051389680609:web:6b3f1bb655e019590fd0a0",

    ),
  );
  
  runApp(const CivicLensApp());
}

class CivicLensApp extends StatelessWidget {
  const CivicLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CivicLens E-Governance',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E), 
          secondary: const Color(0xFFFF6D00), 
          surface: Colors.white,   
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: StreamBuilder<User?>(
        stream: AuthService().authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const HomeScreen(); 
          }
          return const LoginScreen(); 
        },
      ),
    );
  }
}