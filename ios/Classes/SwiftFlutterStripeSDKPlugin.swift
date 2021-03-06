import Flutter
import UIKit
import Stripe

public class SwiftFlutterStripeSDKPlugin: NSObject, FlutterPlugin, STPAuthenticationContext {
  public func authenticationPresentingViewController() -> UIViewController {
    return self.viewController
  }
    
  private let ephemeralKeyProvider: EphemeralKeyProvider;
  private let methodChannel: FlutterMethodChannel;
  private let viewController: UIViewController;
  
  private var customerSession: STPCustomerContext?;
  
  init(methodChannel: FlutterMethodChannel, viewController: UIViewController) {
    self.methodChannel = methodChannel
    self.ephemeralKeyProvider = EphemeralKeyProvider(methodChannel: methodChannel)
    self.viewController = viewController
  }
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_stripe_sdk", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterStripeSDKPlugin(methodChannel: channel, viewController: (UIApplication.shared.delegate?.window?!.rootViewController)!)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
      case "init":
        _init(publishableKey: (call.arguments as! Dictionary<String, AnyObject>)["publishableKey"] as! String)
        result(nil)
        break
    case "initCustomerSession":
      _initCustomerSession();
      result(nil)
      break
    case "onKeyUpdate":
      ephemeralKeyProvider.keyUpdateListener?((call.arguments as! Dictionary<String, AnyObject>)["stripeResponseJson"] as? [String: AnyObject], nil)
      
      result(nil)
      break
    case "onKeyUpdateFailure":
      ephemeralKeyProvider.keyUpdateListener?(nil, NSError(domain: "flutter_stripe_sdk", code: (call.arguments as! Dictionary<String, AnyObject>)["responseCode"] as! Int, userInfo: ["message": (call.arguments as! Dictionary<String, AnyObject>)["message"] as! String]))

      result(nil)
      break
    case "retrieveCurrentCustomer":
      _retrieveCurrentCustomer(result: result)
      break;
    case "updateCurrentCustomer":
      _updateCurrentCustomer(result: result)
      break;
    case "getPaymentMethods":
      let paymentMethodType: STPPaymentMethodType;
      
      switch (call.arguments as! Dictionary<String, AnyObject>)["type"] as! String {
        case "card":
          paymentMethodType = STPPaymentMethodType.typeCard
          break
        case "card_present":
          paymentMethodType = STPPaymentMethodType.typeCardPresent
          break
        case "ideal":
          paymentMethodType = STPPaymentMethodType.typeiDEAL
          break
      default:
          paymentMethodType = STPPaymentMethodType.typeCard
          break
      }
        
      _getPaymentMethods(type: paymentMethodType, result: result)
      break;
    case "attachPaymentMethod":
      _attachPaymentMethod(id: (call.arguments as! Dictionary<String, AnyObject>)["id"] as! String, result: result)
      break;
    case "detachPaymentMethod":
      _detachPaymentMethod(id: (call.arguments as! Dictionary<String, AnyObject>)["id"] as! String, result: result)
      break;
    case "endCustomerSession":
      _endCustomerSession()
      result(nil)
      break
    case "createPaymentMethodCard":
      let cardParams = STPPaymentMethodCardParams()
      let billingDetails = STPPaymentMethodBillingDetails()
      
      cardParams.number = (call.arguments as! Dictionary<String, AnyObject>)["cardNumber"] as? String
      cardParams.expMonth = (call.arguments as! Dictionary<String, AnyObject>)["cardExpMonth"] as? NSNumber
      cardParams.expYear = (call.arguments as! Dictionary<String, AnyObject>)["cardExpYear"] as? NSNumber
      cardParams.cvc = (call.arguments as! Dictionary<String, AnyObject>)["cardCvv"] as? String
      
      billingDetails.name = (call.arguments as! Dictionary<String, AnyObject>)["billingDetailsName"] as? String
      billingDetails.email = (call.arguments as! Dictionary<String, AnyObject>)["billingDetailsEmail"] as? String
      
      
      _createPaymentMethodCard(paymentMethodCreateParams: STPPaymentMethodParams(card: cardParams, billingDetails: billingDetails, metadata: nil), result: result)
      break
    case "authenticatePayment":
      let paymentIntentSecret = (call.arguments as! Dictionary<String, AnyObject>)["paymentIntentSecret"] as? String
      
