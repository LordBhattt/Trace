// lib/screens/ride_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class RideSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> ride;

  const RideSummaryScreen({super.key, required this.ride});

  @override
  State<RideSummaryScreen> createState() => _RideSummaryScreenState();
}

class _RideSummaryScreenState extends State<RideSummaryScreen> {
  static const Color bg = Color(0xFF0C2C2E);
  static const Color card = Color(0xFF14242F);
  static const Color gold = Color(0xFFD4AF37);
  static const Color champagne = Color(0xFFF4E4C1);

  bool _generatingPDF = false;
  Map<String, dynamic>? _userStats;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    try {
      final stats = await ApiService.getUserStats();
      if (stats['success'] == true && mounted) {
        setState(() {
          _userStats = stats['stats'];
          _loadingStats = false;
        });
      }
    } catch (e) {
      print('Failed to load stats: $e');
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: champagne),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Ride Summary", style: TextStyle(color: champagne)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: champagne),
            onPressed: _shareInvoice,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _paymentSuccessCard(),
          const SizedBox(height: 20),
          _sectionTitle("Trip Details"),
          _tripDetails(),
          const SizedBox(height: 24),
          _sectionTitle("Fare Breakdown"),
          _fareCard(),
          const SizedBox(height: 24),
          _sectionTitle("Driver & Vehicle"),
          _driverCard(),
          const SizedBox(height: 24),
          _sectionTitle("Your Stats"),
          _loadingStats ? _loadingStatsCard() : _statsCard(),
          const SizedBox(height: 30),
          _actionButtons(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _paymentSuccessCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gold.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.greenAccent,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Payment Successful!",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "₹${_getTotalFare()}",
            style: const TextStyle(
              color: gold,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getPaymentId(),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: champagne,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _tripDetails() {
    final pickupLabel = widget.ride["pickup"]?["label"] ?? "Unknown pickup";
    final dropLabel = widget.ride["drop"]?["label"] ?? "Unknown drop";
    final distanceRaw = widget.ride["distanceKm"] ?? 0;
    final double distanceKm = (distanceRaw is num)
        ? distanceRaw.toDouble()
        : double.tryParse(distanceRaw.toString()) ?? 0.0;
    final eta = widget.ride["etaMin"]?.toString() ?? "—";
    final status = (widget.ride["status"] ?? "completed").toString();
    final rideId = (widget.ride["_id"] ?? widget.ride["id"] ?? "").toString();
    final createdAt = widget.ride["createdAt"] ?? widget.ride["confirmedAt"];
    final completedAt = widget.ride["completedAt"];

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rideId.isNotEmpty) ...[
            _detailRow("Ride ID:", rideId),
            const Divider(color: Colors.white24),
          ],
          _detailRow("From:", pickupLabel),
          const SizedBox(height: 6),
          _detailRow("To:", dropLabel),
          const Divider(color: Colors.white24),
          _detailRow("Distance:", "${distanceKm.toStringAsFixed(1)} km"),
          _detailRow("ETA:", "$eta min"),
          _detailRow("Status:", status),
          if (createdAt != null) ...[
            const Divider(color: Colors.white24),
            _detailRow("Booked at:", _formatDateTime(createdAt)),
          ],
          if (completedAt != null)
            _detailRow("Completed at:", _formatDateTime(completedAt)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: champagne,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fareCard() {
    final pricing = (widget.ride["pricing"] ?? {}) as Map<String, dynamic>;

    double numToDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    final double baseFare = numToDouble(pricing["baseFare"]);
    final double distanceFare = numToDouble(pricing["distanceFare"]);
    final double timeFare = numToDouble(pricing["timeFare"]);
    final double foodStopFare = numToDouble(pricing["foodStopFare"]);
    final double total = numToDouble(pricing["totalFare"]);
    final int foodStops =
        foodStopFare > 0 ? (foodStopFare / 15.0).round() : 0;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _detailRow("Base Fare:", "₹${baseFare.round()}"),
          _detailRow("Distance Fare:", "₹${distanceFare.round()}"),
          if (timeFare > 0) _detailRow("Time Fare:", "₹${timeFare.round()}"),
          _detailRow(
            "Food Stops${foodStops > 0 ? " ($foodStops)" : ""}:",
            "₹${foodStopFare.round()}",
          ),
          const Divider(color: Colors.white24),
          _detailRow(
            "Total Fare:",
            "₹${total.round()}",
          ),
        ],
      ),
    );
  }

