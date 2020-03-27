import Flutter
import UIKit
import Braintree
import BraintreeDropIn

//Developed by Dishant Mahajan
public class SwiftFlutterBraintreePlugin: NSObject, FlutterPlugin, BTViewControllerPresentingDelegate {
    
    public func paymentDriver(_ driver: Any, requestsPresentationOf viewController: UIViewController) {
        UIApplication.shared.keyWindow?.rootViewController?.present(viewController, animated: true, completion: nil)
    }
    
    public func paymentDriver(_ driver: Any, requestsDismissalOf viewController: UIViewController) {
        UIApplication.shared.keyWindow?.rootViewController?.dismiss(animated: true, completion: nil)
    }
    
    
    var isHandlingResult: Bool = false
    
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_braintree.custom", binaryMessenger: registrar.messenger())
        
        let instance = SwiftFlutterBraintreePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
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
            print("tokenizeCreditCard")
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
                    
                    let braintreeClient = BTAPIClient(authorization: authorization)!
                    let cardClient = BTCardClient(apiClient: braintreeClient)
                    let card = BTCard(number: cardNumber, expirationMonth:expirationMonth, expirationYear: expirationYear, cvv: nil)
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
            
            
        }else if call.method == "requestPaypalNonce" {
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
            
            
        else {
            print("Not Implemented")
            result(FlutterMethodNotImplemented)
        }
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
