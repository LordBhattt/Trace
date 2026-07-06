import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentService {
  /// Generic low-level checkout used internally.
  /// Returns a Map with either { success: true, paymentId, orderId, signature }
  /// or { success: false, message }.
  static Future<Map<String, dynamic>> openCheckout({
    required String key,
    required int amount, // in paise
    required String orderId,
    required String name,
    required String description,
    String? amountInRupees,
    String? rideId,
  }) async {
    final razorpay = Razorpay();
    final Completer<Map<String, dynamic>> completer = Completer();

    // Success
    void onSuccess(PaymentSuccessResponse response) {
      if (!completer.isCompleted) {
        completer.complete({
          'success': true,
          'paymentId': response.paymentId,
          'orderId': response.orderId,
          'signature': response.signature,
        });
      }
    }

    // Error
    void onError(PaymentFailureResponse response) {
      if (!completer.isCompleted) {
        completer.complete({
          'success': false,
          'message': response.message ?? 'Payment failed',
        });
      }
    }

    // External wallet
    void onExternal(ExternalWalletResponse response) {
      if (!completer.isCompleted) {
        completer.complete({
          'success': false,
          'message': 'External wallet selected: ${response.walletName}',
        });
      }
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onError);
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, onExternal);

    final options = {
      'key': key,
      'amount': amount,
      'order_id': orderId,
      'name': name,
      'description': description,
      'prefill': {
        'contact': '',
        'email': '',
      },
    };

    try {
      razorpay.open(options);

      // Wait for callback or timeout
      final result = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          return {
            'success': false,
            'message': 'Payment timeout or user cancelled',
          };
        },
      );

      // Clear listeners & instance
      try {
        razorpay.clear();
      } catch (_) {}

      return result;
    } catch (e) {
      try {
        razorpay.clear();
      } catch (_) {}
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// High-level helper: ride payment (cab)
  static Future<Map<String, dynamic>> openRideCheckout({
    required String key,
    required int amount, // in paise
    required String orderId,
    required String rideId,
  }) {
    return openCheckout(
      key: key,
      amount: amount,
      orderId: orderId,
      name: 'TRACE Ride Payment',
      description: 'Ride fare payment',
      amountInRupees: (amount / 100).toStringAsFixed(2),
      rideId: rideId,
    );
  }

  /// High-level helper: 50% off cancelled food order resale
  static Future<Map<String, dynamic>> openResaleCheckout({
    required String key,
    required int amount, // in paise
    required String orderId,
  }) {
    return openCheckout(
      key: key,
      amount: amount,
      orderId: orderId,
      name: 'TRACE Food Resale',
      description: 'Cancelled order at 50% off',
      amountInRupees: (amount / 100).toStringAsFixed(2),
      rideId: orderId, // for your backend, this acts like rideId
    );
  }
}
