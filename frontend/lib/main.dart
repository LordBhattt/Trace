// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 🔥 Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// 🔥 Local Notification Handler
import 'services/notification_service.dart';
import 'services/cart_manager.dart'; // ✅ NEW

// Screens
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';

// Navigator Key
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

// Background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("📨 Background message: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase Init
  await Firebase.initializeApp();

  // Background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Local notification setup
  await NotificationService.initialize();

  // ✅ Initialize Cart Manager
  await CartManager().initialize();

  runApp(
    const ProviderScope(child: TraceApp()),
  );
}

class TraceApp extends StatelessWidget {
  const TraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navKey,
      title: "TRACE",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: "Sans",
        scaffoldBackgroundColor: const Color(0xFF0C2C2E),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00D9FF),
          secondary: const Color(0xFF6C63FF),
          surface: const Color(0xFF1A3A3C),
        ),
      ),
      home: const SplashScreen(),
      routes: {
        "/login": (_) => const LoginScreen(),
        "/signup": (_) => const SignupScreen(),
        "/home": (_) => const HomeScreen(),
        "/profile": (_) => const ProfileScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.delayed(const Duration(milliseconds: 800));

    final token = prefs.getString('token');
    final activeRide = prefs.getString('current_ride_id');

    if (!mounted) return;

    // Not logged in
    if (token == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // Logged in + active ride
    if (activeRide != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    // Logged in + no active ride
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "TRACE",
          style: TextStyle(
            fontSize: 42,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
        ),
      ),
    );
  }
}