// lib/screens/ride_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RideDetailScreen extends StatelessWidget {
  final Map<String, dynamic> ride;

  const RideDetailScreen({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    final pickup = ride['pickup'] ?? {};
    final drop = ride['drop'] ?? {};
    final pricing = ride['pricing'] ?? {};
    final driver = ride['driver'] ?? {};
    final status = ride['status'] ?? 'unknown';
    final isPaid = ride['isPaid'] ?? false;
    final distanceKm = ride['distanceKm'] ?? 0;
    final etaMin = ride['etaMin'] ?? 0;

    final createdAt = ride['createdAt'] ?? ride['confirmedAt'];
    final completedAt = ride['completedAt'];
    final paidAt = ride['paidAt'];

    String formatDate(dynamic dateStr) {
      if (dateStr == null) return 'N/A';
      try {
        final dt = DateTime.parse(dateStr);
        return DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
      } catch (_) {
        return 'N/A';
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C2C2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C2C2E),
        title: const Text('Ride Details', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFF4E4C1)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A1929), Color(0xFF162447)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Status: ${status.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if (isPaid)
                    const Icon(Icons.check_circle, color: Colors.green, size: 24),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Fare Breakdown
            _buildSection(
              'Fare Breakdown',
              Column(
                children: [
                  _buildRow('Base Fare', '₹${pricing['baseFare'] ?? 0}'),
                  _buildRow('Distance Fare', '₹${pricing['distanceFare'] ?? 0}'),
                  if ((pricing['timeFare'] ?? 0) > 0)
                    _buildRow('Time Fare', '₹${pricing['timeFare'] ?? 0}'),
                  if ((pricing['foodStopFare'] ?? 0) > 0)
                    _buildRow('Food Stop Fare', '₹${pricing['foodStopFare'] ?? 0}'),
                  const Divider(color: Colors.white24, height: 20),
                  _buildRow(
                    'Total Fare',
                    '₹${pricing['totalFare'] ?? 0}',
                    bold: true,
                    color: const Color(0xFFD4AF37),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Trip Details
            _buildSection(
              'Trip Details',
              Column(
                children: [
                  _buildRow('Distance', '${distanceKm.toStringAsFixed(1)} km'),
                  _buildRow('Estimated Time', '$etaMin min'),
                  _buildRow('Pickup', pickup['label'] ?? 'N/A'),
                  _buildRow('Drop', drop['label'] ?? 'N/A'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Driver Details
            if (driver['name'] != null)
              _buildSection(
                'Driver Details',
                Column(
                  children: [
                    _buildRow('Name', driver['name'] ?? 'N/A'),
                    if (driver['phone'] != null)
                      _buildRow('Phone', driver['phone'] ?? 'N/A'),
                    if (driver['vehicle'] != null)
                      _buildRow('Vehicle', driver['vehicle'] ?? 'N/A'),
                    if (driver['plate'] != null)
                      _buildRow('Plate', driver['plate'] ?? 'N/A'),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Timestamps
            _buildSection(
              'Timeline',
              Column(
                children: [
                  _buildRow('Booked At', formatDate(createdAt)),
                  if (completedAt != null)
                    _buildRow('Completed At', formatDate(completedAt)),
                  if (paidAt != null) _buildRow('Paid At', formatDate(paidAt)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Payment Info
            if (ride['paymentId'] != null)
              _buildSection(
                'Payment Info',
                Column(
                  children: [
                    _buildRow('Payment ID', ride['paymentId'] ?? 'N/A'),
                    _buildRow('Order ID', ride['orderId'] ?? 'N/A'),
                    _buildRow('Payment Mode', 'Razorpay'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1929), Color(0xFF162447)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}