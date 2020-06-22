import Flutter
import UIKit
import Braintree
import BraintreeDropIn

//Developed by Dishant Mahajan
public class SwiftFlutterBraintreePlugin: NSObject, FlutterPlugin, BTViewControllerPresentingDelegate, PKPaymentAuthorizationViewControllerDelegate {
    
    var braintreeClient: BTAPIClient?
    var isHandlingResult: Bool = false
    var flutterResult: FlutterResult?;
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_braintree.custom", binaryMessenger: registrar.messenger())
        
        let instance = SwiftFlutterBraintreePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        print(call.method)
        
        self.flutterResult=result;
        
        if call.method == "start" {
            guard !isHandlingResult else { result(FlutterError(code: "drop_in_already_running", message: "Cannot launch another Drop-in activity while one is already running.", details: nil)); return }
            
            isHandlingResult = true
            
            let dropInRequest = BTDropInRequest()
            
            if let amount = string(for: "amount", in: call) {
                dropInRequest.threeDSecureRequest?.amount = NSDecimalNumber(string: amount)
            }
            
            if let requestThreeDSecureVerification = bool(for: "requestThreeDSecureVerification", in: call) {
                dropInRequest.threeDSecureVerification = requestThreeDSecureVerification
            }
            
            if let vaultManagerEnabled = bool(for: "vaultManagerEnabled", in: call) {
                dropInRequest.vaultManager = vaultManagerEnabled
            }
            
            let clientToken = string(for: "clientToken", in: call)
            let tokenizationKey = string(for: "tokenizationKey", in: call)
            
            guard let authorization = clientToken ?? tokenizationKey else {
                result(FlutterError(code: "braintree_error", message: "Authorization not specified (no clientToken or tokenizationKey)", details: nil))
                isHandlingResult = false
                return
            }
            
            let dropInController = BTDropInController(authorization: authorization, request: dropInRequest) { (controller, braintreeResult, error) in
                controller.dismiss(animated: true, completion: nil)
                
                self.handle(braintreeResult: braintreeResult, error: error, flutterResult: result)
                self.isHandlingResult = false
            }
            
            guard let existingDropInController = dropInController else {
                result(FlutterError(code: "braintree_error", message: "BTDropInController not initialized (no API key or request specified?)", details: nil))
                isHandlingResult = false
                return
            }
            
            UIApplication.shared.keyWindow?.rootViewController?.present(existingDropInController, animated: true, completion: nil)
        }else if call.method == "tokenizeCreditCard" {
            
            isHandlingResult = true
            
            let tokenizationKey = string(for: "authorization", in: call)
            guard let authorization = tokenizationKey else {
                result(FlutterError(code: "braintree_error", message: "Authorization not specified (no clientToken or tokenizationKey)", details: nil))
                isHandlingResult = false
                return
            }
            print(authorization)
            
            if let arguments = call.arguments as? [String:Any] {
                if let request = arguments["request"] as? [String:Any] {
                    
                    let cardNumber = request["cardNumber"] as! String
                    let expirationMonth = request["expirationMonth"] as! String
                    let expirationYear = request["expirationYear"] as! String
                    let cvv = request["cvv"] as! String
                    
                    let braintreeClient = BTAPIClient(authorization: authorization)!
                    let cardClient = BTCardClient(apiClient: braintreeClient)
                    let card = BTCard(number: cardNumber, expirationMonth:expirationMonth, expirationYear: expirationYear, cvv: cvv)
                    cardClient.tokenizeCard(card) { (tokenizedCard, error) in
                        
                        if(error != nil){
                            result(FlutterError(code: "braintree_error", message: error?.localizedDescription, details: nil))
                            self.isHandlingResult = false
                            return
                        }
                        
                        
                        let resultDict: [String: Any?] = ["nonce": tokenizedCard?.nonce ,
                                                          "typeLabel": tokenizedCard?.type ,
                                                          "description": tokenizedCard?.localizedDescription ,
                                                          "isDefault":tokenizedCard?.isDefault ]
                        
                        
                        result(resultDict)
                        
                        
                    }
                }
            }
            
            
        }
        else if call.method == "requestPaypalNonce" {
            
            isHandlingResult = true
            
            let tokenizationKey = string(for: "authorization", in: call)
            guard let authorization = tokenizationKey else {
                result(FlutterError(code: "braintree_error", message: "Authorization not specified (no clientToken or tokenizationKey)", details: nil))
                isHandlingResult = false
                return
            }
            print(authorization)
            
            
            if let arguments = call.arguments as? [String:Any] {
                if let requestParams = arguments["request"] as? [String:Any] {
                    
                    let displayName = requestParams["displayName"] as! String
                    let billingAgreementDescription = requestParams["billingAgreementDescription"] as! String
                    let braintreeClient = BTAPIClient(authorization: authorization)!
                    let payPalDriver = BTPayPalDriver(apiClient: braintreeClient)
                    payPalDriver.viewControllerPresentingDelegate = self
                    //            payPalDriver.appSwitchDelegate = UIApplication.shared.keyWindow?.rootViewController
                    
                    let request = BTPayPalRequest()
                    request.displayName = displayName
                    request.billingAgreementDescription = billingAgreementDescription //Displayed in customer's PayPal account
                    payPalDriver.requestBillingAgreement(request) { (tokenizedPayPalAccount, error) -> Void in
                        if let tokenizedPayPalAccount = tokenizedPayPalAccount {
                            print("Got a nonce: \(tokenizedPayPalAccount.nonce)")
                            let resultDict: [String: Any?] = ["nonce": tokenizedPayPalAccount.nonce ,
                                                              "typeLabel": tokenizedPayPalAccount.type ,
                                                              "description": tokenizedPayPalAccount.localizedDescription ,
                                                              "isDefault":tokenizedPayPalAccount.isDefault ]
                            
                            
                            result(resultDict)
                            
                        } else if let error = error {
                            // Handle error here...
                            print(error)
                            result(FlutterError(code: "braintree_error", message: error.localizedDescription, details: nil))
                            self.isHandlingResult = false
                            return
                        } else {
                            // Buyer canceled payment approval
                            result(FlutterError(code: "braintree_error", message: "Cancelled By User", details: nil))
                            self.isHandlingResult = false
                            return
                        }
                    }
                }
                
            }
        }
        else if(call.method == "isApplePayAvailable"){
            
            if PKPaymentAuthorizationViewController.canMakePayments(usingNetworks: [PKPaymentNetwork.visa, PKPaymentNetwork.masterCard, PKPaymentNetwork.amex]) {
                result( true);
            }else{
                result( false);
            }
            
        }else if(call.method == "collectDeviceData"){
            
            let tokenizationKey = string(for: "authorization", in: call)
            guard let authorization = tokenizationKey else {
                result(FlutterError(code: "braintree_error", message: "Authorization not specified (no clientToken or tokenizationKey)", details: nil))
                isHandlingResult = false
                return
            }
            
            
            let braintreeClient = BTAPIClient(authorization: authorization)!
            
            let dataCollector:BTDataCollector = BTDataCollector.init(apiClient: braintreeClient)
            dataCollector.collectDeviceData({ deviceData in
                
                result(deviceData);
            })
            
            
        }else if(call.method == "payWithApplePay"){
            //
            //            guard !isHandlingResult else { self.setFlutterError(code: "payment_already_running", message: "Cannot launch another Payment activity while one is already running."); return }
            //
            //
            isHandlingResult = true
            
            let tokenizationKey = string(for: "authorization", in: call)
            guard let authorization = tokenizationKey else {
                self.setFlutterError(code:"braintree_error",message: "Authorization not specified (no clientToken or tokenizationKey)")
                return
            }
            
            
            
            self.braintreeClient = BTAPIClient(authorization: authorization)!
            let applePayClient = BTApplePayClient(apiClient: self.braintreeClient!)
            // You can use the following helper method to create a PKPaymentRequest which will set the `countryCode`,
            // `currencyCode`, `merchantIdentifier`, and `supportedNetworks` properties.
            // You can also create the PKPaymentRequest manually. Be aware that you'll need to keep these in
            // sync with the gateway settings if you go this route.
            applePayClient.paymentRequest { (paymentRequest, error) in
                guard let paymentRequest = paymentRequest else {
                    self.setFlutterError(code:"braintree_error",message: error!.localizedDescription)
                    return
                }
                
                // We recommend collecting billing address information, at minimum
                // billing postal code, and passing that billing postal code with all
                // Apple Pay transactions as a best practice.
                if #available(iOS 11.0, *) {
                    //paymentRequest.requiredBillingContactFields = [.postalAddress]
                } else {
                    // Fallback on earlier versions
                }
                
                // Set other PKPaymentRequest properties here
                paymentRequest.merchantCapabilities = .capability3DS
                
                if let arguments = call.arguments as? [String:Any] {
                    
                    guard let label = arguments["label"] else {
                        self.setFlutterError(code:"braintree_error",message:"Label not specified" )
                        return
                    }
                    
                    guard let total = arguments["total"] else {
                        self.setFlutterError(code:"braintree_error",message:"Amount not specified" )
                        return
                    }
                    
                    let amount = NSDecimalNumber( value: total as! Double)
                    
                    paymentRequest.paymentSummaryItems =
                        [
                            PKPaymentSummaryItem(label: label as! String, amount: amount),
                    ]
                    
                    
                    if let vc = PKPaymentAuthorizationViewController(paymentRequest: paymentRequest)
                        as PKPaymentAuthorizationViewController?
                    {
                        vc.delegate =  self
                        
                        UIApplication.shared.keyWindow?.rootViewController?.present(vc, animated: true, completion: nil)
                    } else {
                        self.setFlutterError(code:"braintree_error",message:"Error: Payment request is invalid." )
                    }
                }
            }
        }
            
        else {
            print("Not Implemented")
            result(FlutterMethodNotImplemented)
        }
    }
    
    func setFlutterError(code:String, message:String ){
        self.flutterResult?(FlutterError(code: code, message: message,details: nil))
        isHandlingResult = false
        return
        
    }
    
    public func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.dismiss(animated: true, completion:nil)
        guard !isHandlingResult else { self.setFlutterError(code: "payment_not_completed", message: "Payment not Completed"); return }
        
    }
    
    
    public func paymentDriver(_ driver: Any, requestsPresentationOf viewController: UIViewController) {
        
    }
    
    public func paymentDriver(_ driver: Any, requestsDismissalOf viewController: UIViewController) {
        
    }
    
    @available(iOS 11.0, *)
    public func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController,
                                                   didAuthorizePayment payment: PKPayment,
                                                   handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        
        // Tokenize the Apple Pay payment
        let braintreeClient = BTApplePayClient(apiClient: self.braintreeClient!)
        
        braintreeClient.tokenizeApplePay(payment) { (nonce, error) in
            if error != nil {
                // Received an error from Braintree.
                // Indicate failure via the completion callback.
                self.setFlutterError(code: "braintree_error", message:error!.localizedDescription)
                completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                return
            }
            
            // TODO: On success, send nonce to your server for processing.
            // If requested, address information is accessible in `payment` and may
            // also be sent to your server.
            // Then indicate success or failure based on the server side result of Transaction.sale
            // via the completion callback.
            // e.g. If the Transaction.sale was successful
            
            
            let resultDict: [String: Any?] = ["nonce": nonce?.nonce ,
                                              "typeLabel": nonce?.type ,
                                              "description": nonce?.localizedDescription ,
                                              "isDefault":nonce?.isDefault ]
            
            
            self.setFlutterSuccess(resultDict: resultDict)
            completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        }
        
    }
    
    
    func setFlutterSuccess(resultDict: [String:Any?]){
        self.flutterResult!(resultDict)
        self.isHandlingResult=false;
    }
    
    
    
    private func handle(braintreeResult: BTDropInResult?, error: Error?, flutterResult: FlutterResult) {
        if error != nil {
            flutterResult(FlutterError(code: "braintree_error", message: error?.localizedDescription, details: nil))
        }
        else if braintreeResult?.isCancelled ?? false {
            flutterResult(nil)
        }
        else if let braintreeResult = braintreeResult {
            let nonceResultDict: [String: Any?] = ["nonce": braintreeResult.paymentMethod?.nonce,
                                                   "typeLabel": braintreeResult.paymentMethod?.type,
                                                   "description": braintreeResult.paymentMethod?.localizedDescription,
                                                   "isDefault": braintreeResult.paymentMethod?.isDefault]
            
            let resultDict: [String: Any?] = ["paymentMethodNonce": nonceResultDict]
            
            flutterResult(resultDict)
        }
    }
    
    
    private func string(for key: String, in call: FlutterMethodCall) -> String? {
        return (call.arguments as? [String: Any])?[key] as? String
    }
    
    
    private func bool(for key: String, in call: FlutterMethodCall) -> Bool? {
        return (call.arguments as? [String: Any])?[key] as? Bool
    }
    
}
