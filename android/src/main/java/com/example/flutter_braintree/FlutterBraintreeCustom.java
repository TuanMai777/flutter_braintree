package com.example.flutter_braintree;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

import androidx.appcompat.app.AppCompatActivity;

import com.braintreepayments.api.BraintreeFragment;
import com.braintreepayments.api.Card;
import com.braintreepayments.api.GooglePayment;
import com.braintreepayments.api.PayPal;
import com.braintreepayments.api.interfaces.BraintreeCancelListener;
import com.braintreepayments.api.interfaces.BraintreeErrorListener;
import com.braintreepayments.api.interfaces.BraintreeResponseListener;
import com.braintreepayments.api.interfaces.PaymentMethodNonceCreatedListener;
import com.braintreepayments.api.models.CardBuilder;
import com.braintreepayments.api.models.GooglePaymentRequest;
import com.braintreepayments.api.models.PayPalRequest;
import com.braintreepayments.api.models.PaymentMethodNonce;
import com.google.android.gms.wallet.TransactionInfo;
import com.google.android.gms.wallet.WalletConstants;

import java.util.HashMap;

public class FlutterBraintreeCustom extends AppCompatActivity implements PaymentMethodNonceCreatedListener, BraintreeCancelListener, BraintreeErrorListener {
    private BraintreeFragment braintreeFragment;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_flutter_braintree_custom);

        try {
            Intent intent = getIntent();
            braintreeFragment = BraintreeFragment.newInstance(this, intent.getStringExtra("authorization"));
            String type = intent.getStringExtra("type");
            if (type.equals("tokenizeCreditCard")) {
                tokenizeCreditCard();
            } else if (type.equals("requestPaypalNonce")) {
                requestPaypalNonce();
            } else if (type.equals("isGooglePayAvailable")) {
                isGooglePayAvailable();
            } else if (type.equals("payWithGooglePay")) {
                payWithGooglePay();
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
        GooglePaymentRequest googlePaymentRequest = new GooglePaymentRequest()
                .transactionInfo(TransactionInfo.newBuilder()
                        .setTotalPrice(intent.getStringExtra("total"))
                        .setTotalPriceStatus(WalletConstants.TOTAL_PRICE_STATUS_FINAL)
                        .setCurrencyCode(intent.getStringExtra("currencyCode"))
                        .build())
                .paypalEnabled(false)
                .googleMerchantName(intent.getStringExtra("label"))
                // We recommend collecting billing address information, at minimum
                // billing postal code, and passing that billing postal code with all
                // Google Pay card transactions as a best practice.
                .billingAddressRequired(true);

        GooglePayment.requestPayment(braintreeFragment, googlePaymentRequest);

    }

    private void isGooglePayAvailable() {
        GooglePayment.isReadyToPay(braintreeFragment, new BraintreeResponseListener<Boolean>() {
            @Override
            public void onResponse(Boolean isReadyToPay) {
                Log.i("TAG", "isGooglePayAvailable " + isReadyToPay);
                Intent data = new Intent();
                data.putExtra("type", "isGooglePayAvailable");
                if (isReadyToPay) {
                    data.putExtra("result", true);
                } else {
                    data.putExtra("result", false);
                }
                setResult(RESULT_OK, data);
                finish();
            }

        });
    }

    protected void tokenizeCreditCard() {
        Intent intent = getIntent();
        CardBuilder builder = new CardBuilder()
                .cardNumber(intent.getStringExtra("cardNumber"))
                .cvv(intent.getStringExtra("cvv"))
                .expirationMonth(intent.getStringExtra("expirationMonth"))
                .expirationYear(intent.getStringExtra("expirationYear"));
        Card.tokenize(braintreeFragment, builder);
    }

    protected void requestPaypalNonce() {
        Intent intent = getIntent();
        PayPalRequest request = new PayPalRequest(intent.getStringExtra("amount"))
                .currencyCode(intent.getStringExtra("currencyCode"))
                .displayName(intent.getStringExtra("displayName"))
                .billingAgreementDescription(intent.getStringExtra("billingAgreementDescription"))
                .intent(PayPalRequest.INTENT_AUTHORIZE);

        if (intent.getStringExtra("amount") == null) {
            // Vault flow
            PayPal.requestBillingAgreement(braintreeFragment, request);
        } else {
            // Checkout flow
            PayPal.requestOneTimePayment(braintreeFragment, request);
        }
    }

    @Override
    public void onPaymentMethodNonceCreated(PaymentMethodNonce paymentMethodNonce) {
        HashMap<String, Object> nonceMap = new HashMap<String, Object>();
        nonceMap.put("nonce", paymentMethodNonce.getNonce());
        nonceMap.put("typeLabel", paymentMethodNonce.getTypeLabel());
        nonceMap.put("description", paymentMethodNonce.getDescription());
        nonceMap.put("isDefault", paymentMethodNonce.isDefault());

        Intent result = new Intent();
        result.putExtra("type", "paymentMethodNonce");
        result.putExtra("paymentMethodNonce", nonceMap);
        setResult(RESULT_OK, result);
        finish();
    }

    @Override
    public void onCancel(int requestCode) {
        setResult(RESULT_CANCELED);
        finish();
    }

    @Override
    public void onError(Exception error) {
        Intent result = new Intent();
        result.putExtra("error", error);
        setResult(2, result);
        finish();
    }
}
