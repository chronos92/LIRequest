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

public func == (l1 : LIRequestBase, l2 : LIRequestBase) -> Bool {
    return l1.LIUID == l2.LIUID
}

@available(*,deprecated:1.6,renamed:"LIRequest.ContentType")
public enum LIRequestContentType : String {
    case TextPlain = "text/plain"
    case ApplicationJson = "application/json"
    case TextHtml = "text/html"
    case ImageJpeg = "image/jpeg"
}

public class LIRequestBase : Equatable {
    
    public enum ContentType : String {
        case textPlain = "text/plain"
        case applicationJson = "application/json"
        case textHtml = "text/html"
        case imageJpeg = "image/jpeg"
    }
    
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
    //MARK: INIT & SET
    public init(contentType ct : LIRequest.ContentType, callbackName cn : String = "data") {
        contentType = ct
        callbackName = cn
        manager = AFHTTPSessionManager()
    }
    
    public func setForNextCall(callback : String) {
        callbackForNextCall = true
        previousCallbackName = callbackName
        callbackName = callback
    }
    
    public func setForNextCall(contentType : LIRequest.ContentType, subContentType sub : LIRequest.ContentType? = nil, readingOption : JSONSerialization.ReadingOptions? = nil) {
        self.subContentType = sub
        self.readingOption = readingOption
        contentTypeForNexCall = true
        previousContentType = self.contentType
        self.contentType = contentType
    }
    
    public func setLogin(username : String, andPassword password : String) {
        requestWithLogin = true
        loginUsername = username
        loginPassword = password
    }
    
