import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'controllers/auth_controller.dart';
import 'controllers/recognition_controller.dart';
import 'views/login_screen.dart';
import 'views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool isFirebaseInitialized = false;
  try {
    await Firebase.initializeApp();
    isFirebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => RecognitionController()..initialize()),
      ],
      child: SmartAttendanceApp(isFirebaseInitialized: isFirebaseInitialized),
    ),
  );
}

class SmartAttendanceApp extends StatelessWidget {
  final bool isFirebaseInitialized;
  const SmartAttendanceApp({super.key, required this.isFirebaseInitialized});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Attendance',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      builder: (context, child) {
        if (!isFirebaseInitialized) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 80),
                    const SizedBox(height: 16),
                    const Text(
                      'Firebase Not Configured',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The app requires Firebase to be configured properly. Please add your google-services.json (Android) or GoogleService-Info.plist (iOS) and enable Authentication and Firestore.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        context.read<AuthController>().setMockAuthenticated(true);
                      },
                      child: const Text('Bypass to Login (Mock Mode)'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return child!;
      },
      home: Consumer<AuthController>(
        builder: (context, auth, _) {
          return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}
