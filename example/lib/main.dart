import 'package:flutter/material.dart';
import 'package:flutter_braintree/flutter_braintree.dart';

void main() => runApp(
      MaterialApp(
        home: MyApp(),
      ),
    );

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static final String tokenizationKey = 'sandbox_5gpzt4pc_djn63vyk799r7w45';

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    // if (Platform.isIOS) {
    //   checkApplePay();
    // } else {
    //   checkGooglePay();
    // }
  }

  void showNonce(BraintreePaymentMethodNonce nonce) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Payment method nonce:'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Nonce: ${nonce.nonce}'),
            SizedBox(height: 16),
            Text('Type label: ${nonce.typeLabel}'),
            SizedBox(height: 16),
            Text('Description: ${nonce.description}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Braintree example app'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            applePayAvailable
                ? TextButton(
                    onPressed: () async {
                      try {
                        BraintreePaymentMethodNonce result =
                            await Braintree.payWithApplePay(
                                tokenizationKey, 'Testing ', 10);
                        if (result != null) {
                          showNonce(result);
                        }
                      } catch (e) {
                        print(e);
                      }
                    },
                    child: Text('Test Apple Pay'),
                  )
                : Container(),
            googlePayAvailable
                ? TextButton(
                    onPressed: () async {
                      try {
                        BraintreePaymentMethodNonce result =
                            await Braintree.payWithGooglePay(
                                tokenizationKey, 'AUD', 'Testing ', 10, true);
                        if (result != null) {
                          showNonce(result);
                        }
                      } catch (e) {
                        print(e);
                      }
                    },
                    child: Text('Test Google Pay'),
                  )
                : Container(),
            TextButton(
              onPressed: () async {
                try {
                  String result =
                      await Braintree.collectDeviceData(tokenizationKey);

                  if (result != null) {
                    print("Device Data");
                    print(result);
                  }
                } catch (e) {
                  print(e);
                }
              },
              child: Text('Collect Device Data'),
            ),
            TextButton(
              onPressed: () async {
                var request = BraintreeDropInRequest(
                  tokenizationKey: tokenizationKey,
                  collectDeviceData: true,
                  googlePaymentRequest: BraintreeGooglePaymentRequest(
                    totalPrice: '4.20',
                    currencyCode: 'USD',
                    billingAddressRequired: false, googleMerchantID: '',
                  ),
                  paypalRequest: BraintreePayPalRequest(
                    amount: '4.20',
                    displayName: 'Example company',
                  ),
                );
                BraintreeDropInResult result =
                    await BraintreeDropIn.start(request);
                if (result != null) {
                  showNonce(result.paymentMethodNonce);
                }
              },
              child: Text('LAUNCH NATIVE DROP-IN'),
            ),
            TextButton(
              onPressed: () async {
                final request = BraintreeCreditCardRequest(
                    cardNumber: '4813900009988650',
                    expirationMonth: '11',
                    expirationYear: '2024',
                    cvv: '382');
                BraintreePaymentMethodNonce result =
                    await Braintree.tokenizeCreditCard(
                  tokenizationKey,
                  request,
                );
                if (result != null) {
                  showNonce(result);
                }
              },
              child: Text('TOKENIZE CREDIT CARD'),
            ),
            TextButton(
              onPressed: () async {
                final request = BraintreePayPalRequest(
                  billingAgreementDescription:
                      'I hearby agree that flutter_braintree is great.',
                  displayName: 'Your Company',
                );
                BraintreePaymentMethodNonce result =
                    await Braintree.requestPaypalNonce(
                  tokenizationKey,
                  request,
                );
                if (result != null) {
                  showNonce(result);
                }
              },
              child: Text('PAYPAL VAULT FLOW'),
            ),
            TextButton(
              onPressed: () async {
                final request = BraintreePayPalRequest(amount: '13.37');
                BraintreePaymentMethodNonce result =
                    await Braintree.requestPaypalNonce(
                  tokenizationKey,
                  request,
                );
                if (result != null) {
                  showNonce(result);
                }
              },
              child: Text('PAYPAL CHECKOUT FLOW'),
            ),
          ],
        ),
      ),
    );
  }

  bool applePayAvailable = false;

  void checkApplePay() async {
    bool result = await Braintree.isApplePayAvailable();
    if (result != null) {
      setState(() {
        applePayAvailable = result;
      });
    }
  }

  bool googlePayAvailable = false;

  void checkGooglePay() async {
    bool result = await Braintree.isGooglePayAvailable(tokenizationKey);
    if (result != null) {
      print(result);
      setState(() {
        googlePayAvailable = result;
      });
    }
  }
}
