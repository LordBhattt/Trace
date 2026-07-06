import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'ride_history_screen.dart';
import 'profile_screen.dart';
import 'admin_login_screen.dart';

// Food Imports
import 'food/food_home_screen.dart';
import 'food/order_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? userProfile;
  bool loading = true;
  String? _currentRideId;

  static const Color bg = Color(0xFF0C2C2E);
  static const Color gold = Color(0xFFD4AF37);
  static const Color champagne = Color(0xFFF4E4C1);

  // Admin unlock long-press timer
  DateTime? _pressStartTime;
  final Duration adminHoldDuration = Duration(seconds: 10);

  // Animations
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _loadUser();
    _loadActiveRide();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveRide() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentRideId = prefs.getString('current_ride_id');
    });
  }

  Future<void> _loadUser() async {
    try {
      final res = await ApiService.getUserProfile();
      if (res['success'] == true) {
        setState(() {
          userProfile = res['user'];
        });
      }
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // Admin unlock trigger check
  void _checkAdminUnlock() {
    if (_pressStartTime == null) return;

    final pressDuration = DateTime.now().difference(_pressStartTime!);
    if (pressDuration >= adminHoldDuration) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      );
    }

    _pressStartTime = null;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveRide = _currentRideId != null;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: GestureDetector(
          onLongPressStart: (_) => _pressStartTime = DateTime.now(),
          onLongPressEnd: (_) => _checkAdminUnlock(),
          child: Text(
            userProfile == null
                ? "TRACE"
                : "Welcome, ${userProfile!['name']}",
            style: const TextStyle(
              color: champagne,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: champagne),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: champagne),
            onPressed: _logout,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: champagne))
          : FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),

                      // TRACE Logo
                      GestureDetector(
                        onLongPressStart: (_) =>
                            _pressStartTime = DateTime.now(),
                        onLongPressEnd: (_) => _checkAdminUnlock(),
                        child: ShaderMask(
                          shaderCallback: (bounds) =>
                              const LinearGradient(
                            colors: [champagne, gold],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            "TRACE",
                            style: TextStyle(
                              fontSize: 60,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      Text(
                        "Smart Mobility & Delivery",
                        style: TextStyle(
                          color: champagne.withOpacity(0.7),
                          fontSize: 14,
                          letterSpacing: 2,
                        ),
                      ),

                      const SizedBox(height: 50),

                      // ACTIVE RIDE SECTION
                      if (hasActiveRide) ...[
                        _mainButton(
                          "Resume Active Ride",
                          Icons.directions_car_filled_rounded,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const MapScreen(serviceType: "cab"),
                              ),
                            );
                          },
                          isPrimary: true,
                        ),
                        const SizedBox(height: 20),
                      ],

                      // PRIMARY SERVICES
                      if (!hasActiveRide) ...[
                        _mainButton(
                          "Book a Cab",
                          Icons.local_taxi_rounded,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const MapScreen(serviceType: "cab"),
                              ),
                            );
                          },
                          isPrimary: true,
                        ),
                        const SizedBox(height: 20),

                        // Order Food – SAME STYLE AS BOOK CAB
                        _mainButton(
                          "Order Food",
                          Icons.restaurant_rounded,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FoodHomeScreen(),
                              ),
                            );
                          },
                          isPrimary: true,
                        ),
                        const SizedBox(height: 20),
                      ],

                      // SECONDARY ACTIONS
                      _mainButton(
                        "Ride History",
                        Icons.history_rounded,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RideHistoryScreen(),
                            ),
                          );
                        },
                        isPrimary: false,
                      ),
                      const SizedBox(height: 12),
                      _mainButton(
                        "Food Orders",
                        Icons.receipt_long_rounded,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OrderHistoryScreen(),
                            ),
                          );
                        },
                        isPrimary: false,
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // MAIN BUTTON UI BUILDER
  Widget _mainButton(
    String text,
    IconData icon,
    VoidCallback onTap, {
    required bool isPrimary,
    Gradient? gradient,
    bool isSpecial = false,
  }) {
    final bool useGradient = gradient != null && isPrimary == false;
    // ^ keep gradient support if you ever want special secondary buttons later

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: useGradient
              ? Colors.transparent
              : (isPrimary ? gold : const Color(0xFF0A1929)),
          foregroundColor: isPrimary ? bg : champagne,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(
            color: isSpecial
                ? Colors.orange
                : gold.withOpacity(isPrimary ? 0.8 : 0.4),
            width: isPrimary ? 2 : 1.5,
          ),
          elevation: isPrimary ? 8 : 0,
          shadowColor: gold.withOpacity(0.4),
        ),
        child: useGradient
            ? Ink(
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 26),
                      const SizedBox(width: 12),
                      Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: isSpecial
                        ? Colors.orange
                        : (isPrimary ? bg : gold),
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: TextStyle(
                      color: isSpecial
                          ? Colors.orange
                          : (isPrimary ? bg : champagne),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
