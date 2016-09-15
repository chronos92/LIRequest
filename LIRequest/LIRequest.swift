//
//  LIRequestSwift.swift
//  LIRequestSwift
//
//  Created by Boris Falcinelli on 03/02/16.
//  Copyright © 2016 Boris Falcinelli. All rights reserved.
//

import Foundation
import AFNetworking
import UIKit

public func == (l1 : LIRequest, l2 : LIRequest) -> Bool {
    return l1.LIUID == l2.LIUID
}

public class LIRequest : Equatable {
    /**
     The Content-Type to be set in the response
     
     - text/plain
     - application/json
     - text/html
     - image/jpeg
     */
    public enum ContentType : String {
        case textPlain = "text/plain"
        case applicationJson = "application/json"
        case textHtml = "text/html"
        case imageJpeg = "image/jpeg"
        //case applicationXwwwFormUrlencoded = "application/x-www-form-urlencoded"
    }
    
    /**
     It's a Request Unique Identifier
     The comparision when == is used check if the LIUID are eguals
     */
    let LIUID : String = UUID().uuidString
    private var contentType : LIRequest.ContentType
    private(set) var callbackName : String
    private var loginUsername : String?
    private var loginPassword : String?
    private var requestWithLogin : Bool = false
    private var previousCallbackName : String?
    private var previousContentType : LIRequest.ContentType?
    private var subContentType : LIRequest.ContentType?
    private var callbackForNextCall : Bool = false
    private var contentTypeForNexCall : Bool = false
    private var manager : AFHTTPSessionManager
    private var readingOption : JSONSerialization.ReadingOptions? = nil
    private var userAgent : String? = nil
    public var showNetworkActivityIndicator : Bool = true
    
    private var failureObject : ((_ object : AnyObject?,_ errorMessage : String)->Void)? = nil
    private var success : (_ response:AnyObject?)->Void = {_ in }
    private var additionalSuccess : ((_ response:AnyObject?)->Void)?
    private var failure : (_ errorMessage : String)->Void = {_ in }
    private var isComplete : ((_ request : LIRequest, _ state : Bool)->Void)?
    
    //MARK: INIT & SET
    /**
     Inializes a new request with a Content-Type and callback name and returns it to the caller
     
     - Parameters:
        - contentType: is a Content-Type used in the response
        - callbackName: default: data. Is a key used in the response object to move the object to the block
     */
    public init(contentType ct : LIRequest.ContentType, callbackName cn : String = "data") {
        contentType = ct
        callbackName = cn
        manager = AFHTTPSessionManager()
    }
    /**
     With this method it's possible to set a callback used only in the next call.
     After that call the callback is reset to the default
     
     - Parameter callback: new key for response object
     */
    public func setForNextCall(callback : String) {
        callbackForNextCall = true
        previousCallbackName = callbackName
        callbackName = callback
    }
    /**
     It's possible set multple params for the next call
     
     - Parameters:
        - contentType: new Content-Type used in the next call
        - subContentType: optional, additional Content-Type used in the next call
        - readingOption: optional, JSON reading option used for read the JSON Object recived in the next call
     */
    public func setForNextCall(contentType : LIRequest.ContentType, subContentType sub : LIRequest.ContentType? = nil, readingOption : JSONSerialization.ReadingOptions? = nil) {
        self.subContentType = sub
        self.readingOption = readingOption
        contentTypeForNexCall = true
        previousContentType = self.contentType
        self.contentType = contentType
    }
    /**
     It's possible to set username and password for the subsequent requests
     To disable login in subsequent request user *resetNeedLogin* method
     
     - Parameters:
        - username: username used in the request authorization
        - password: password used in the request authorization
     */
    public func setLogin(username : String, andPassword password : String) {
        requestWithLogin = true
        loginUsername = username
        loginPassword = password
    }
    /**
     When it setted username and password for the requests, it's possible to reset login data and set to off the login
     To set login data use *setLogin(username:andPassword:)* method
    */
    @available(iOS 1.10,*)
    public func resetNeedLogin() {
        requestWithLogin = false
        loginUsername = nil
        loginPassword = nil
    }
    /**
     The method set the User-Agent in the request
     
     - Parameter userAgent: User-Agent to set in the request
    */
    public func setUserAgent(_ userAgent : String) {
        self.userAgent = userAgent
    }
    
