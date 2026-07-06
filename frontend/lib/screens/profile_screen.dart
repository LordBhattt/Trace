// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userProfile;
  Map<String, dynamic>? userStats;
  bool isLoading = true;

  static const Color bg = Color(0xFF0C2C2E);
  static const Color card = Color(0xFF14242F);
  static const Color gold = Color(0xFFD4AF37);
  static const Color champagne = Color(0xFFF4E4C1);

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final profile = await ApiService.getUserProfile();
      final stats = await ApiService.getUserStats();

      if (!mounted) return;

      setState(() {
        userProfile = profile["user"] ?? {};
        userStats = stats["stats"] ?? {};
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text("Profile", style: TextStyle(color: champagne)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: champagne))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _buildStats(),
          const SizedBox(height: 24),
          _buildMenu(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withOpacity(0.3)),
      ),
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 45,
            backgroundColor: Colors.white12,
            child: Icon(Icons.person, color: champagne, size: 46),
          ),
          const SizedBox(height: 12),
          Text(
            userProfile?["name"]?.toString() ?? "User",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: champagne,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            userProfile?["email"]?.toString() ?? "",
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            userProfile?["phone"]?.toString() ?? "",
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final stats = userStats ?? {};

    // SAFE VALUES (prevents all crashes)
    final int totalRides =
        (stats["totalRides"] is num) ? (stats["totalRides"] as num).toInt() : 0;

    final double totalDistance = (stats["totalDistance"] is num)
        ? (stats["totalDistance"] as num).toDouble()
        : 0.0;

    final double totalSpent = (stats["totalSpent"] is num)
        ? (stats["totalSpent"] as num).toDouble()
        : 0.0;

    final double rating = (stats["rating"] is num)
        ? (stats["rating"] as num).toDouble()
        : 5.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.local_taxi,
                  label: "Total Rides",
                  value: totalRides.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  icon: Icons.straighten,
                  label: "Total Distance",
                  value: "${totalDistance.toStringAsFixed(1)} km",
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.currency_rupee,
                  label: "Total Spent",
                  value: "₹${totalSpent.toStringAsFixed(0)}",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  icon: Icons.star,
                  label: "Rating",
                  value: rating.toStringAsFixed(1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: gold, size: 26),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: champagne,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _menuItem(
            Icons.history,
            "Ride History",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
          _menuItem(Icons.payment, "Payment Methods", () {}),
          _menuItem(Icons.info_outline, "About TRACE", () {}),
          const SizedBox(height: 12),
          _menuItem(Icons.logout, "Logout", _logout, isRed: true),
        ],
      ),
    );
  }

  Widget _menuItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isRed = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Icon(icon, color: isRed ? Colors.red : champagne),
        title: Text(
          title,
          style: TextStyle(
            color: isRed ? Colors.red : champagne,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: isRed ? Colors.red : Colors.white38,
        ),
        onTap: onTap,
      ),
    );
  }
}
