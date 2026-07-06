// lib/screens/food/cart_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../services/food_api_service.dart';
import '../../services/payment_service.dart';
import 'order_tracking_screen.dart';

class CartScreen extends StatefulWidget {
  final Map<String, dynamic> restaurant;
  final List<Map<String, dynamic>> cartItems;
  final Map<String, dynamic>? resellDeal;
  final Map<String, dynamic>? deliveryAddress;

  const CartScreen({
    super.key,
    required this.restaurant,
    required this.cartItems,
    this.resellDeal,
    this.deliveryAddress,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _creatingOrder = false;
  bool _loadingPrice = true;
  String? _errorMessage;

  String deliveryMode = "dedicated_delivery";
  String paymentMode = "online";

  Map<String, dynamic>? priceData;

  static const String RAZORPAY_KEY = "rzp_test_RgUC6UWgg7Oqd7";

  @override
  void initState() {
    super.initState();
    
    if (widget.deliveryAddress == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Please select delivery address first'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      });
      return;
    }
    
    _fetchPrice();
  }

  Map<String, dynamic> get deliveryLocation {
    return {
      "lat": widget.deliveryAddress!['lat'],
      "lon": widget.deliveryAddress!['lon'],
      "address": widget.deliveryAddress!['display_name'] ?? 'Delivery Location'
    };
  }

  Future<void> _fetchPrice() async {
    setState(() {
      _loadingPrice = true;
      _errorMessage = null;
    });

    try {
      print("🔍 Fetching price...");
      print("📦 Items: ${widget.cartItems.length}");
      print("📍 Location: ${deliveryLocation['address']}");
      
      final result = await FoodApiService.getPricePreview(
        restaurantId: widget.restaurant["_id"] ?? '',
        items: widget.cartItems,
        deliveryLocation: deliveryLocation,
        preferredMode: deliveryMode,
      );

      print("✅ Price data received");

      if (mounted) {
        setState(() {
          priceData = result;
          _loadingPrice = false;
        });
      }
    } catch (e) {
      print("❌ Price fetch error: $e");
      
      if (mounted) {
        setState(() {
          _loadingPrice = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  double get calculatedTotal {
    return widget.cartItems.fold(0.0, (sum, item) {
      final price = (item['price'] ?? 0) as num;
      final quantity = (item['quantity'] ?? 1) as num;
      return sum + (price * quantity).toDouble();
    });
  }

  Future<void> _proceedToCheckout() async {
    print("🛒 Checkout initiated");
    _showDeliveryModeSelection();
  }

  void _showDeliveryModeSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A3A3C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Delivery Mode',
              style: TextStyle(
                color: Color(0xFFF4E4C1),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'TRACE Exclusive Feature',
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            _deliveryModeTile(
              icon: Icons.delivery_dining,
              title: 'Dedicated Delivery',
              subtitle: 'Fast delivery, standard charges',
              badge: 'FASTEST',
              badgeColor: Colors.green,
              mode: 'dedicated_delivery',
            ),
            const SizedBox(height: 12),
            _deliveryModeTile(
              icon: Icons.local_taxi,
              title: 'Shared with Cab Ride',
              subtitle: 'Save money, delivered by cab driver',
              badge: 'SAVE 50%',
              badgeColor: const Color(0xFFD4AF37),
              mode: 'detour_cab',
            ),
          ],
        ),
      ),
    ).then((_) {
      if (deliveryMode.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _showPaymentOptions();
        });
      }
    });
  }

  Widget _deliveryModeTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required String mode,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        setState(() => deliveryMode = mode);
        _fetchPrice();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0C2C2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: deliveryMode == mode
                ? const Color(0xFFD4AF37)
                : const Color(0xFFD4AF37).withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFD4AF37), size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFFF4E4C1),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A3A3C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Payment Method',
              style: TextStyle(
                color: Color(0xFFF4E4C1),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _paymentOptionTile(
              icon: Icons.payment,
              title: 'Online Payment',
              subtitle: 'Pay via UPI, Cards, Wallet',
              onTap: () {
                Navigator.pop(context);
                _initiateOnlinePayment();
              },
            ),
            const SizedBox(height: 12),
            _paymentOptionTile(
              icon: Icons.money,
              title: 'Cash on Delivery',
              subtitle: 'Pay when order arrives',
              onTap: () {
                Navigator.pop(context);
                _createCODOrder();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0C2C2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFD4AF37)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFF4E4C1),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFFD4AF37),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initiateOnlinePayment() async {
    if (_creatingOrder) return;
    
    setState(() => _creatingOrder = true);

    try {
      print('💳 Step 1: Getting final amount...');
      
      final amounts = priceData?["amounts"] as Map<String, dynamic>?;
      final finalAmount = amounts != null 
          ? ((amounts["finalPayableAmount"] ?? calculatedTotal) as num).toDouble()
          : calculatedTotal;

      if (finalAmount <= 0) {
        throw Exception("Invalid payment amount: ₹$finalAmount");
      }

      print('💰 Final amount: ₹$finalAmount');
      print('📝 Step 2: Creating order on backend...');

      final orderAmounts = _buildOrderAmounts(finalAmount, "online");
      
      final createOrderResponse = await FoodApiService.createFoodOrder(
        restaurantId: widget.restaurant["_id"]?.toString() ?? '',
        items: widget.cartItems,
        deliveryLocation: deliveryLocation,
        deliveryMode: deliveryMode,
        amounts: orderAmounts,
      );

      if (!mounted) return;

      final orderId = createOrderResponse["order"]?["_id"]?.toString() ?? '';

      if (orderId.isEmpty) {
        throw Exception("Order ID not received from backend");
      }

      print('✅ Order created: $orderId');
      print('💳 Step 3: Creating Razorpay order...');

      // Add a small delay to ensure backend has processed the order
      await Future.delayed(const Duration(milliseconds: 500));

      final razorpayResponse = await FoodApiService.createRazorpayOrderForFood(
        orderId: orderId,
        amount: finalAmount,
      );

      final razorpayOrderId = razorpayResponse["razorpayOrderId"]?.toString() ?? '';

      if (razorpayOrderId.isEmpty) {
        throw Exception("Razorpay order ID not received");
      }

      print('✅ Razorpay Order ID: $razorpayOrderId');
      print('🚀 Step 4: Opening Razorpay checkout...');

      if (!mounted) return;

      final paymentResult = await PaymentService.openCheckout(
        key: RAZORPAY_KEY,
        amount: (finalAmount * 100).toInt(),
        orderId: razorpayOrderId,
        name: 'TRACE Food Order',
        description: 'Order from ${widget.restaurant["name"] ?? "Restaurant"}',
      );

      if (!mounted) return;

      print('📲 Payment result: $paymentResult');

      if (paymentResult['success'] == true) {
        print('✅ Payment successful!');
        print('🔐 Step 5: Verifying payment...');
        
        try {
          await FoodApiService.verifyFoodPayment(
            orderId: orderId,
            razorpayPaymentId: paymentResult['paymentId'] ?? '',
            razorpaySignature: paymentResult['signature'] ?? '',
          );
          print('✅ Payment verified!');
        } catch (e) {
          print("⚠️ Payment verification warning: $e");
          // Continue anyway - payment was successful
        }

        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Order placed successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: orderId),
          ),
        );
      } else {
        throw Exception(paymentResult['message'] ?? 'Payment cancelled or failed');
      }
    } catch (e) {
      print("❌ Payment error: $e");
      if (mounted) {
        _showError(_parseErrorMessage(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _creatingOrder = false);
    }
  }

  Future<void> _createCODOrder() async {
    if (_creatingOrder) return;
    
    setState(() => _creatingOrder = true);

    try {
      print('💵 Creating COD order...');
      
      final amounts = priceData?["amounts"] as Map<String, dynamic>?;
      final finalAmount = amounts != null 
          ? ((amounts["finalPayableAmount"] ?? calculatedTotal) as num).toDouble()
          : calculatedTotal;

      final orderAmounts = _buildOrderAmounts(finalAmount, "cod");

      final createOrderResponse = await FoodApiService.createFoodOrder(
        restaurantId: widget.restaurant["_id"]?.toString() ?? '',
        items: widget.cartItems,
        deliveryLocation: deliveryLocation,
        deliveryMode: deliveryMode,
        amounts: orderAmounts,
      );

      if (!mounted) return;

      final orderId = createOrderResponse["order"]?["_id"]?.toString() ?? '';

      if (orderId.isEmpty) {
        throw Exception("Order ID not received");
      }

      print('✅ COD Order created: $orderId');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Order placed successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: orderId),
        ),
      );
    } catch (e) {
      print("❌ COD error: $e");
      if (mounted) _showError(_parseErrorMessage(e.toString()));
    } finally {
      if (mounted) setState(() => _creatingOrder = false);
    }
  }

  Map<String, dynamic> _buildOrderAmounts(double finalAmount, String mode) {
    final amounts = priceData?["amounts"] as Map<String, dynamic>?;
    
    if (amounts != null) {
      return {
        "itemsTotal": ((amounts["itemsTotal"] ?? calculatedTotal) as num).toDouble(),
        "deliveryFee": ((amounts["deliveryFee"] ?? 0) as num).toDouble(),
        "platformFee": ((amounts["platformFee"] ?? 0) as num).toDouble(),
        "gstAmount": ((amounts["gstAmount"] ?? 0) as num).toDouble(),
        "discounts": ((amounts["discounts"] ?? 0) as num).toDouble(),
        "distanceFee": ((amounts["distanceFee"] ?? 0) as num).toDouble(),
        "finalPayableAmount": finalAmount,
        "paymentMode": mode,
      };
    } else {
      return {
        "itemsTotal": calculatedTotal,
        "deliveryFee": 0.0,
        "platformFee": 0.0,
        "gstAmount": 0.0,
        "discounts": 0.0,
        "distanceFee": 0.0,
        "finalPayableAmount": calculatedTotal,
        "paymentMode": mode,
      };
    }
  }

  String _parseErrorMessage(String error) {
    if (error.contains("outside restaurant radius")) {
      return "Restaurant doesn't deliver to your location";
    }
    if (error.contains("Failed to create order")) {
      return "Unable to create order. Please try again";
    }
    if (error.contains("timeout") || error.contains("Timeout")) {
      return "Request timed out. Please check your internet connection";
    }
    if (error.contains("SocketException")) {
      return "Network error. Please check your internet connection";
    }
    return error.replaceAll("Exception: ", "").replaceAll("Exception:", "");
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
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
          'Your Cart',
          style: TextStyle(
            color: Color(0xFFF4E4C1),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loadingPrice
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
            )
          : _errorMessage != null
              ? _buildErrorView()
              : _buildCartContent(),
    );
  }

  Widget _buildCartContent() {
    return Column(
      children: [
        _buildDeliveryAddressCard(),
        _buildRestaurantHeader(),
        _buildDeliveryModeIndicator(),
        Expanded(child: _buildCartList()),
        _buildPricingSection(),
        _buildCheckoutButton(),
      ],
    );
  }

  Widget _buildDeliveryAddressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1A3A3C),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Color(0xFFD4AF37)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivering to',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  deliveryLocation['address'],
                  style: const TextStyle(
                    color: Color(0xFFF4E4C1),
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryModeIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF0C2C2E),
      child: Row(
        children: [
          Icon(
            deliveryMode == "detour_cab" ? Icons.local_taxi : Icons.delivery_dining,
            color: const Color(0xFFD4AF37),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              deliveryMode == "detour_cab"
                  ? "Shared Delivery (Save 50%)"
                  : "Dedicated Delivery",
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _showDeliveryModeSelection,
            child: const Text(
              "CHANGE",
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Unable to calculate pricing',
              style: TextStyle(
                color: Color(0xFFF4E4C1),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _parseErrorMessage(_errorMessage ?? 'An error occurred'),
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchPrice,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1A3A3C),
      child: Row(
        children: [
          const Icon(Icons.restaurant, color: Color(0xFFD4AF37)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.restaurant['name'] ?? 'Restaurant',
              style: const TextStyle(
                color: Color(0xFFF4E4C1),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.cartItems.length,
      itemBuilder: (context, index) {
        final item = widget.cartItems[index];
        final price = (item['price'] ?? 0) as num;
        final quantity = item['quantity'] ?? 1;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A3C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "${item['name'] ?? 'Item'} x $quantity",
                  style: const TextStyle(
                    color: Color(0xFFF4E4C1),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                "₹${(price * quantity).toStringAsFixed(0)}",
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildPricingSection() {
    final amounts = priceData?["amounts"] as Map<String, dynamic>?;
    
    final itemsTotal = amounts != null 
        ? ((amounts["itemsTotal"] ?? calculatedTotal) as num).toDouble()
        : calculatedTotal;
    final deliveryFee = ((amounts?["deliveryFee"] ?? 0) as num).toDouble();
    final platformFee = ((amounts?["platformFee"] ?? 0) as num).toDouble();
    final gstAmount = ((amounts?["gstAmount"] ?? 0) as num).toDouble();
    final savings = ((amounts?["discounts"] ?? 0) as num).toDouble();
    final finalAmount = amounts != null
        ? ((amounts["finalPayableAmount"] ?? calculatedTotal) as num).toDouble()
        : calculatedTotal;

    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF1A3A3C),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _priceRow("Items Total", itemsTotal),
          if (deliveryFee > 0) _priceRow("Delivery Fee", deliveryFee),
          if (platformFee > 0) _priceRow("Platform Fee", platformFee),
          if (gstAmount > 0) _priceRow("GST", gstAmount),
          if (savings > 0) _priceRow("Savings", -savings, green: true),
          const Divider(color: Colors.white24, height: 20),
          _priceRow("Final Payable", finalAmount, bold: true),
        ],
      ),
    );
  }

  Widget _priceRow(String label, num amount, {bool bold = false, bool green = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            "₹${amount.abs().toStringAsFixed(0)}",
            style: TextStyle(
              color: green ? Colors.greenAccent : const Color(0xFFD4AF37),
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton() {
    final amounts = priceData?["amounts"];
    final finalAmount = amounts != null
        ? ((amounts["finalPayableAmount"] ?? calculatedTotal) as num).toInt()
        : calculatedTotal.toInt();

    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF1A3A3C),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _creatingOrder ? null : _proceedToCheckout,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              disabledBackgroundColor: Colors.grey,
            ),
            child: _creatingOrder
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    "Proceed to Pay ₹$finalAmount",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}