    //MARK: GET
    public func get(to urlString : String, withParams params : [String: Any]? = nil) -> URLSessionDataTask? {
        let requestSerializer = AFHTTPRequestSerializer()
        if requestWithLogin {
            requestSerializer.setAuthorizationHeaderFieldWithUsername(self.loginUsername!, password: self.loginPassword!)
        }
        if let ua = userAgent {
            requestSerializer.setValue(ua, forHTTPHeaderField: "User-Agent")
        }
        var responseSerializer : AFHTTPResponseSerializer
        switch contentType {
        case .applicationJson,.textPlain,.imageJpeg :
            responseSerializer = AFJSONResponseSerializer()
            if readingOption != nil {
                (responseSerializer as! AFJSONResponseSerializer).readingOptions = readingOption!
            }
        case.textHtml : responseSerializer = AFHTTPResponseSerializer()
        }
        responseSerializer.acceptableContentTypes = Set<String>(arrayLiteral:  contentType.rawValue)
        if subContentType != nil {
            responseSerializer.acceptableContentTypes?.insert(subContentType!.rawValue)
        } else {
            responseSerializer.acceptableContentTypes?.insert(LIRequest.ContentType.textPlain.rawValue)
        }
        manager.responseSerializer = responseSerializer
        manager.requestSerializer = requestSerializer
        
        NSLog("Nuova chiamata GET : %@", urlString)
        UIApplication.shared.isNetworkActivityIndicatorVisible = showNetworkActivityIndicator
        return manager.get(urlString, parameters: params, progress: nil, success: { (dataTask, responseObject) -> Void in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            NSLog("Risposta success per : %@", urlString)
            if self.contentType == .applicationJson || self.contentType == .textPlain {
                if let obj = responseObject as? [String:AnyObject] {
                    if !(obj["success"] as? Bool ?? true) {
                        self.callbackFailure(with: obj as AnyObject?, andErrorMessage: obj["message"] as! String)
                    } else {
                        let currentCallback = self.callbackName
                        if self.callbackForNextCall {
                            self.callbackForNextCall = false
                            self.callbackName = self.previousCallbackName!
                            self.previousCallbackName = nil
                        }
                        if let responseDict = responseObject as? [String:AnyObject] {
                            if currentCallback == "" {
                                self.callbackSuccess(with: responseDict as AnyObject?)
                            } else {
                                self.callbackSuccess(with: responseDict[currentCallback])
                            }
                        } else {
                            self.callbackSuccess(with: responseObject as AnyObject?)
                        }
                    }
                } else {
                    self.callbackSuccess(with: responseObject as AnyObject?)
                }
            } else {
                self.callbackSuccess(with: responseObject as AnyObject?)
            }
            if self.contentTypeForNexCall {
                self.contentTypeForNexCall = false
                self.contentType = self.previousContentType!
            }
            self.callbackIsComplete(with: true)
        }) { (dataTask, error) -> Void in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            NSLog("Risposta failure per : %@", urlString)
            self.callbackFailure(with: nil, andErrorMessage: error.localizedDescription)
            self.callbackIsComplete(with: false)
        }
    }
    //MARK: POST
    public func post(to urlString : String, withParams params : [String:Any]? = nil) -> URLSessionDataTask? {
        let requestSerializer = AFHTTPRequestSerializer()
        if params != nil {
            let data = try! JSONSerialization.data(withJSONObject: params!, options: JSONSerialization.WritingOptions.prettyPrinted)
            NSLog("%@",String(data: data, encoding: String.Encoding.utf8)!)
        }
        if requestWithLogin {
            requestSerializer.setAuthorizationHeaderFieldWithUsername(self.loginUsername!, password: self.loginPassword!)
        }
        if let ua = userAgent {
            requestSerializer.setValue(ua, forHTTPHeaderField: "User-Agent")
        }
        var responseSerializer : AFHTTPResponseSerializer
        switch contentType {
        case .applicationJson, .textPlain,.imageJpeg:
            responseSerializer = AFJSONResponseSerializer()
            if readingOption != nil {
                (responseSerializer as! AFJSONResponseSerializer).readingOptions = readingOption!
            }
        case .textHtml : responseSerializer = AFHTTPResponseSerializer()
        }
        responseSerializer.acceptableContentTypes = Set<String>(arrayLiteral: contentType.rawValue)
        if subContentType != nil {
            responseSerializer.acceptableContentTypes?.insert(subContentType!.rawValue)
        } else {
            responseSerializer.acceptableContentTypes?.insert(LIRequest.ContentType.textPlain.rawValue)
        }
        manager.responseSerializer = responseSerializer
        manager.requestSerializer = requestSerializer
        
//        if contentType == LIRequest.ContentType.applicationXwwwFormUrlencoded {
//            manager.requestSerializer.setQueryStringSerializationWithBlock({ (request, parameters, error) -> String in
//                do {
//                    let data = try JSONSerialization.data(withJSONObject: parameters, options: JSONSerialization.WritingOptions.prettyPrinted)
//                    let string = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
//                    return String(describing:string)
//                } catch {
//                    debugPrint("Errore nella codifica dei parametri")
//                    return ""
//                }
//            })
//        }
    
        NSLog("Nuova chiamata POST : %@", urlString)
        UIApplication.shared.isNetworkActivityIndicatorVisible = showNetworkActivityIndicator
        return manager.post(urlString, parameters: params, progress: nil, success: { (dataTask, responseObject) -> Void in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            if self.contentType == .applicationJson || self.contentType == .textPlain {
                if let obj = responseObject as? [String:AnyObject] {
                    if !(obj["success"] as? Bool ?? true) {
                        debugPrint(obj)
                        self.callbackFailure(with: obj as AnyObject?, andErrorMessage: obj["message"] as! String)
                    } else {
                        NSLog("Risposta success per : %@", urlString)
                        let currentCallback = self.callbackName
                        if self.callbackForNextCall {
                            self.callbackForNextCall = false
                            self.callbackName = self.previousCallbackName!
                            self.previousCallbackName = nil
                        }
                        
                        let response = responseObject as! [String:AnyObject]
                        if currentCallback == "" {
                            self.callbackSuccess(with: response as AnyObject?)
                        } else {
                            self.callbackSuccess(with: response[currentCallback])
                        }
                    }
                } else {
                    self.callbackSuccess(with: responseObject as AnyObject?)
                }
            } else {
                self.callbackSuccess(with: responseObject as AnyObject?)
            }
            if self.contentTypeForNexCall {
                self.contentTypeForNexCall = false
                self.contentType = self.previousContentType!
            }
            self.callbackIsComplete(with: true)
        }) { (dataTask, error) -> Void in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            NSLog("Risposta failure per : %@", urlString)
            debugPrint(error)
            self.callbackFailure(with: nil, andErrorMessage: error.localizedDescription)
            self.callbackIsComplete(with: false)
        }
    }
    
