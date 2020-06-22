import 'package:flutter/services.dart';

import 'request.dart';
import 'result.dart';

class Braintree {
  static const MethodChannel _kChannel =
      const MethodChannel('flutter_braintree.custom');

  const Braintree._();

  /// Tokenizes a credit card.
  ///
  /// [authorization] must be either a valid client token or a valid tokenization key.
  /// [request] should contain all the credit card information necessary for tokenization.
  ///
  /// Returns a [Future] that resolves to a [BraintreePaymentMethodNonce] if the tokenization was successful.
  static Future<BraintreePaymentMethodNonce> tokenizeCreditCard(
    String authorization,
    BraintreeCreditCardRequest request,
  ) async {
    assert(authorization != null);
    assert(request != null);
    final result = await _kChannel.invokeMethod('tokenizeCreditCard', {
      'authorization': authorization,
      'request': request.toJson(),
    });

    return BraintreePaymentMethodNonce.fromJson(result);
  }

  static Future<bool> isGooglePayAvailable(
    String authorization,
  ) async {
    assert(authorization != null);
    final result = await _kChannel.invokeMethod('isGooglePayAvailable', {
      'authorization': authorization,
    });
    return result;
  }

  static Future<bool> isApplePayAvailable() async {
    final result = await _kChannel.invokeMethod('isApplePayAvailable');
    return result;
  }

  static Future<BraintreePaymentMethodNonce> payWithGooglePay(
    String authorization,
    String currencyCode,
    String label,
    double total,
    bool testing,
  ) async {
    assert(authorization != null);
    assert(currencyCode != null);
    assert(label != null);
    assert(total != null && total >= 0);
    assert(testing != null);
    final result = await _kChannel.invokeMethod('payWithGooglePay', {
      'authorization': authorization,
      'label': label,
      'currencyCode': currencyCode,
      'total': total.toString(),
      "testing": testing
    });

    return BraintreePaymentMethodNonce.fromJson(result);
  }

  static Future<String> collectDeviceData(String authorization) async {
    assert(authorization != null);

    final String result = await _kChannel.invokeMethod('collectDeviceData', {
      'authorization': authorization,
    });

    return result;
  }

  static Future<BraintreePaymentMethodNonce> payWithApplePay(
    String authorization,
    String label,
    double total,
  ) async {
    assert(authorization != null);
    assert(label != null);
    assert(total != null && total >= 0);
    final result = await _kChannel.invokeMethod('payWithApplePay', {
      'authorization': authorization,
      'label': label,
      'total': total,
    });

    return BraintreePaymentMethodNonce.fromJson(result);
  }

  /// Requests a PayPal payment method nonce.
  ///
  /// [authorization] must be either a valid client token or a valid tokenization key.
  /// [request] should contain all the information necessary for the PayPal request.
  ///
  /// Returns a [Future] that resolves to a [BraintreePaymentMethodNonce] if the user confirmed the request,
  /// or `null` if the user canceled the Vault or Checkout flow.
  static Future<BraintreePaymentMethodNonce> requestPaypalNonce(
    String authorization,
    BraintreePayPalRequest request,
  ) async {
    assert(authorization != null);
    assert(request != null);
    final result = await _kChannel.invokeMethod('requestPaypalNonce', {
      'authorization': authorization,
      'request': request.toJson(),
    });

    return BraintreePaymentMethodNonce.fromJson(result);
  }
}
