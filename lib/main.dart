import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'scoring/forest.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'theme/app_theme.dart';
import 'ui/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (hf2signalsafe)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[SignalSafe] Firebase initialized successfully with hf2signalsafe.');
    AuthService().initialize();
    // Start real-time Firestore listeners (block_events, blacklist, scan_reports, audit_log)
    FirestoreService().startListening();
  } catch (e) {
    debugPrint('[SignalSafe] Firebase initialization fallback mode: $e');
  }

  // Load the 50-tree Random Forest model from assets
  try {
    await ForestEvaluator.initialize(assetPath: 'assets/model.json');
    debugPrint('[SignalSafe] Random Forest Model loaded successfully into memory.');
  } catch (e) {
    debugPrint('[SignalSafe] Error loading model: $e');
  }

  runApp(const SignalSafeApp());
}

class SignalSafeApp extends StatelessWidget {
  const SignalSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SignalSafe — Campus Network Security',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainShell(),
    );
  }
}
