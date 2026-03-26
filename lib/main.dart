import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'screens/main_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/auth/role_selection_screen.dart'; // Assume this is the starting auth screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AthleteProfileApp());
}

class AppColors {
  static const Color primary = Color(0xFF5850EC);
  static const Color secondary = Color(0xFF7C3AED);
  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color backgroundDark = Color(0xFF0B0F19);
  static const Color cardDark = Color(0xFF161B2A);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color accentPurple = Color(0xFF8B5CF6);
  
  // Status Colors for Recruiter
  static const Color statusInterested = Color(0xFF3B82F6); // Blue
  static const Color statusContacted = Color(0xFFF59E0B); // Orange
  static const Color statusInterview = Color(0xFF10B981); // Green
  static const Color statusPassed = Color(0xFFEF4444); // Red
}

class AthleteProfileApp extends StatelessWidget {
  const AthleteProfileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScoutLinkz Athlete Profile',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // Defaulting to dark mode as per designs
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.backgroundDark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.cardDark,
          background: AppColors.backgroundDark,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      home: _buildAuthWrapper(),
    );
  }

  Widget _buildAuthWrapper() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('scouts').doc(snapshot.data!.uid).get(),
            builder: (context, scoutSnapshot) {
              if (scoutSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (scoutSnapshot.hasData && scoutSnapshot.data!.exists) {
                return const MainScreen(initialRole: UserRole.recruiter);
              }
              return const MainScreen(initialRole: UserRole.athleteSelf);
            },
          );
        }
        return const RoleSelectionScreen(); // Navigate to role selection if not authenticated
      },
    );
  }
}