    public func setUserAgent(_ userAgent : String) {
        self.userAgent = userAgent
    }
    //MARK: GET
    public func get(to urlString : String, withParams params : [String: AnyObject]? = nil) -> URLSessionDataTask? {
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
        UIApplication.shared().isNetworkActivityIndicatorVisible = showNetworkActivityIndicator
        return manager.get(urlString, parameters: params, progress: nil, success: { (dataTask, responseObject) -> Void in
            UIApplication.shared().isNetworkActivityIndicatorVisible = false
            NSLog("Risposta success per : %@", urlString)
            if self.contentType == .applicationJson || self.contentType == .textPlain {
                if let obj = responseObject as? [String:AnyObject] {
                    if !(obj["success"] as? Bool ?? true) {
                            self.callbackFailure(with: obj, andErrorMessage: obj["message"] as! String)
                    } else {
                        let currentCallback = self.callbackName
                        if self.callbackForNextCall {
                            self.callbackForNextCall = false
                            self.callbackName = self.previousCallbackName!
                            self.previousCallbackName = nil
                        }
                        if let responseDict = responseObject as? [String:AnyObject] {
                            if currentCallback == "" {
                                self.callbackSuccess(with: responseDict)
                            } else {
                                self.callbackSuccess(with: responseDict[currentCallback])
                            }
                        } else {
                            self.callbackSuccess(with: responseObject)
                        }
                    }
                } else {
                    self.callbackSuccess(with: responseObject)
                }
            } else {
                self.callbackSuccess(with: responseObject)
            }
            if self.contentTypeForNexCall {
                self.contentTypeForNexCall = false
                self.contentType = self.previousContentType!
            }
            self.callbackIsComplete(with: true)
        }) { (dataTask, error) -> Void in
            UIApplication.shared().isNetworkActivityIndicatorVisible = false
            NSLog("Risposta failure per : %@", urlString)
            self.callbackFailure(with: nil, andErrorMessage: error.localizedDescription)
            self.callbackIsComplete(with: false)
        }
    }
    //MARK: POST
    public func post(to urlString : String, withParams params : [String:AnyObject]? = nil) -> URLSessionDataTask? {
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
        
        NSLog("Nuova chiamata POST : %@", urlString)
        UIApplication.shared().isNetworkActivityIndicatorVisible = showNetworkActivityIndicator
        return manager.post(urlString, parameters: params, progress: nil, success: { (dataTask, responseObject) -> Void in
            UIApplication.shared().isNetworkActivityIndicatorVisible = false
            if self.contentType == .applicationJson || self.contentType == .textPlain {
                if let obj = responseObject as? [String:AnyObject] {
                    if !(obj["success"] as? Bool ?? true) {
                        debugPrint(obj)
                        if obj["data"] != nil && !(obj["data"]! as? [String:AnyObject] ?? [:]).isEmpty {
                            self.callbackFailure(with: obj["data"],andErrorMessage:obj["message"] as! String)
                        } else {
                            self.callbackFailure(with: obj["message"] as! String)
                        }
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
                            self.callbackSuccess(with: response)
                        } else {
                            self.callbackSuccess(with: response[currentCallback])
                        }
                    }
                } else {
                    self.callbackSuccess(with: responseObject)
                }
            } else {
                self.callbackSuccess(with: responseObject)
            }
            if self.contentTypeForNexCall {
                self.contentTypeForNexCall = false
                self.contentType = self.previousContentType!
            }
            self.callbackIsComplete(with: true)
        }) { (dataTask, error) -> Void in
            UIApplication.shared().isNetworkActivityIndicatorVisible = false
            NSLog("Risposta failure per : %@", urlString)
            debugPrint(error)
            self.callbackFailure(with: error.localizedDescription)
            self.callbackIsComplete(with: false)
        }
    }
    
    public func post(to urlString : String, withImage image : UIImage, andFileName name : String, andParams params : [String:AnyObject]?) -> URLSessionDataTask?{
        return post(to:urlString, withImage: image, andFileName: name, andParams: params, andParamsName: nil, uploadProgressBlock: nil)
    }
    
    public func post(to urlString : String, withImage image : UIImage, andFileName name : String, andParams params : [String:AnyObject]?, uploadProgressBlock block : (percentage:Progress)->Void) -> URLSessionDataTask?{
        return post(to:urlString, withImage: image, andFileName: name, andParams: params, andParamsName: nil, uploadProgressBlock: block)
    }
    
    public func post(to urlString : String, withImage image : UIImage, andFileName fileName : String, andParams params : [String:AnyObject]?, andParamsName paramsName : String?, uploadProgressBlock block : ((percentage:Progress)-> Void)?) -> URLSessionDataTask? {
        return post(to:urlString, withImage: image,andFileName: fileName,andParams: params,andParamsName: paramsName,uploadProgressBlock: block)
    }
    
    public func post(to urlString : String, withData data : Data, withFileName fileName : String, andParams params : [String:AnyObject]?, andParamsName paramsName : String?, uploadProgressBlock block : ((progress : Progress)->Void)?) -> URLSessionDataTask? {
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
        UIApplication.shared().isNetworkActivityIndicatorVisible = showNetworkActivityIndicator
        return manager.post(urlString, parameters: params, constructingBodyWith: { (formData) -> Void in
            formData.appendPart(withFileData: data, name: paramsName ?? "", fileName: fileName, mimeType: LIRequest.ContentType.imageJpeg.rawValue)
            }, progress: { (progress) -> Void in
                DispatchQueue.main.async(execute: {
                    block?(progress: progress)
                })
            }, success: { (dataTask, responseObject) -> Void in
                UIApplication.shared().isNetworkActivityIndicatorVisible = false
                if responseObject is NSData {
                    if [LIRequest.ContentType.textHtml,LIRequest.ContentType.textPlain].contains(self.contentType) {
                        self.callbackSuccess(with: responseObject)
                    } else {
                        self.callbackFailure(with: "found data instead object")
                    }
                } else {
                    let obj = responseObject as! [String:AnyObject]
                    if !(obj["success"] as? Bool ?? true) {
                        self.callbackFailure(with: obj["message"] as! String)
                    } else {
                        let currentCallback = self.callbackName
                        if self.callbackForNextCall {
                            self.callbackForNextCall = false
                            self.callbackName = self.previousCallbackName!
                            self.previousCallbackName = nil
                        }
                        
                        let response = responseObject as! [String:AnyObject]
                        if currentCallback == "" {
                            self.callbackSuccess(with: response)
                        } else {
                            self.callbackSuccess(with: response[currentCallback])
                        }
                    }
                }
                self.callbackIsComplete(with: true)
        }) { (dataTask, error) -> Void in
            UIApplication.shared().isNetworkActivityIndicatorVisible = false
            self.callbackFailure(with: error.localizedDescription)
            self.callbackIsComplete(with: false)
        }
    }
    
    //MARK: CALLBACK
    func callbackFailure(with object : AnyObject?,andErrorMessage errorText : String) {
        
    }
    
    func callbackSuccess(with response : AnyObject?) {
        
    }
    
    func callbackIsComplete(with state : Bool) {
        
    }
    
    public func abortAllOperation() {
        manager.operationQueue.cancelAllOperations()
    }
    
    
    @available(*,deprecated: 1.6,message: "use callbackIsComplete(with:) isntead")
    func callbackIsComplete(_ state : Bool) {
        callbackIsComplete(with: state)
    }
    @available(*,deprecated: 1.6,message: "use callbackSuccess(with:) instead")
    func callbackSuccess(_ response : AnyObject?) {
        self.callbackSuccess(with: response)
    }
    @available(*,deprecated:1.6,message:"use callbackFailure(with:) instead")
    func callbackFailure(_ errorMessage : String) {
        self.callbackFailure(with: errorMessage)
    }
    @available(*,deprecated:1.6,message:"use callbackFailure(with:andErrormessage:) instead")
    func callbackFailure(_ object : AnyObject?,withErrorMessage errorText : String) {
        self.callbackFailure(with: object, andErrorMessage: errorText)
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
    public func post(_ url : String, andImage image : UIImage, withFileName name : String, andParams params : [String:AnyObject]?, uploadProgressBlock block : (percentage:Progress)->Void) -> URLSessionDataTask? {
        return post(to: url, withImage: image, andFileName: name, andParams: params, uploadProgressBlock: block)
    }
    @available(*,deprecated:1.6,message: "use post(to:withImage:andFileName:params:andParamsName:uploadProgressBlock:) instead")
    public func post(_ url : String, andImage image : UIImage, withFileName fileName : String, andParams params : [String:AnyObject]?, andParamsName paramsName : String?, uploadProgressBlock block : ((percentage:Progress)-> Void)?) -> URLSessionDataTask? {
        return post(to: url, withImage: image, andFileName: fileName, andParams: params, andParamsName: paramsName, uploadProgressBlock: block)
    }
    @available(*,deprecated:1.6,message: "use post(to:withData:andFileName:andParams:andParamsName:uploadProgressBlock:) instead")
    public func post(_ url : String, andData data : Data, withFileName fileName : String, andParams params : [String:AnyObject]?, andParamsName paramsName : String?, uploadProgressBlock block : ((progress : Progress)->Void)?) -> URLSessionDataTask? {
        return post(to: url, withData: data, withFileName: fileName, andParams: params, andParamsName: paramsName, uploadProgressBlock: block)
    }

}

