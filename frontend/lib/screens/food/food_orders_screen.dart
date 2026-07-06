import 'package:flutter/material.dart';
import '../../services/food_api_service.dart';
import 'order_tracking_screen.dart';

class FoodOrdersScreen extends StatefulWidget {
  const FoodOrdersScreen({super.key});

  @override
  State<FoodOrdersScreen> createState() => _FoodOrdersScreenState();
}

class _FoodOrdersScreenState extends State<FoodOrdersScreen> {
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
      final fetchedOrders = await FoodApiService.getOrderHistory();
      setState(() {
        orders = fetchedOrders;
      });
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
        return 'On the Way';
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
      case 'preparing':
      case 'ready_for_pickup':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hr ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
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
      return 'You saved ₹$saved with TRACE Saver (Shared Cab)';
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
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
            )
          : orders.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index] as Map<String, dynamic>;
                      return _buildOrderCard(order);
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
    final status = order['status'] ?? 'placed';
    final items = order['items'] as List? ?? [];
    final amounts = (order['amounts'] ?? {}) as Map<String, dynamic>;

    final numFinal =
        (amounts['finalPayableAmount'] is num) ? amounts['finalPayableAmount'] as num : 0;
    final amount = numFinal.toInt();

    final createdAt = DateTime.tryParse(order['createdAt'] ?? '') ??
        DateTime.now();
    final isActive =
        !['delivered', 'cancelled'].contains(status.toString());

    final deliveryMode =
        (order['deliveryMode'] ?? 'dedicated_delivery').toString();
    final savings = _savingsText(amounts, deliveryMode);
    final paymentText = _paymentMethodText(amounts);

    return GestureDetector(
      onTap: () {
        // Always allow opening tracking to view timeline / status
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                OrderTrackingScreen(orderId: order['_id'] as String),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3A3C),
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(
                  color: const Color(0xFFD4AF37),
                  width: 2,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Restaurant + status
            Row(
              children: [
                Expanded(
                  child: Text(
                    restaurant['name']?.toString() ?? 'Restaurant',
                    style: const TextStyle(
                      color: Color(0xFFF4E4C1),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status.toString()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(status.toString()),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Items count
            Text(
              '${items.length} ${items.length == 1 ? 'item' : 'items'}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 8),

            // Date + total amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(createdAt),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
                Text(
                  '₹$amount',
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Delivery mode + payment method
            Row(
              children: [
                Icon(
                  deliveryMode == 'detour_cab'
                      ? Icons.local_taxi
                      : Icons.delivery_dining,
                  size: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  _deliveryModeText(deliveryMode),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
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
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
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

            if (isActive) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.touch_app,
                    color: Color(0xFFD4AF37),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tap to track order',
                    style: TextStyle(
                      color:
                          const Color(0xFFD4AF37).withOpacity(0.8),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
