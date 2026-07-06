import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'admin_login_screen.dart';

const String ADMIN_API = "https://trace-payment-server.onrender.com/api/admin";

class AdminDashboardScreen extends StatefulWidget {
  final String token;
  const AdminDashboardScreen({super.key, required this.token});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String activeTab = "dashboard";

  Map<String, dynamic>? stats;
  List drivers = [];
  List liveRides = [];
  List allRides = [];
  Map<String, dynamic>? earnings;

  bool loading = false;
  String? error;

  Map<String, String> get authHeader => {
        "Authorization": "Bearer ${widget.token}",
      };

  @override
  void initState() {
    super.initState();
    loadTab();
  }

  Future<void> loadTab() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      if (activeTab == "dashboard") {
        final res =
            await http.get(Uri.parse("$ADMIN_API/stats"), headers: authHeader);
        stats = jsonDecode(res.body);
      } else if (activeTab == "drivers") {
        final res =
            await http.get(Uri.parse("$ADMIN_API/drivers"), headers: authHeader);
        drivers = jsonDecode(res.body)["drivers"];
      } else if (activeTab == "live") {
        final res = await http.get(Uri.parse("$ADMIN_API/rides/live"),
            headers: authHeader);
        liveRides = jsonDecode(res.body)["rides"];
      } else if (activeTab == "rides") {
        final res =
            await http.get(Uri.parse("$ADMIN_API/rides"), headers: authHeader);
        allRides = jsonDecode(res.body)["rides"];
      } else if (activeTab == "earnings") {
        final res =
            await http.get(Uri.parse("$ADMIN_API/earnings"), headers: authHeader);
        earnings = jsonDecode(res.body);
      }
    } catch (e) {
      error = "Failed to load data";
    }

    setState(() => loading = false);
  }

  Widget buildBody() {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    if (error != null) {
      return Center(
        child: Text(error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
      );
    }

    if (activeTab == "dashboard") {
      return dashboardTab();
    } else if (activeTab == "drivers") {
      return driversTab();
    } else if (activeTab == "live") {
      return ridesTab(liveRides, "Live Rides");
    } else if (activeTab == "rides") {
      return ridesTab(allRides, "All Rides");
    } else if (activeTab == "earnings") {
      return earningsTab();
    }

    return const SizedBox();
  }

  Widget dashboardTab() {
    if (stats == null) return const SizedBox();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        statTile("Total Users", stats!["totalUsers"]),
        statTile("Total Drivers", stats!["totalDrivers"]),
        statTile("Online Drivers", stats!["onlineDrivers"]),
        statTile("Total Rides", stats!["totalRides"]),
        statTile("Live Rides", stats!["liveRides"]),
        statTile("Total Revenue", "₹${stats!["totalRevenue"]}"),
      ],
    );
  }

  Widget driversTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: drivers.length,
      itemBuilder: (_, i) {
        final d = drivers[i];
        return cardTile(
          title: d["name"],
          subtitle: "${d["phone"]} • ${d["vehicleNumber"]}",
          trailing: d["online"] ? "ONLINE" : "OFFLINE",
        );
      },
    );
  }

  Widget ridesTab(List rides, String title) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rides.length,
      itemBuilder: (_, i) {
        final r = rides[i];
        return cardTile(
          title: "${r["userId"]?["name"] ?? "User"} → ${r["driverId"]?["name"] ?? "Driver"}",
          subtitle:
              "${r["pickupAddress"] ?? "Pickup"} → ${r["dropAddress"] ?? "Drop"}",
          trailing: "₹${r["pricing"]?["totalFare"] ?? r["fare"] ?? 0}",
        );
      },
    );
  }

  Widget earningsTab() {
    if (earnings == null) return const SizedBox();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        statTile("Total Earnings", "₹${earnings!["totalEarnings"]}"),
        statTile("Total Rides", earnings!["totalRides"]),
        statTile("Average Fare", "₹${earnings!["avgFare"]}"),
        statTile("Today's Earnings", "₹${earnings!["todayEarnings"]}"),
        statTile("Today's Rides", earnings!["todayRides"]),
      ],
    );
  }

  Widget statTile(String title, dynamic value) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1929),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        "$title: $value",
        style: const TextStyle(fontSize: 16, color: Colors.white),
      ),
    );
  }

  Widget cardTile({required String title, required String subtitle, required String trailing}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1929),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          Text(trailing,
              style: const TextStyle(color: Colors.greenAccent, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C2C2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1929),
        title: const Text("TRACE Admin", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                (_) => false,
              );
            },
          )
        ],
      ),
      body: buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0A1929),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        currentIndex: [
          "dashboard",
          "drivers",
          "live",
          "rides",
          "earnings"
        ].indexOf(activeTab),
        onTap: (i) {
          setState(() {
            activeTab = ["dashboard", "drivers", "live", "rides", "earnings"][i];
          });
          loadTab();
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Dashboard"),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Drivers"),
          BottomNavigationBarItem(icon: Icon(Icons.car_crash), label: "Live"),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "Rides"),
          BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: "Earnings"),
        ],
      ),
    );
  }
}
