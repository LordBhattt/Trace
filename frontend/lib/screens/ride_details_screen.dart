// lib/screens/ride_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RideDetailScreen extends StatelessWidget {
  final Map<String, dynamic> ride;

  static const Color bg = Color(0xFF0C2C2E);
  static const Color card = Color(0xFF14242F);
  static const Color gold = Color(0xFFD4AF37);
  static const Color champagne = Color(0xFFF4E4C1);

  const RideDetailScreen({super.key, required this.ride});

  String _formatDate(String? raw) {
    if (raw == null) return "";
    final dt = DateTime.tryParse(raw);
    if (dt == null) return "";
    return DateFormat("dd MMM yyyy • hh:mm a").format(dt);
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
      case "assigned":
      case "confirmed":
        return Colors.blueAccent;
      default:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = (ride["pickup"] ?? {}) as Map<String, dynamic>;
    final drop = (ride["drop"] ?? {}) as Map<String, dynamic>;
    final pricing = (ride["pricing"] ?? {}) as Map<String, dynamic>;
    final driver = (ride["driver"] ?? {}) as Map<String, dynamic>;

    final double distanceKm = (ride["distanceKm"] ?? 0) is num
        ? (ride["distanceKm"] as num).toDouble()
        : 0.0;

    final int etaMin = (ride["etaMin"] ?? 0) is num
        ? (ride["etaMin"] as num).toInt()
        : 0;

    final int foodStops = (ride["foodStops"] ?? 0) is num
        ? (ride["foodStops"] as num).toInt()
        : 0;

    final int suggestionsCount =
        (ride["selectedSuggestions"] as List?)?.length ?? 0;

    final num totalFareNum = (pricing["totalFare"] ?? 0) is num
        ? pricing["totalFare"] as num
        : 0;
    final num baseFareNum = (pricing["baseFare"] ?? 0) is num
        ? pricing["baseFare"] as num
        : 0;
    final num distanceFareNum = (pricing["distanceFare"] ?? 0) is num
        ? pricing["distanceFare"] as num
        : 0;
    final num timeFareNum = (pricing["timeFare"] ?? 0) is num
        ? pricing["timeFare"] as num
        : 0;
    final num foodFareNum = (pricing["foodStopFare"] ?? 0) is num
        ? pricing["foodStopFare"] as num
        : 0;

    final status = (ride["status"] ?? "pending") as String;
    final bool isPaid = (ride["isPaid"] ?? false) as bool;

    final createdAt = ride["createdAt"]?.toString();
    final confirmedAt = ride["confirmedAt"]?.toString();
    final startedAt = ride["startedAt"]?.toString();
    final completedAt = ride["completedAt"]?.toString();
    final paidAt = ride["paidAt"]?.toString();

    final paymentId = ride["paymentId"]?.toString();
    final orderId = ride["orderId"]?.toString();

    final driverName = driver["name"]?.toString() ?? "Driver (auto-assigned)";
    final driverVehicle = driver["vehicle"]?.toString() ?? "Vehicle TBD";
    final driverPlate = driver["plate"]?.toString() ?? "";
    final driverPhone = driver["phone"]?.toString();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text(
          "Ride Details",
          style: TextStyle(color: champagne),
        ),
        iconTheme: const IconThemeData(color: champagne),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Pickup & Drop Box ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: gold.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Pickup"),
                  Text(
                    pickup["label"]?.toString() ?? "Pickup",
                    style: const TextStyle(color: champagne, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  _sectionTitle("Drop"),
                  Text(
                    drop["label"]?.toString() ?? "Drop",
                    style: const TextStyle(color: champagne, fontSize: 15),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // --- Summary Box ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: gold.withOpacity(0.35)),
              ),
              child: Column(
                children: [
                  _row("Distance", "${distanceKm.toStringAsFixed(1)} km"),
                  _row("Estimated Time", "$etaMin minutes"),
                  _row("Food Stops", "$foodStops"),
                  _row("Suggestions", "$suggestionsCount"),
                  const Divider(color: Colors.white24, height: 22),
                  _row("Base Fare", "₹${baseFareNum.toStringAsFixed(0)}"),
                  _row("Distance Fare", "₹${distanceFareNum.toStringAsFixed(0)}"),
                  _row("Time Fare", "₹${timeFareNum.toStringAsFixed(0)}"),
                  _row("Food Stop Fare", "₹${foodFareNum.toStringAsFixed(0)}"),
                  const Divider(color: Colors.white24, height: 22),
                  _rowBold("Total Fare", "₹${totalFareNum.toStringAsFixed(0)}"),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // --- Status Badge ---
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _statusColor(status).withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.circle,
                      color: _statusColor(status), size: 14),
                  const SizedBox(width: 8),
                  Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  if (isPaid)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.5),
                        ),
                      ),
                      child: const Text(
                        "PAID",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // --- Timeline ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: gold.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Timeline"),
                  const SizedBox(height: 8),
                  _row("Created", _formatDate(createdAt ?? confirmedAt)),
                  _row("Confirmed", _formatDate(confirmedAt)),
                  _row("Started", _formatDate(startedAt)),
                  _row("Completed", _formatDate(completedAt)),
                  _row("Paid", _formatDate(paidAt)),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // --- Payment Info ---
            if (paymentId != null || orderId != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: gold.withOpacity(0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("Payment Details"),
                    const SizedBox(height: 8),
                    if (paymentId != null)
                      _row("Payment ID", paymentId),
                    if (orderId != null)
                      _row("Order ID", orderId),
                  ],
                ),
              ),

            const SizedBox(height: 18),

            // --- Driver details (from snapshot) ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: gold.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white12,
                    child: Icon(Icons.person, color: champagne, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driverName,
                          style: const TextStyle(
                            color: champagne,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "$driverVehicle${driverPlate.isNotEmpty ? " • $driverPlate" : ""}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        if (driverPhone != null &&
                            driverPhone.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            "📞 $driverPhone",
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 35),
          ],
        ),
      ),
    );
  }

  Widget _row(String a, String b) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            a,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              b,
              textAlign: TextAlign.right,
              style: const TextStyle(color: champagne, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowBold(String a, String b) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            a,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            b,
            style: const TextStyle(
              color: gold,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Text(
      t,
      style: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }
}