    public func post(to urlString : String, withImage image : UIImage, andFileName name : String, andParams params : [String:Any]?) -> URLSessionDataTask?{
        return post(to:urlString, withImage: image, andFileName: name, andParams: params, andParamsName: nil, uploadProgressBlock: nil)
    }
    
    public func post(to urlString : String, withImage image : UIImage, andFileName name : String, andParams params : [String:Any]?, uploadProgressBlock block : ((_ percentage:Progress)->Void)?) -> URLSessionDataTask?{
        return post(to:urlString, withImage: image, andFileName: name, andParams: params, andParamsName: nil, uploadProgressBlock: block)
    }
    
    public func post(to urlString : String, withImage image : UIImage, andFileName fileName : String, andParams params : [String:Any]?, andParamsName paramsName : String?, uploadProgressBlock block : ((_ percentage:Progress)-> Void)?) -> URLSessionDataTask? {
        return post(to:urlString, withImage: image,andFileName: fileName,andParams: params,andParamsName: paramsName,uploadProgressBlock: block)
    }
    
    public func post(to urlString : String, withData data : Data, withFileName fileName : String, andParams params : [String:Any]?, andParamsName paramsName : String?, uploadProgressBlock block : ((_ progress : Progress)->Void)?) -> URLSessionDataTask? {
        let requestSerializer = AFHTTPRequestSerializer()
        requestSerializer.setValue(LIRequest.ContentType.imageJpeg.rawValue, forHTTPHeaderField: "Content-Type")
        if requestWithLogin {
            requestSerializer.setAuthorizationHeaderFieldWithUsername(loginUsername!, password: loginPassword!)
        }
        if let ua = userAgent {
            requestSerializer.setValue(ua, forHTTPHeaderField: "User-Agent")
        }
        var responseSerializer : AFHTTPResponseSerializer
        switch contentType {
        case .applicationJson, .textPlain, .imageJpeg: responseSerializer = AFJSONResponseSerializer()
        case .textHtml: responseSerializer = AFHTTPResponseSerializer()
        }
        responseSerializer.acceptableContentTypes = Set<String>(arrayLiteral:  contentType.rawValue,LIRequest.ContentType.textPlain.rawValue)
        manager.responseSerializer = responseSerializer
        manager.requestSerializer = requestSerializer
        
        NSLog("Nuova chiamata POST : %@", urlString)
        UIApplication.shared.isNetworkActivityIndicatorVisible = showNetworkActivityIndicator
        return manager.post(urlString, parameters: params, constructingBodyWith: { (formData) -> Void in
            formData.appendPart(withFileData: data, name: paramsName ?? "", fileName: fileName, mimeType: LIRequest.ContentType.imageJpeg.rawValue)
            }, progress: { (progress) -> Void in
                DispatchQueue.main.async(execute: {
                    block?(progress)
                })
            }, success: { (dataTask, responseObject) -> Void in
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                if responseObject is NSData {
                    if [LIRequest.ContentType.textHtml,LIRequest.ContentType.textPlain].contains(self.contentType) {
                        self.callbackSuccess(with: responseObject as AnyObject?)
                    } else {
                        self.callbackFailure(with: responseObject as AnyObject?, andErrorMessage: "found data instead object")
                    }
                } else {
                    let obj = responseObject as! [String:AnyObject]
                    if !(obj["success"] as? Bool ?? true) {
                        self.callbackFailure(with: obj as AnyObject?, andErrorMessage: obj["message"] as! String)
                    } else {
                        let currentCallback = self.callbackName
                        if self.callbackForNextCall {
                            self.callbackForNextCall = false
                            self.callbackName = self.previousCallbackName!
                            self.previousCallbackName = nil
                        }
                        
                        let response = responseObject as! [String:AnyObject]
                        if currentCallback == "" {
                            self.callbackSuccess(with: response as AnyObject?)
                        } else {
                            self.callbackSuccess(with: response[currentCallback])
                        }
                    }
                }
                self.callbackIsComplete(with: true)
        }) { (dataTask, error) -> Void in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            self.callbackFailure(with: nil, andErrorMessage: error.localizedDescription)
            self.callbackIsComplete(with: false)
        }
    }
    
