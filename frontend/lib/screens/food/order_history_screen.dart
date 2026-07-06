import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import 'order_tracking_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<dynamic> orders = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => loading = true);

    try {
      final res = await ApiService.getFoodOrderHistory();

      if (res['success'] == true) {
        setState(() {
          orders = res['orders'] ?? [];
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error loading orders: $e');
    }

    setState(() => loading = false);
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'placed':
        return 'Order Placed';
      case 'accepted':
        return 'Accepted';
      case 'preparing':
        return 'Preparing';
      case 'ready_for_pickup':
        return 'Ready for Pickup';
      case 'picked_up':
        return 'Picked Up';
      case 'on_the_way':
        return 'On The Way';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'on_the_way':
      case 'picked_up':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  String _deliveryModeText(String mode) {
    if (mode == 'detour_cab') {
      return 'Shared Cab Delivery';
    }
    return 'Standard Delivery';
  }

  String? _savingsText(Map<String, dynamic> amounts, String deliveryMode) {
    final numDiscount =
        (amounts['discounts'] is num) ? amounts['discounts'] as num : 0;
    if (numDiscount <= 0) return null;

    final saved = numDiscount.toInt();

    if (deliveryMode == 'detour_cab') {
      return 'You saved ₹$saved with TRACE Saver';
    } else {
      return 'You could have saved ₹$saved with TRACE Saver';
    }
  }

  String _paymentMethodText(Map<String, dynamic> amounts) {
    final mode = (amounts['paymentMode'] ??
            amounts['payment_method'] ??
            amounts['paymentMethod'] ??
            'online')
        .toString();

    if (mode == 'cod') {
      return 'Cash on Delivery';
    }
    return 'Paid Online';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C2C2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C2C2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF4E4C1)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Food Orders',
          style: TextStyle(
            color: Color(0xFFF4E4C1),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF4E4C1)),
            )
          : orders.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      return _buildOrderCard(
                          orders[index] as Map<String, dynamic>);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No orders yet',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your food orders will appear here',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final restaurant = order['restaurantId'] ?? {};
    final restaurantName = restaurant['name']?.toString() ?? 'Unknown Restaurant';
    final coverImage = restaurant['coverImageUrl']?.toString() ?? '';

    final amounts = (order['amounts'] ?? {}) as Map<String, dynamic>;
    final numFinal =
        (amounts['finalPayableAmount'] is num) ? amounts['finalPayableAmount'] as num : 0;
    final total = numFinal.toInt();

    final status = (order['status'] ?? 'placed').toString();
    final deliveryMode =
        (order['deliveryMode'] ?? 'dedicated_delivery').toString();

    final items = order['items'] as List? ?? [];
    final itemCount = items.length;

    final createdAt = order['createdAt'] != null
        ? DateTime.parse(order['createdAt'].toString())
        : DateTime.now();
    final dateStr =
        DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt);

    final savings = _savingsText(amounts, deliveryMode);
    final paymentText = _paymentMethodText(amounts);

    final bool isActive =
        !['delivered', 'cancelled'].contains(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A3C),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Restaurant header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (coverImage.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: coverImage,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[800],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[800],
                        child: const Icon(Icons.restaurant, size: 24),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.restaurant, size: 24),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurantName,
                        style: const TextStyle(
                          color: Color(0xFFF4E4C1),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF0C2C2E), height: 1),

          // Order details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date + total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '₹$total',
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Delivery mode + payment
                Row(
                  children: [
                    Icon(
                      deliveryMode == 'detour_cab'
                          ? Icons.local_taxi
                          : Icons.delivery_dining,
                      size: 16,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _deliveryModeText(deliveryMode),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.payments,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      paymentText,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

                if (savings != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.savings,
                        size: 16,
                        color: Color(0xFFD4AF37),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          savings,
                          style: const TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Action buttons (Track / View details)
          if (isActive)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingScreen(
                          orderId: order['_id'].toString(),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Track Order',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
