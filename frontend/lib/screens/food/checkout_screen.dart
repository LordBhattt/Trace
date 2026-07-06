// lib/screens/food/checkout_screen.dart
// ⚠️ This screen is deprecated in the new TRACE Food Flow.
// Checkout is now fully handled INSIDE CartScreen.
// We keep this file ONLY to avoid app crashes if any old navigation calls it.

import 'package:flutter/material.dart';
import 'cart_screen.dart';

class CheckoutScreen extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  final List<Map<String, dynamic>> cartItems;

  const CheckoutScreen({
    super.key,
    required this.restaurant,
    required this.cartItems,
  });

  @override
  Widget build(BuildContext context) {
    // Immediately redirect to CartScreen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CartScreen(
            restaurant: restaurant,
            cartItems: cartItems,
          ),
        ),
      );
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0C2C2E),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFD4AF37)),
            SizedBox(height: 16),
            Text(
              "Redirecting to TRACE Checkout...",
              style: TextStyle(color: Color(0xFFF4E4C1), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