      _authenticatePayment(paymentIntentSecret: paymentIntentSecret!, result: result)
      break
    default:
      result(FlutterMethodNotImplemented)
      break
    }
  }
    
  private func _init(publishableKey: String) {
    STPPaymentConfiguration.shared().publishableKey = publishableKey
  }
  
  private func _initCustomerSession() {
    customerSession = STPCustomerContext(keyProvider: ephemeralKeyProvider)
  }
  
  private func _retrieveCurrentCustomer(result: @escaping FlutterResult) {
    customerSession?.retrieveCustomer({ (customer: STPCustomer?, error: Error?) in
      if (customer != nil) {
        result(customer?.allResponseFields)
      }
      
      if (error != nil) {
        result(FlutterError(code: "0", message: "Failed to retrieve current customer. Possible connection issues.", details: nil))
      }
    })
  }
  
  private func _updateCurrentCustomer(result: @escaping FlutterResult) {
    customerSession?.updateCustomer(withShippingAddress: STPAddress(), completion: { (error: Error?) in
      if (error != nil) {
        result(FlutterError(code: "0", message: "Failed to update current customer. Possible connection issues.", details: nil))
      } else {
        result(nil)
      }
    })
  }
  
  private func _getPaymentMethods(type: STPPaymentMethodType, result: @escaping FlutterResult) {
    customerSession?.listPaymentMethodsForCustomer(completion: { (paymenMethods: [STPPaymentMethod]?, error: Error?) in
      if (paymenMethods != nil) {
        result(paymenMethods?.map({ (paymentMethod: STPPaymentMethod) -> [AnyHashable : Any] in
          return paymentMethod.allResponseFields
        }))
      }
      
      if (error != nil) {
        result(FlutterError(code: "0", message: "Failed to get payment methods. Possible connection issues.", details: nil))
      }
    })
  }
  
  private func _attachPaymentMethod(id: String, result: @escaping FlutterResult) {
    customerSession?.attachPaymentMethod(toCustomer: id, completion: { (error: Error?) in
      if (error != nil) {
        result(FlutterError(code: "0", message: "Failed to attach payment method. Possible connection issues.", details: nil))
      } else {
        result(nil)
      }
    })
  }
  
  private func _detachPaymentMethod(id: String, result: @escaping FlutterResult) {
    customerSession?.detachPaymentMethod(fromCustomer: id, completion: { (error: Error?) in
      if (error != nil) {
        result(FlutterError(code: "0", message: "Failed to detach payment method. Possible connection issues.", details: nil))
      } else {
        result(nil)
      }
    })
  }
  
  private func _endCustomerSession() {
    customerSession?.clearCache()
    customerSession = nil;
  }

  private func _createPaymentMethodCard(paymentMethodCreateParams: STPPaymentMethodParams, result: @escaping FlutterResult) {
    STPAPIClient.shared().createPaymentMethod(with: paymentMethodCreateParams) { (paymentMethod: STPPaymentMethod?, error: Error?) in
      if (error != nil) {
        result(FlutterError(code: "0", message: "Failed to create payment method.", details: nil))
      } else {
        result(paymentMethod?.allResponseFields)
      }
    }
  }
  
  private func _authenticatePayment(paymentIntentSecret: String, result: @escaping FlutterResult) {
    STPPaymentHandler.shared().confirmPayment(withParams: STPPaymentIntentParams(clientSecret: paymentIntentSecret), authenticationContext: self) { (status: STPPaymentHandler.ActionStatus, paymentIntent: STPPaymentIntent?, error: Error?) in
        if (error != nil) {
          result(FlutterError(code: "0", message: "Failed to authenticate payment.", details: nil))
        } else {
          switch (status) {
            case .failed:
              result(FlutterError(code: "0", message: "Failed to authenticate payment.", details: nil))
              break;
            case .canceled:
              result(FlutterError(code: "0", message: "Failed to authenticate payment.", details: nil))
              break;
            case .succeeded:
              result(nil)
              break;
          }
        }
    }
  }
}

private class EphemeralKeyProvider: NSObject, STPCustomerEphemeralKeyProvider {
  private let methodChannel: FlutterMethodChannel;

  public var keyUpdateListener: STPJSONResponseCompletionBlock?;
  
  init (methodChannel: FlutterMethodChannel) {
    self.methodChannel = methodChannel;
  }
  
  func createCustomerKey(withAPIVersion apiVersion: String, completion: @escaping STPJSONResponseCompletionBlock) {
    keyUpdateListener = completion;
    methodChannel.invokeMethod("createEphemeralKey", arguments: ["apiVersion": apiVersion])
  }
}
