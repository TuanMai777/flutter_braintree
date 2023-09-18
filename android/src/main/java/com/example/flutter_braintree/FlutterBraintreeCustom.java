package com.example.flutter_braintree;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;


import com.braintreepayments.api.BraintreeClient;
import com.braintreepayments.api.BraintreeRequestCodes;
import com.braintreepayments.api.BrowserSwitchResult;
import com.braintreepayments.api.Card;
import com.braintreepayments.api.CardClient;
import com.braintreepayments.api.CardNonce;
import com.braintreepayments.api.DataCollector;
import com.braintreepayments.api.DataCollectorCallback;
import com.braintreepayments.api.GooglePayClient;
import com.braintreepayments.api.GooglePayIsReadyToPayCallback;
import com.braintreepayments.api.GooglePayRequest;
import com.braintreepayments.api.GooglePayRequestPaymentCallback;
import com.braintreepayments.api.PayPalAccountNonce;
import com.braintreepayments.api.PayPalClient;
import com.braintreepayments.api.PayPalListener;
import com.braintreepayments.api.PayPalVaultRequest;
import com.braintreepayments.api.PaymentMethodNonce;
import com.braintreepayments.api.ThreeDSecureAdditionalInformation;
import com.braintreepayments.api.ThreeDSecureClient;
import com.braintreepayments.api.ThreeDSecurePostalAddress;
import com.braintreepayments.api.ThreeDSecureRequest;
import com.braintreepayments.api.ThreeDSecureResult;
import com.google.android.gms.wallet.TransactionInfo;
import com.google.android.gms.wallet.WalletConstants;

import java.util.HashMap;

public class FlutterBraintreeCustom extends AppCompatActivity implements PayPalListener {
    private BraintreeClient braintreeClient;
    private PayPalClient payPalClient;
    private GooglePayClient googlePayClient;
    private DataCollector dataCollector;
    private ThreeDSecureClient threeDSecureClient;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_flutter_braintree_custom);

        try {
            Intent intent = getIntent();
            braintreeClient = new BraintreeClient(this, intent.getStringExtra("authorization"), "com.hello.world.mahajan");
//                    "com.example.flutter_braintree_example.braintree");
            googlePayClient = new GooglePayClient(braintreeClient);
            dataCollector = new DataCollector(braintreeClient);
            payPalClient = new PayPalClient(braintreeClient);
            payPalClient.setListener(this);
            threeDSecureClient = new ThreeDSecureClient(braintreeClient);

            String type = intent.getStringExtra("type");
            if (type.equals("tokenizeCreditCard")) {
                tokenizeCreditCard();
            } else if (type.equals("requestPaypalNonce")) {
                requestPaypalNonce();
            } else if (type.equals("isGooglePayAvailable")) {
                isGooglePayAvailable();
            } else if (type.equals("payWithGooglePay")) {
                payWithGooglePay();
            } else if (type.equals("collectDeviceData")) {
                collectDeviceData();
            } else {
                throw new Exception("Invalid request type: " + type);
            }
        } catch (Exception e) {
            Intent result = new Intent();
            result.putExtra("error", e);
            setResult(2, result);
            finish();
            return;
        }
    }

    private void payWithGooglePay() {
        Intent intent = getIntent();

        GooglePayRequest googlePaymentRequest = new GooglePayRequest();
        googlePaymentRequest
                .setTransactionInfo(TransactionInfo.newBuilder()
                        .setTotalPrice(intent.getStringExtra("total"))
                        .setTotalPriceStatus(WalletConstants.TOTAL_PRICE_STATUS_FINAL)
                        .setCurrencyCode(intent.getStringExtra("currencyCode"))
                        .build());

        googlePaymentRequest.setPayPalEnabled(false);

        googlePaymentRequest.setGoogleMerchantName(intent.getStringExtra("label"));
        // We recommend collecting billing address information, at minimum
        // billing postal code, and passing that billing postal code with all
        // Google Pay card transactions as a best practice.
        googlePaymentRequest.setBillingAddressRequired(true);

        if (!intent.getBooleanExtra("testing", true)) {
            googlePaymentRequest.setEnvironment("PRODUCTION");
        }

        googlePayClient.requestPayment(this, googlePaymentRequest, new GooglePayRequestPaymentCallback() {
            @Override
            public void onResult(@Nullable Exception error) {

            }
        });

    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == BraintreeRequestCodes.GOOGLE_PAY) {
            googlePayClient.onActivityResult(resultCode, data, (paymentMethodNonce, error) -> {
                if (paymentMethodNonce != null) {
                    // send this nonce to your server
                    String nonce = paymentMethodNonce.getString();
                    sendNonceBack(nonce, "", "", paymentMethodNonce.isDefault());
                } else {
                    // handle error
                }
            });
        }

