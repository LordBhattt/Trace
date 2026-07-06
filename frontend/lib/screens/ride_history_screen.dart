import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'ride_detail_screen.dart';  // ✅ corrected import name

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  bool loading = true;
  List<dynamic> rides = [];

  static const Color bg = Color(0xFF0C2C2E);
  static const Color gold = Color(0xFFD4AF37);
  static const Color champagne = Color(0xFFF4E4C1);

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  Future<void> _loadRides() async {
    try {
      final list = await ApiService.getRideHistory();
      setState(() {
        rides = list;
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  String _formatDate(String? raw) {
    if (raw == null) return "";
    final dt = DateTime.tryParse(raw);
    if (dt == null) return "";
    return DateFormat("dd MMM, hh:mm a").format(dt);
  }

  Color _statusColor(String s) {
    switch (s) {
      case "paid":
        return Colors.greenAccent;
      case "completed":
        return Colors.orangeAccent;
      case "cancelled":
        return Colors.redAccent;
      case "started":
      case "arriving":
      case "ontrip":
        return Colors.blueAccent;
      default:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text("Ride History", style: TextStyle(color: champagne)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: champagne))
          : rides.isEmpty
              ? const Center(
                  child: Text("No rides yet",
                      style: TextStyle(color: champagne, fontSize: 16)),
                )
              : RefreshIndicator(
                  onRefresh: _loadRides,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rides.length,
                    itemBuilder: (_, i) => _rideCard(rides[i]),
                  ),
                ),
    );
  }

  Widget _rideCard(dynamic ride) {
    final pickup = ride["pickup"]?["label"] ?? "Pickup";
    final drop = ride["drop"]?["label"] ?? "Drop";

    final pricing = ride["pricing"] ?? {};
    final double totalFare =
        (pricing["totalFare"] ?? 0).toDouble(); // using backend fare

    final double distance = (ride["distanceKm"] ?? 0).toDouble();
    final String status = ride["status"] ?? "pending";
    final String date = _formatDate(ride["createdAt"]);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RideDetailScreen(ride: ride), // ✅ corrected class name
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF14242F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: gold.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pickup → Drop
            Text(pickup, style: const TextStyle(color: champagne, fontSize: 15)),
            const SizedBox(height: 4),
            Text(drop,
                style: const TextStyle(color: Colors.white60, fontSize: 14)),
            const SizedBox(height: 12),

            // Distance + Fare row
            Row(
              children: [
                Icon(Icons.straighten, color: gold.withOpacity(0.8), size: 18),
                const SizedBox(width: 6),
                Text("${distance.toStringAsFixed(1)} km",
                    style: const TextStyle(color: champagne)),
                const SizedBox(width: 14),
                const Icon(Icons.currency_rupee,
                    color: Colors.greenAccent, size: 18),
                Text(totalFare.toStringAsFixed(0),
                    style: const TextStyle(color: Colors.greenAccent)),
              ],
            ),

            const SizedBox(height: 12),

            // Status + Date row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _statusColor(status).withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(date,
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
