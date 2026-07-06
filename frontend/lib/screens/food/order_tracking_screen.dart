// lib/screens/food/order_tracking_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../services/food_api_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Map<String, dynamic>? order;
  Timer? _timer;
  bool loading = true;
  final MapController _mapController = MapController();

  // Simulated driver position (in production, this comes from backend)
  LatLng? _driverPosition;
  LatLng? _restaurantPosition;
  LatLng? _deliveryPosition;

  final List<Map<String, dynamic>> orderSteps = const [
    {'status': 'placed', 'label': 'Order Placed', 'icon': Icons.receipt_long},
    {'status': 'accepted', 'label': 'Accepted by Restaurant', 'icon': Icons.check_circle},
    {'status': 'preparing', 'label': 'Food is Being Prepared', 'icon': Icons.restaurant_menu},
    {'status': 'ready_for_pickup', 'label': 'Ready for Pickup', 'icon': Icons.shopping_bag},
    {'status': 'picked_up', 'label': 'Picked Up', 'icon': Icons.delivery_dining},
    {'status': 'on_the_way', 'label': 'On the Way', 'icon': Icons.local_shipping},
    {'status': 'delivered', 'label': 'Delivered', 'icon': Icons.done_all},
  ];

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (order != null && !['delivered', 'cancelled'].contains(order!['status'])) {
        _loadOrder();
        _simulateDriverMovement();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _loadOrder() async {
    try {
      final fetchedOrder = await FoodApiService.getOrderDetails(widget.orderId);
      setState(() {
        order = fetchedOrder['order'];
        loading = false;
        
        // Extract positions
        if (order != null) {
          final restaurant = order!['restaurantId'];
          if (restaurant is Map && restaurant['location'] != null) {
            _restaurantPosition = LatLng(
              (restaurant['location']['lat'] as num).toDouble(),
              (restaurant['location']['lon'] as num).toDouble(),
            );
          }
          
          final deliveryLoc = order!['locationDelivery'];
          if (deliveryLoc != null) {
            _deliveryPosition = LatLng(
              (deliveryLoc['lat'] as num).toDouble(),
              (deliveryLoc['lon'] as num).toDouble(),
            );
          }

          // Initialize driver position
          if (_driverPosition == null && _restaurantPosition != null) {
            _driverPosition = _restaurantPosition;
          }
        }
      });
    } catch (e) {
      print('Error loading order: $e');
      setState(() => loading = false);
    }
  }

  void _simulateDriverMovement() {
    if (_driverPosition == null || _deliveryPosition == null) return;
    
    final status = order?['status'];
    if (status == 'picked_up' || status == 'on_the_way') {
      // Move driver 10% closer to delivery location
      final latDiff = _deliveryPosition!.latitude - _driverPosition!.latitude;
      final lonDiff = _deliveryPosition!.longitude - _driverPosition!.longitude;
      
      setState(() {
        _driverPosition = LatLng(
          _driverPosition!.latitude + (latDiff * 0.1),
          _driverPosition!.longitude + (lonDiff * 0.1),
        );
      });

      // Center map on driver
      _mapController.move(_driverPosition!, 14.0);
    }
  }

  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A3C),
        title: const Text('Cancel Order?', style: TextStyle(color: Color(0xFFF4E4C1))),
        content: const Text(
          'Are you sure you want to cancel this order?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FoodApiService.cancelOrder(widget.orderId, 'User cancelled');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled successfully'), backgroundColor: Colors.orange),
      );
      _loadOrder();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _generateReceipt() async {
    if (order == null) return;

    final pdf = pw.Document();
    final restaurant = order!['restaurantId'] ?? {};
    final amounts = order!['amounts'];
    final items = order!['items'] as List;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('TRACE Food Receipt', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 10),
            
            // Restaurant Info
            pw.Text('Restaurant: ${restaurant['name'] ?? 'N/A'}', style: const pw.TextStyle(fontSize: 14)),
            pw.Text('Order ID: ${widget.orderId}', style: const pw.TextStyle(fontSize: 12)),
            pw.Text('Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(order!['createdAt']))}', 
                    style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 20),

            // Items
            pw.Text('Order Items:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            ...items.map((item) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('${item['quantity']}x ${item['name']}'),
                pw.Text('₹${(item['itemTotal'] as num).toStringAsFixed(0)}'),
              ],
            )),
            
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 10),

            // Bill Details
            pw.Text('Bill Details:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _pdfBillRow('Items Total', amounts['itemsTotal']),
            _pdfBillRow('Platform Fee', amounts['platformFee']),
            _pdfBillRow('Delivery Fee', amounts['deliveryFee']),
            _pdfBillRow('GST', amounts['gstAmount']),
            if ((amounts['discounts'] as num) > 0)
              _pdfBillRow('Discount', -amounts['discounts']),
            pw.Divider(),
            _pdfBillRow('Total Paid', amounts['finalPayableAmount'], isBold: true),

            pw.SizedBox(height: 30),
            pw.Text('Payment Status: ${order!['isPaid'] ? 'PAID' : 'PENDING'}', 
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            if (order!['razorpayPaymentId'] != null)
              pw.Text('Payment ID: ${order!['razorpayPaymentId']}', style: const pw.TextStyle(fontSize: 10)),

            pw.Spacer(),
            pw.Center(child: pw.Text('Thank you for using TRACE!', style: const pw.TextStyle(fontSize: 12))),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _pdfBillRow(String label, dynamic amount, {bool isBold = false}) {
    final numAmount = (amount as num).toDouble();
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text('₹${numAmount.abs().toStringAsFixed(0)}', 
                style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    );
  }

  int _getCurrentStepIndex() {
    if (order == null) return 0;
    final status = order!['status'];
    final idx = orderSteps.indexWhere((step) => step['status'] == status);
    return idx == -1 ? 0 : idx;
  }

  bool _canCancelOrder() {
    if (order == null) return false;
    final status = order!['status'];
    return ['placed', 'accepted'].contains(status);
  }

  int _calculateETA() {
    final status = order?['status'];
    if (status == 'delivered' || status == 'cancelled') return 0;
    if (status == 'preparing' || status == 'ready_for_pickup') return 20;
    if (status == 'picked_up' || status == 'on_the_way') return 10;
    return 30;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0C2C2E),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
      );
    }

    if (order == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0C2C2E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0C2C2E),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFFF4E4C1)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text('Order not found', style: TextStyle(color: Colors.white))),
      );
    }

    final restaurant = order!['restaurantId'] ?? {};
    final status = order!['status'] ?? 'placed';
    final isCancelled = status == 'cancelled';
    final isDelivered = status == 'delivered';
    final currentStepIndex = _getCurrentStepIndex();

    return Scaffold(
      backgroundColor: const Color(0xFF0C2C2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C2C2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF4E4C1)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Track Order', style: TextStyle(color: Color(0xFFF4E4C1), fontWeight: FontWeight.bold)),
        actions: [
          if (isDelivered)
            IconButton(
              icon: const Icon(Icons.receipt_long, color: Color(0xFFD4AF37)),
              onPressed: _generateReceipt,
              tooltip: 'Download Receipt',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Live Map (if order is active)
                  if (!isCancelled && !isDelivered && _restaurantPosition != null && _deliveryPosition != null)
                    _buildLiveMap(),

                  // Restaurant Info
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A3A3C),
                      border: Border(bottom: BorderSide(color: Colors.white10, width: 1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.restaurant, color: Color(0xFFD4AF37), size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                restaurant['name'] ?? 'Restaurant',
                                style: const TextStyle(color: Color(0xFFF4E4C1), fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Order #${widget.orderId.substring(widget.orderId.length - 6)}',
                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ETA Card
                  if (!isCancelled && !isDelivered) _buildEtaCard(status),

                  const SizedBox(height: 16),

                  // Status Display
                  if (isCancelled)
                    _buildCancelledStatus()
                  else if (isDelivered)
                    _buildDeliveredStatus()
                  else
                    _buildActiveStatus(currentStepIndex),

                  const SizedBox(height: 24),

                  // Delivery Mode Indicator
                  if (order!['deliveryMode'] == 'detour_cab')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD4AF37)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_taxi, color: Color(0xFFD4AF37)),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Shared Delivery Mode',
                                    style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Your food is being delivered by a cab driver along their route',
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('SAVE 50%', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Order Items
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Order Items', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ...((order!['items'] as List?) ?? []).map((item) {
                          final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                          final total = (item['itemTotal'] as num?)?.toDouble() ?? 0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A3A3C),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Text('${qty}x', style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
                                const SizedBox(width: 12),
                                Expanded(child: Text(item['name']?.toString() ?? '', style: const TextStyle(color: Color(0xFFF4E4C1)))),
                                Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bill Details
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3A3C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bill Details', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _buildBillRow('Items Total', order!['amounts']['itemsTotal']),
                          _buildBillRow('Platform Fee', order!['amounts']['platformFee']),
                          _buildBillRow('Delivery Fee', order!['amounts']['deliveryFee']),
                          if ((order!['amounts']['discounts'] as num) > 0)
                            _buildBillRow('Discount', -order!['amounts']['discounts'], color: Colors.green),
                          _buildBillRow('GST', order!['amounts']['gstAmount']),
                          const Divider(color: Colors.white24, height: 24),
                          _buildBillRow('Total Payable', order!['amounts']['finalPayableAmount'], isBold: true),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1A3A3C),
              border: Border(top: BorderSide(color: Colors.white10, width: 1)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  if (isDelivered)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _generateReceipt,
                        icon: const Icon(Icons.download),
                        label: const Text('Download Receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  if (_canCancelOrder()) ...[
                    if (isDelivered) const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _cancelOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMap() {
    return Container(
      height: 300,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4AF37)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _driverPosition ?? _restaurantPosition!,
            initialZoom: 14.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.smartshare_app',
            ),
            MarkerLayer(
              markers: [
                // Restaurant
                if (_restaurantPosition != null)
                  Marker(
                    point: _restaurantPosition!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.restaurant, color: Colors.orange, size: 40),
                  ),
                // Delivery location
                if (_deliveryPosition != null)
                  Marker(
                    point: _deliveryPosition!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                  ),
                // Driver
                if (_driverPosition != null)
                  Marker(
                    point: _driverPosition!,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFD4AF37),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delivery_dining, color: Colors.black, size: 30),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEtaCard(String status) {
    final eta = _calculateETA();
    final riderName = order?['driver']?['name'] ?? order?['riderName'] ?? 'Your delivery partner';

    String statusText;
    IconData icon;
    if (status == 'preparing') {
      statusText = 'Your food is being prepared';
      icon = Icons.restaurant_menu;
    } else if (status == 'ready_for_pickup') {
      statusText = 'Food is ready for pickup';
      icon = Icons.shopping_bag;
    } else if (status == 'picked_up' || status == 'on_the_way') {
      statusText = '$riderName is on the way';
      icon = Icons.delivery_dining;
    } else if (status == 'accepted') {
      statusText = 'Restaurant accepted your order';
      icon = Icons.check_circle;
    } else {
      statusText = 'Processing your order';
      icon = Icons.timelapse;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFD4AF37).withOpacity(0.2), const Color(0xFF1A3A3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4AF37), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFD4AF37)),
            child: Icon(icon, color: Colors.black, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusText, style: const TextStyle(color: Color(0xFFF4E4C1), fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Color(0xFFD4AF37), size: 16),
                    const SizedBox(width: 6),
                    Text('Arriving in $eta min', style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveStatus(int currentStepIndex) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: List.generate(orderSteps.length, (index) {
          final step = orderSteps[index];
          final isCompleted = index <= currentStepIndex;
          final isCurrent = index == currentStepIndex;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCompleted ? const Color(0xFFD4AF37) : Colors.grey.shade800,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(step['icon'] as IconData, color: isCompleted ? Colors.black : Colors.white54, size: 20),
                  ),
                  if (index < orderSteps.length - 1)
                    Container(
                      width: 2,
                      height: 40,
                      color: isCompleted ? const Color(0xFFD4AF37) : Colors.grey.shade800,
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step['label'] as String,
                      style: TextStyle(
                        color: isCompleted ? const Color(0xFFF4E4C1) : Colors.white54,
                        fontSize: 16,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFD4AF37).withOpacity(0.7)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('In progress...', style: TextStyle(color: const Color(0xFFD4AF37).withOpacity(0.7), fontSize: 12, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCancelledStatus() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel, color: Colors.red, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order Cancelled', style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(order!['cancellationReason']?.toString() ?? 'Order was cancelled', style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveredStatus() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 32),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order Delivered', style: TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Thank you for ordering with TRACE!', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, dynamic amount, {bool isBold = false, Color? color}) {
    final numAmount = (amount as num?) ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color ?? Colors.white70, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text('₹${numAmount.abs().toStringAsFixed(0)}', style: TextStyle(color: color ?? const Color(0xFFF4E4C1), fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}