//        else if (requestCode == BraintreeRequestCodes.THREE_D_SECURE){
//            threeDSecureClient.onActivityResult(resultCode, data, (threeDSecureResult, error) -> {
//                // send threeDSecureResult.getTokenizedCard().getString() to your server
//            });
//        }

    }

    private void collectDeviceData() {

        dataCollector.collectDeviceData(this, new DataCollectorCallback() {
            @Override
            public void onResult(@Nullable String deviceData, @Nullable Exception error) {

                // send deviceData to your server
                Intent data = new Intent();
                data.putExtra("type", "collectDeviceData");
                data.putExtra("result", deviceData);
                setResult(RESULT_OK, data);
                finish();
            }
        });
    }

    private void isGooglePayAvailable() {
        googlePayClient.isReadyToPay(this, (isReadyToPay, error) -> {
            Intent data = new Intent();
            data.putExtra("type", "isGooglePayAvailable");
            data.putExtra("result", isReadyToPay);
            setResult(RESULT_OK, data);
            finish();
        });
    }

    protected void tokenizeCreditCard() {
        Intent intent = getIntent();
        Card card = new Card();

        card.setNumber(intent.getStringExtra("cardNumber"));
        card.setCvv(intent.getStringExtra("cvv"));
        card.setExpirationMonth(intent.getStringExtra("expirationMonth"));
        card.setExpirationYear(intent.getStringExtra("expirationYear"));

        CardClient cardClient = new CardClient(braintreeClient);

        cardClient.tokenize(card, (cardNonce, error) -> {
            if (error != null) {

            } else {
                threeDSecureProcess(cardNonce);
//                sendNonceBack(cardNonce.getString(), cardNonce.getCardType(), cardNonce.getBin(), cardNonce.isDefault());
            }

        });
    }

    private void threeDSecureProcess(CardNonce cardNonce) {

        ThreeDSecurePostalAddress address = new ThreeDSecurePostalAddress();
        address.setGivenName("Jill"); // ASCII-printable characters required, else will throw a validation error
        address.setSurname("Doe"); // ASCII-printable characters required, else will throw a validation error
        address.setPhoneNumber("5551234567");
        address.setStreetAddress("555 Smith St");
        address.setExtendedAddress("#2");
        address.setLocality("Chicago");
        address.setRegion("IL");
        address.setPostalCode("12345");
        address.setCountryCodeAlpha2("US");

// For best results, provide as many additional elements as possible.
        ThreeDSecureAdditionalInformation additionalInformation = new ThreeDSecureAdditionalInformation();
        additionalInformation.setShippingAddress(address);

        ThreeDSecureRequest threeDSecureRequest = new ThreeDSecureRequest();
        threeDSecureRequest.setAmount("10");
        threeDSecureRequest.setEmail("test@email.com");
        threeDSecureRequest.setBillingAddress(address);
        threeDSecureRequest.setNonce(cardNonce.getString());
        threeDSecureRequest.setVersionRequested(ThreeDSecureRequest.VERSION_2);
        threeDSecureRequest.setAdditionalInformation(additionalInformation);

        threeDSecureClient.performVerification(this, threeDSecureRequest, (threeDSecureLookupResult, lookupError) -> {
            // optional: inspect the lookup result and prepare UI if a challenge is required
            if (threeDSecureLookupResult != null) {
                threeDSecureClient.continuePerformVerification(this, threeDSecureRequest, threeDSecureLookupResult, (threeDSecureResult, verificationError) -> {
                    // send threeDSecureResult.getTokenizedCard().getString() nonce to your server
                });
            } else {
                sendNonceBack(cardNonce.getString(), cardNonce.getCardType(), cardNonce.getBin(), cardNonce.isDefault());
            }

        });

    }



    @Override
    protected void onNewIntent(Intent newIntent) {
        super.onNewIntent(newIntent);

        setIntent(newIntent);
    }

    protected void requestPaypalNonce() {
        Intent intent = getIntent();


        PayPalVaultRequest vaultRequest = new PayPalVaultRequest();

        vaultRequest.setDisplayName(intent.getStringExtra("displayName"));
        vaultRequest.setBillingAgreementDescription(intent.getStringExtra("billingAgreementDescription"));
        payPalClient.tokenizePayPalAccount(this, vaultRequest);



//        PayPalVaultRequest request = new PayPalVaultRequest(intent.getStringExtra("amount"))
//                .currencyCode(intent.getStringExtra("currencyCode"))
//                .displayName(intent.getStringExtra("displayName"))
//                .billingAgreementDescription(intent.getStringExtra("billingAgreementDescription"))
//                .intent(PayPalRequest.INTENT_AUTHORIZE);
//
//        if (intent.getStringExtra("amount") == null) {
//            // Vault flow
//            PayPal.requestBillingAgreement(braintreeFragment, request);
//        } else {
//            // Checkout flow
//            PayPal.requestOneTimePayment(braintreeFragment, request);
//        }
    }


    @Override
    protected void onResume() {
        super.onResume();
        Log.i("Error", "Resume Called");
//        BrowserSwitchResult browserSwitchResult = braintreeClient.deliverBrowserSwitchResult(this);

//        if (payPalClient != null && browserSwitchResult != null && browserSwitchResult.getRequestCode() == BraintreeRequestCodes.PAYPAL) {
//            payPalClient.onBrowserSwitchResult(browserSwitchResult, (payPalAccountNonce, error) -> {
//                if (payPalAccountNonce != null) {
//                    // Send nonce to server
//                    String nonce = payPalAccountNonce.getString();
//                    sendNonceBack(nonce, payPalAccountNonce.getClientMetadataId(), payPalAccountNonce.getAuthenticateUrl(), payPalAccountNonce.isDefault());
//                } else {
//                    // handle error
//                    Log.d("Error", error.getMessage());
//                }
//            });
//        }
    }


    void sendNonceBack(String nonce, String typeLabel, String description, boolean isDefault) {
        HashMap<String, Object> nonceMap = new HashMap<String, Object>();
        nonceMap.put("nonce", nonce);
        nonceMap.put("typeLabel", typeLabel);
        nonceMap.put("description", description);
        nonceMap.put("isDefault", isDefault);

        Intent result = new Intent();
        result.putExtra("type", "paymentMethodNonce");
        result.putExtra("paymentMethodNonce", nonceMap);
        setResult(RESULT_OK, result);
        finish();
    }

    @Override
    public void onPayPalSuccess(@NonNull PayPalAccountNonce payPalAccountNonce) {
        String nonce = payPalAccountNonce.getString();
        Log.i("nonce",nonce);
        sendNonceBack(nonce, payPalAccountNonce.getClientMetadataId(), payPalAccountNonce.getAuthenticateUrl(), payPalAccountNonce.isDefault());
    }

    @Override
    public void onPayPalFailure(@NonNull Exception error) {
        Log.d("Paypal Error", error.getMessage());
    }

    //    @Override
//    public void onPaymentMethodNonceCreated(PaymentMethodNonce paymentMethodNonce) {
//        HashMap<String, Object> nonceMap = new HashMap<String, Object>();
//        nonceMap.put("nonce", paymentMethodNonce.getNonce());
//        nonceMap.put("typeLabel", paymentMethodNonce.getTypeLabel());
//        nonceMap.put("description", paymentMethodNonce.getDescription());
//        nonceMap.put("isDefault", paymentMethodNonce.isDefault());
//
//        Intent result = new Intent();
//        result.putExtra("type", "paymentMethodNonce");
//        result.putExtra("paymentMethodNonce", nonceMap);
//        setResult(RESULT_OK, result);
//        finish();
//    }
//
//    @Override
//    public void onCancel(int requestCode) {
//        setResult(RESULT_CANCELED);
//        finish();
//    }
//
//    @Override
//    public void onError(Exception error) {
//
//        Intent result = new Intent();
//        result.putExtra("error", error);
//        setResult(2, result);
//        finish();
//    }
//

}
