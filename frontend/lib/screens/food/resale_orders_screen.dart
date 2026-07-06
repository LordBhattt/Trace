// lib/screens/food/resale_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../services/payment_service.dart';

class ResaleOrdersScreen extends StatefulWidget {
  const ResaleOrdersScreen({super.key});

  @override
  State<ResaleOrdersScreen> createState() => _ResaleOrdersScreenState();
}

class _ResaleOrdersScreenState extends State<ResaleOrdersScreen> {
  List<dynamic> resaleOrders = [];
  bool loading = true;
  
  // User location (hardcoded for now - should come from GPS)
  final double userLat = 18.5204;
  final double userLon = 73.8567;

  @override
  void initState() {
    super.initState();
    _loadResaleOrders();
  }

  Future<void> _loadResaleOrders() async {
    setState(() => loading = true);

    try {
      final res = await ApiService.getNearbyResaleOrders(
        lat: userLat,
        lon: userLon,
        radius: 5,
      );

      if (res['success'] == true) {
        setState(() {
          resaleOrders = res['orders'] ?? [];
        });
      }
    } catch (e) {
      print('Error loading resale orders: $e');
    }

    setState(() => loading = false);
  }

  Future<void> _claimOrder(String orderId) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFF4E4C1)),
        ),
      );

      // Claim the order
      final res = await ApiService.claimResaleOrder(orderId);

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (res['success'] != true) {
        _showError(res['message'] ?? 'Failed to claim order');
        return;
      }

      final paymentAmount = res['paymentAmount'];

      // Proceed to payment
      await _processPayment(orderId, paymentAmount);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      _showError('Error claiming order: $e');
    }
  }

  Future<void> _processPayment(String orderId, int amount) async {
    try {
      // Get Razorpay key
      final key = await ApiService.getRazorpayKey();
      if (key == null) {
        _showError('Failed to get payment key');
        return;
      }

      // Create payment order (backend calculates actual amount)
      final orderRes = await ApiService.createPaymentOrder(orderId);
      if (orderRes['success'] != true) {
        _showError('Failed to create payment order');
        return;
      }

      final razorpayOrderId = orderRes['orderId'];
      final int razorpayAmount =
          ((orderRes['amount'] ?? 0) as num).toInt(); // amount in paise

      // Open Razorpay using dedicated resale payment method
      final paymentRes = await PaymentService.openResaleCheckout(
        key: key,
        amount: razorpayAmount,
        orderId: razorpayOrderId,
      );

      if (paymentRes['success'] != true) {
        _showError(paymentRes['message'] ?? 'Payment failed');
        return;
      }

      // Verify payment
      final verifyRes = await ApiService.verifyPayment(
        paymentId: paymentRes['paymentId'],
        orderId: razorpayOrderId,
        signature: paymentRes['signature'],
        // For resale orders, backend is using orderId as rideId-equivalent
        rideId: orderId,
      );

      if (verifyRes['success'] == true) {
        _showSuccess();
      } else {
        _showError('Payment verification failed');
      }
    } catch (e) {
      _showError('Payment error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A3C),
        title: const Text(
          '🎉 Order Claimed!',
          style: TextStyle(color: Color(0xFFF4E4C1)),
        ),
        content: const Text(
          'Your order is confirmed and will be delivered soon!',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to home
            },
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFFD4AF37)),
            ),
          ),
        ],
      ),
    );
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
          '50% Off Deals 🔥',
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
          : resaleOrders.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadResaleOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: resaleOrders.length,
                    itemBuilder: (context, index) {
                      return _buildResaleCard(
                        resaleOrders[index] as Map<String, dynamic>,
                      );
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
            Icons.discount_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No deals available right now',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for 50% off deals',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResaleCard(Map<String, dynamic> order) {
    final restaurant = order['restaurantId'] ?? {};
    final restaurantName = restaurant['name'] ?? 'Unknown Restaurant';
    final coverImage = restaurant['coverImageUrl'] ?? '';
    
    final amounts = order['amounts'] ?? {};
    final originalPrice = ((amounts['finalPayableAmount'] ?? 0) as num).toInt();
    final resellPrice = ((order['resellPrice'] ?? 0) as num).toInt();
    final discount = originalPrice - resellPrice;
    
    final distance = (order['distance'] ?? 0).toDouble();
    final minutesLeft = order['minutesLeft'] ?? 0;
    
    final items = order['items'] as List? ?? [];
    final itemNames = items.map((item) => item['name']).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B6B).withOpacity(0.2),
            const Color(0xFFFF8E53).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with timer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '$minutesLeft min left',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '50% OFF',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Restaurant info
                Row(
                  children: [
                    if (coverImage.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: coverImage,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[800],
                            child: const Icon(Icons.restaurant),
                          ),
                        ),
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.white.withOpacity(0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${distance.toStringAsFixed(1)} km away',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Items
                Text(
                  'Items: $itemNames',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 16),

                // Pricing
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹$originalPrice',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 16,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '₹$resellPrice',
                              style: const TextStyle(
                                color: Color(0xFFD4AF37),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Save ₹$discount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Claim button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _claimOrder(order['_id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'CLAIM NOW',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