    public func abortAllOperation() {
        manager.operationQueue.cancelAllOperations()
    }
    
  
    public func setIsComplete(with isCompleteHandler : ((_ request:LIRequest, _ state : Bool)->Void)?) {
        isComplete = isCompleteHandler
    }
    
    public func setSuccess(with successHandler : @escaping (_ responseObject:AnyObject?)->Void) {
        success = successHandler
    }
    
    public func setAdditionalSuccess(with additionalSuccessHandler : ((_ responseObject:AnyObject?)->Void)?) {
        self.additionalSuccess = additionalSuccessHandler
    }
    
    public func setFailure(with failureHandler : @escaping (_ errorMessage : String)->Void) {
        failure = failureHandler
    }
    
    @available(*,unavailable)
    public func setFailureWithObject(_ failureHandler : (_ object : AnyObject?)->Void) {
    }
    
    public func setFailure(withObject failureHandler : ((_ object : AnyObject?,_ errorMessage : String)->Void)?) {
        failureObject = failureHandler
    }
    
    func callbackIsComplete(with state : Bool) {
        self.isComplete?(self,state)
    }
    
    func callbackFailure(with object: AnyObject?,andErrorMessage errorText : String) {
        NSLog("Error call : %@", errorText)
        if failureObject != nil {
            failureObject!(object,errorText)
        } else {
            failure(errorText)
        }
    }
    