  Widget _driverCard() {
    final driver = widget.ride["driver"] ?? {};
    final driverName = driver["name"] ?? "Rajesh Kumar";
    final vehicle = driver["vehicle"] ?? "Toyota Camry";
    final plate = driver["plate"] ?? "MH 02 AB 1234";

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white12,
                backgroundImage:
                    const NetworkImage('https://i.pravatar.cc/150?img=12'),
                onBackgroundImageError: (_, __) {},
                child: const Icon(Icons.person, color: champagne, size: 34),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: const TextStyle(color: champagne, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Icon(Icons.star, color: gold, size: 18),
                        SizedBox(width: 4),
                        Text("4.8", style: TextStyle(color: champagne)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const Icon(Icons.directions_car, color: champagne, size: 28),
              Text(
                "$vehicle\n$plate",
                textAlign: TextAlign.center,
                style: const TextStyle(color: champagne),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _loadingStatsCard() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withOpacity(0.3)),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: gold),
      ),
    );
  }

  Widget _statsCard() {
    if (_userStats == null) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: gold.withOpacity(0.3)),
        ),
        child: const Center(
          child: Text(
            "Unable to load stats",
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final totalRides = _userStats!['totalRides'] ?? 0;
    final totalSpent = _userStats!['totalSpent'] ?? 0;
    final totalDistance = _userStats!['totalDistance'] ?? 0.0;
    final avgFare = totalRides > 0 ? (totalSpent / totalRides) : 0;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [card, const Color(0xFF1A2F3F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem(Icons.directions_car, "Total Rides", "$totalRides"),
              _statItem(Icons.currency_rupee, "Total Spent", "₹$totalSpent"),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem(Icons.route, "Total Distance",
                  "${totalDistance.toStringAsFixed(1)} km"),
              _statItem(Icons.trending_down, "Avg Fare",
                  "₹${avgFare.round()}"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: gold, size: 32),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: champagne,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _actionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _generatingPDF ? null : _generateInvoice,
            icon: _generatingPDF
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf),
            label: Text(_generatingPDF ? "Generating..." : "Download Invoice"),
            style: ElevatedButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: bg,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.home),
            label: const Text("Back to Home"),
            style: OutlinedButton.styleFrom(
              foregroundColor: champagne,
              side: BorderSide(color: gold.withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===== PDF GENERATION =====
  Future<void> _generateInvoice() async {
    setState(() => _generatingPDF = true);

    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final invoiceNumber = "TRACE-${widget.ride["_id"]?.toString().substring(0, 8) ?? "UNKNOWN"}";

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "TRACE",
                      style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "INVOICE",
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(invoiceNumber),
                        pw.Text(DateFormat('dd MMM yyyy').format(now)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Divider(),
                pw.SizedBox(height: 20),

                // Trip Details
                pw.Text(
                  "Trip Details",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                _pdfDetailRow("Ride ID:", _getRideId()),
                _pdfDetailRow("From:", _getPickupLabel()),
                _pdfDetailRow("To:", _getDropLabel()),
                _pdfDetailRow("Distance:", _getDistance()),
                _pdfDetailRow("Status:", _getStatus()),
                _pdfDetailRow("Date:", _getCreatedDate()),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 20),

                // Fare Breakdown
                pw.Text(
                  "Fare Breakdown",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                _pdfDetailRow("Base Fare:", "₹${_getBaseFare()}"),
                _pdfDetailRow("Distance Fare:", "₹${_getDistanceFare()}"),
                if (_getTimeFare() > 0)
                  _pdfDetailRow("Time Fare:", "₹${_getTimeFare()}"),
                if (_getFoodStopFare() > 0)
                  _pdfDetailRow("Food Stops:", "₹${_getFoodStopFare()}"),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Total Fare:",
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "₹${_getTotalFare()}",
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Divider(),
                pw.SizedBox(height: 20),

                // Payment Details
                pw.Text(
                  "Payment Details",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                _pdfDetailRow("Payment ID:", _getPaymentId()),
                _pdfDetailRow("Payment Mode:", "Razorpay"),
                _pdfDetailRow("Payment Status:", "Success"),
                pw.Spacer(),

                // Footer
                pw.Center(
                  child: pw.Text(
                    "Thank you for riding with TRACE!",
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'TRACE_Invoice_$invoiceNumber.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPDF = false);
    }
  }

  pw.Widget _pdfDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(
            value,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _shareInvoice() async {
    await _generateInvoice();
  }

  // Helper methods
  String _getRideId() =>
      (widget.ride["_id"] ?? widget.ride["id"] ?? "N/A").toString();
  String _getPickupLabel() =>
      widget.ride["pickup"]?["label"] ?? "Unknown pickup";
  String _getDropLabel() => widget.ride["drop"]?["label"] ?? "Unknown drop";
  String _getDistance() {
    final distanceRaw = widget.ride["distanceKm"] ?? 0;
    final double distanceKm = (distanceRaw is num)
        ? distanceRaw.toDouble()
        : double.tryParse(distanceRaw.toString()) ?? 0.0;
    return "${distanceKm.toStringAsFixed(1)} km";
  }

  String _getStatus() =>
      (widget.ride["status"] ?? "completed").toString().toUpperCase();
  String _getCreatedDate() {
    final createdAt = widget.ride["createdAt"] ?? widget.ride["confirmedAt"];
    if (createdAt == null) return "N/A";
    return _formatDateTime(createdAt);
  }

  String _formatDateTime(dynamic date) {
    try {
      DateTime dt = date is DateTime ? date : DateTime.parse(date.toString());
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return "N/A";
    }
  }

  int _getBaseFare() {
    final pricing = widget.ride["pricing"] ?? {};
    return _toInt(pricing["baseFare"]);
  }

  int _getDistanceFare() {
    final pricing = widget.ride["pricing"] ?? {};
    return _toInt(pricing["distanceFare"]);
  }

  int _getTimeFare() {
    final pricing = widget.ride["pricing"] ?? {};
    return _toInt(pricing["timeFare"]);
  }

  int _getFoodStopFare() {
    final pricing = widget.ride["pricing"] ?? {};
    return _toInt(pricing["foodStopFare"]);
  }

  int _getTotalFare() {
    final pricing = widget.ride["pricing"] ?? {};
    return _toInt(pricing["totalFare"]);
  }

  String _getPaymentId() {
    return widget.ride["paymentId"]?.toString() ?? "N/A";
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }
}