public class LIRequest : LIRequestBase {
    internal var failureObject : ((object : AnyObject?,errorMessage : String)->Void)? = nil
    internal var success : (response:AnyObject?)->Void = {_ in }
    internal var additionalSuccess : ((response:AnyObject?)->Void)?
    internal var failure : (errorMessage : String)->Void = {_ in }
    internal var isComplete : ((request : LIRequest, state : Bool)->Void)?
    
    public func setIsComplete(with isCompleteHandler : (request:LIRequest, state : Bool)->Void) {
        isComplete = isCompleteHandler
    }
    
    public func setSuccess(with successHandler : (responseObject:AnyObject?)->Void) {
        success = successHandler
    }
    
    public func setAdditionalSuccess(with additionalSuccessHandler : ((responseObject:AnyObject?)->Void)?) {
        self.additionalSuccess = additionalSuccessHandler
    }
    
    public func setFailure(with failureHandler : (errorMessage : String)->Void) {
        failure = failureHandler
    }
    
    @available(*,unavailable)
    public func setFailureWithObject(_ failureHandler : (object : AnyObject?)->Void) {
    }
    
    public func setFailure(withObject failureHandler : (object : AnyObject?,errorMessage : String)->Void) {
        failureObject = failureHandler
    }
    
    override func callbackIsComplete(with state : Bool) {
        self.isComplete?(request: self,state: state)
    }
    
    override func callbackFailure(with object: AnyObject?,andErrorMessage errorText : String) {
        NSLog("Error call : %@", errorMessage)
        if failureObject != nil {
            failureObject!(object: object,errorMessage : errorText)
        } else {
            failure(errorMessage: errorText)
        }
    }
    
    override func callbackSuccess(with response: AnyObject?) {
        additionalSuccess?(response:response)
        success(response: response)
    }
    
    
    @available(*,deprecated:1.6,message:"callbackSuccess(with:) instead")
    override func callbackSuccess(_ response: AnyObject?) {
        self.callbackSuccess(with: response)
        
    }
    @available(*,deprecated: 1.6,message: "use callbackFailure(with:) instead")
    override func callbackFailure(_ object: AnyObject?,withErrorMessage errorText : String) {
        self.callbackFailure(with: object, andErrorMessage: errorText)
    }
    @available(*,deprecated: 1.6,message: "use callbackFailure(with:) instead")
    override func callbackFailure(_ errorMessage : String) {
        self.callbackFailure(with: errorMessage)
    }
    @available(*,deprecated: 1.6,message: "use callbackIsComplete(with:) instead")
    override func callbackIsComplete(_ state : Bool) {
        self.callbackIsComplete(with: state)
    }
    @available(*,deprecated: 1.6,message: "use setFailure(withObject:) instead")
    public func setFailureWithObject(_ failureHandler : (object : AnyObject?,errorMessage : String)->Void) {
        self.setFailure(withObject: failureHandler)
    }
    @available(*,deprecated:1.6,message:"use setFailure(with:) instead")
    public func setFailure(_ failureHandler : (errorMessage : String)->Void) {
        self.setFailure(with: failureHandler)
    }
    @available(*,deprecated:1.6,message:"use setSuccess(with:) instead")
    public func setSuccess(_ successHandler : (responseObject:AnyObject?)->Void) {
        self.setSuccess(with: successHandler)
    }
    @available(*,deprecated:1.6,message:"use setIsComplete(with:) instead")
    public func setIsComplete(_ isCompleteHandler : (request:LIRequest, state : Bool)->Void) {
        self.setIsComplete(with: isCompleteHandler)
    }
}