    func callbackSuccess(with response: AnyObject?) {
        additionalSuccess?(response)
        success(response)
    }
    
    
    @available(*,deprecated:1.6,message:"callbackSuccess(with:) instead")
    func callbackSuccess(_ response: AnyObject?) {
        self.callbackSuccess(with: response)
        
    }
    @available(*,deprecated: 1.6,message: "use callbackFailure(with:) instead")
    func callbackFailure(_ object: AnyObject?,withErrorMessage errorText : String) {
        self.callbackFailure(with: object, andErrorMessage: errorText)
    }
    @available(*,deprecated: 1.6,message: "use callbackFailure(with:) instead")
    func callbackFailure(_ errorMessage : String) {
        self.callbackFailure(with:nil,andErrorMessage: errorMessage)
    }
    @available(*,deprecated: 1.6,message: "use callbackIsComplete(with:) instead")
    func callbackIsComplete(_ state : Bool) {
        self.callbackIsComplete(with: state)
    }
    @available(*,deprecated: 1.6,message: "use setFailure(withObject:) instead")
    public func setFailureWithObject(_ failureHandler : ((_ object : AnyObject?,_ errorMessage : String)->Void)?) {
        self.setFailure(withObject: failureHandler)
    }
    @available(*,deprecated:1.6,message:"use setFailure(with:) instead")
    public func setFailure(_ failureHandler : @escaping (_ errorMessage : String)->Void) {
        self.setFailure(with: failureHandler)
    }
    @available(*,deprecated:1.6,message:"use setSuccess(with:) instead")
    public func setSuccess(_ successHandler : @escaping (_ responseObject:AnyObject?)->Void) {
        self.setSuccess(with: successHandler)
    }
    @available(*,deprecated:1.6,message:"use setIsComplete(with:) instead")
    public func setIsComplete(_ isCompleteHandler : ((_ request:LIRequest, _ state : Bool)->Void)?) {
        self.setIsComplete(with: isCompleteHandler)
    }
    @available(*,deprecated:1.6,message:"use setLogin(username:andPassword:) insted")
    public func setLoginUsername(_ username : String, andLoginPassword password : String) {
        self.setLogin(username: username, andPassword: password)
    }
    @available(*,deprecated:1.6,message:"use setForNextCall(contentType:subContentType:readingOption:) instead")
    public func setContentTypeForNextCall(_ contentType : LIRequest.ContentType, subContentType sub : LIRequest.ContentType? = nil, readingOption : JSONSerialization.ReadingOptions? = nil) {
        self.setForNextCall(contentType: contentType, subContentType: sub, readingOption: readingOption)
    }
    @available(*,deprecated:1.6,message: "use setForNextCall(callback:) instead")
    public func setCallbackNameForNextCall(_ callback : String) {
        self.setForNextCall(callback: callback)
    }
    @available(*,deprecated:1.6,message: "use get(to:withParams:) instead")
    public func get(_ url : String, andParams params : [String: AnyObject]? = nil) -> URLSessionDataTask? {
        return get(to: url, withParams: params)
    }
    @available(*,deprecated:1.6,message: "use post(to:withParams:) instead")
    public func post(_ url : String, andParams params : [String:AnyObject]? = nil) -> URLSessionDataTask? {
        return post(to: url, withParams: params)
    }
    @available(*,deprecated:1.6,message: "use post(to:withImage:andFileName:andParams:) instead")
    public func post(_ url : String, andImage image : UIImage, withFileName name : String, andParams params : [String:AnyObject]?) -> URLSessionDataTask? {
        return post(to: url, withImage: image, andFileName: name, andParams: params)
    }
    @available(*,deprecated:1.6,message: "use post(to:withImage:andFileName:andParams:uploadProgressBlock:) instead")
    public func post(_ url : String, andImage image : UIImage, withFileName name : String, andParams params : [String:AnyObject]?, uploadProgressBlock block : ((_ percentage:Progress)->Void)?) -> URLSessionDataTask? {
        return post(to: url, withImage: image, andFileName: name, andParams: params, uploadProgressBlock: block)
    }
    @available(*,deprecated:1.6,message: "use post(to:withImage:andFileName:params:andParamsName:uploadProgressBlock:) instead")
    public func post(_ url : String, andImage image : UIImage, withFileName fileName : String, andParams params : [String:AnyObject]?, andParamsName paramsName : String?, uploadProgressBlock block : ((_ percentage:Progress)-> Void)?) -> URLSessionDataTask? {
        return post(to: url, withImage: image, andFileName: fileName, andParams: params, andParamsName: paramsName, uploadProgressBlock: block)
    }
    @available(*,deprecated:1.6,message: "use post(to:withData:andFileName:andParams:andParamsName:uploadProgressBlock:) instead")
    public func post(_ url : String, andData data : Data, withFileName fileName : String, andParams params : [String:AnyObject]?, andParamsName paramsName : String?, uploadProgressBlock block : ((_ progress : Progress)->Void)?) -> URLSessionDataTask? {
        return post(to: url, withData: data, withFileName: fileName, andParams: params, andParamsName: paramsName, uploadProgressBlock: block)
    }
}

@available(*,deprecated:1.6,renamed:"LIRequest.ContentType")
public enum LIRequestContentType : String {
    case TextPlain = "text/plain"
    case ApplicationJson = "application/json"
    case TextHtml = "text/html"
    case ImageJpeg = "image/jpeg"
}
