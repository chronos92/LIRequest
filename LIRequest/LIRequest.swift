//
//  LIRequestSwift.swift
//  LIRequestSwift
//
//  Created by Boris Falcinelli on 03/02/16.
//  Copyright © 2016 Boris Falcinelli. All rights reserved.
//

import Foundation
import AFNetworking

public enum LIRequestContentType : String {
    case textPlain = "text/plain"
    case applicationJson = "application/json"
    case textHtml = "text/html"
    case imageJpeg = "image/jpeg"
    case MP3File = "audio/mpeg"
    case WAVEAudioFile = "audio/x-wav"
}

public func == (l1 : LIRequestBase, l2 : LIRequestBase) -> Bool {
    return l1.LIUID == l2.LIUID
}

public class LIRequestBase : Equatable {
    let LIUID : String = UUID().uuidString
    private var contentType : LIRequestContentType
    private(set) var callbackName : String
    private var loginUsername : String?
    private var loginPassword : String?
    private var requestWithLogin : Bool = false
    private var previousCallbackName : String?
    private var previousContentType : LIRequestContentType?
    private var subContentType : LIRequestContentType?
    private var callbackForNextCall : Bool = false
    private var contentTypeForNexCall : Bool = false
    private var manager : AFHTTPSessionManager
    private var readingOption : JSONSerialization.ReadingOptions? = nil
    private var userAgent : String? = nil
    //MARK: INIT & SET
    public init(contentType ct : LIRequestContentType, callbackName cn : String = "data") {
        contentType = ct
        callbackName = cn
        manager = AFHTTPSessionManager()
    }
    
    public func setCallbackNameForNextCall(_ callback : String) {
        callbackForNextCall = true
        previousCallbackName = callbackName
        callbackName = callback
    }
    
    public func setContentTypeForNextCall(_ contentType : LIRequestContentType, subContentType sub : LIRequestContentType? = nil, readingOption : JSONSerialization.ReadingOptions? = nil) {
        self.subContentType = sub
        self.readingOption = readingOption
        contentTypeForNexCall = true
        previousContentType = self.contentType
        self.contentType = contentType
    }
    
    public func setLoginUsername(_ username : String, andLoginPassword password : String) {
        requestWithLogin = true
        loginUsername = username
        loginPassword = password
    }
    
    public func setUserAgent(_ userAgent : String) {
        self.userAgent = userAgent
    }
    //MARK: GET
    public func get(_ url : String, andParams params : [String: AnyObject]? = nil) -> URLSessionDataTask? {
        let requestSerializer = AFHTTPRequestSerializer()
        if requestWithLogin {
            requestSerializer.setAuthorizationHeaderFieldWithUsername(self.loginUsername!, password: self.loginPassword!)
        }
        if let ua = userAgent {
            requestSerializer.setValue(ua, forHTTPHeaderField: "User-Agent")
        }
        var responseSerializer : AFHTTPResponseSerializer
        switch contentType {
        case .ApplicationJson,.TextPlain,.ImageJpeg :
            responseSerializer = AFJSONResponseSerializer()
            if readingOption != nil {
                (responseSerializer as! AFJSONResponseSerializer).readingOptions = readingOption!
            }
        case.TextHtml : responseSerializer = AFHTTPResponseSerializer()
        }
        responseSerializer.acceptableContentTypes = Set<String>(arrayLiteral:  contentType.rawValue)
        if subContentType != nil {
            responseSerializer.acceptableContentTypes?.insert(subContentType!.rawValue)
        } else {
            responseSerializer.acceptableContentTypes?.insert(LIRequestContentType.TextPlain.rawValue)
        }
        manager.responseSerializer = responseSerializer
        manager.requestSerializer = requestSerializer
        
        NSLog("Nuova chiamata GET : %@", url)
        return manager.get(url, parameters: params, progress: nil, success: { (dataTask, responseObject) -> Void in
            
            NSLog("Risposta success per : %@", url)
            if self.contentType == .ApplicationJson || self.contentType == .TextPlain {
                if let obj = responseObject as? [String:AnyObject] {
                    if !(obj["success"] as? Bool ?? true) {
                        if obj["data"] != nil {
                            self.callbackFailure(obj["data"], withErrorMessage: obj["message"] as! String)
                        } else {
                            self.callbackFailure(obj["message"] as! String)
                        }
                    } else {
                        let currentCallback = self.callbackName
                        if self.callbackForNextCall {
                            self.callbackForNextCall = false
                            self.callbackName = self.previousCallbackName!
                            self.previousCallbackName = nil
                        }
                        if let responseDict = responseObject as? [String:AnyObject] {
                            if currentCallback == "" {
                                self.callbackSuccess(responseDict)
                            } else {
                                self.callbackSuccess(responseDict[currentCallback])
                            }
                        } else {
                            self.callbackSuccess(responseObject)
                        }
                    }
                } else {
                    self.callbackSuccess(responseObject)
                }
            } else {
                self.callbackSuccess(responseObject)
            }
            if self.contentTypeForNexCall {
                self.contentTypeForNexCall = false
                self.contentType = self.previousContentType!
            }
            self.callbackIsComplete(true)
        }) { (dataTask, error) -> Void in
            NSLog("Risposta failure per : %@", url)
            self.callbackFailure(error.localizedDescription)
            self.callbackIsComplete(false)
        }
    }
    //MARK: POST
    public func post(_ url : String, andParams params : [String:AnyObject]? = nil) -> URLSessionDataTask? {
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
        case .ApplicationJson, .TextPlain,.ImageJpeg:
            responseSerializer = AFJSONResponseSerializer()
            if readingOption != nil {
                (responseSerializer as! AFJSONResponseSerializer).readingOptions = readingOption!
            }
        case .TextHtml : responseSerializer = AFHTTPResponseSerializer()
        }
        responseSerializer.acceptableContentTypes = Set<String>(arrayLiteral: contentType.rawValue)
        if subContentType != nil {
            responseSerializer.acceptableContentTypes?.insert(subContentType!.rawValue)
        } else {
            responseSerializer.acceptableContentTypes?.insert(LIRequestContentType.TextPlain.rawValue)
        }
        manager.responseSerializer = responseSerializer
        manager.requestSerializer = requestSerializer
        
        NSLog("Nuova chiamata POST : %@", url)
        
        return manager.post(url, parameters: params, progress: nil, success: { (dataTask, responseObject) -> Void in
            if self.contentType == .ApplicationJson || self.contentType == .TextPlain {
                if let obj = responseObject as? [String:AnyObject] {
                    if !(obj["success"] as? Bool ?? true) {
                        debugPrint(obj)
                        if obj["data"] != nil && !(obj["data"]! as? [String:AnyObject] ?? [:]).isEmpty {
                            self.callbackFailure(obj["data"],withErrorMessage:obj["message"] as! String)
                        } else {
                            self.callbackFailure(obj["message"] as! String)
                        }
                    } else {
                        NSLog("Risposta success per : %@", url)
                        let currentCallback = self.callbackName
                        if self.callbackForNextCall {
                            self.callbackForNextCall = false
                            self.callbackName = self.previousCallbackName!
                            self.previousCallbackName = nil
                        }
                        
                        let response = responseObject as! [String:AnyObject]
                        if currentCallback == "" {
                            self.callbackSuccess(response)
                        } else {
                            self.callbackSuccess(response[currentCallback])
                        }
                    }
                } else {
                    self.callbackSuccess(responseObject)
                }
            } else {
                self.callbackSuccess(responseObject)
            }
            if self.contentTypeForNexCall {
                self.contentTypeForNexCall = false
                self.contentType = self.previousContentType!
            }
            self.callbackIsComplete(true)
        }) { (dataTask, error) -> Void in
            NSLog("Risposta failure per : %@", url)
            debugPrint(error)
            self.callbackFailure(error.localizedDescription)
            self.callbackIsComplete(false)
        }
    }
    
    public func post(_ url : String, andImage image : UIImage, withFileName name : String, andParams params : [String:AnyObject]?) -> URLSessionDataTask?{
        return post(url, andImage: image, withFileName: name, andParams: params, andParamsName: nil, uploadProgressBlock: nil)
    }
    
    public func post(_ url : String, andImage image : UIImage, withFileName name : String, andParams params : [String:AnyObject]?, uploadProgressBlock block : (percentage:Progress)->Void) -> URLSessionDataTask?{
        return post(url, andImage: image, withFileName: name, andParams: params, andParamsName: nil, uploadProgressBlock: block)
    }
    
    public func post(_ url : String, andImage image : UIImage, withFileName fileName : String, andParams params : [String:AnyObject]?, andParamsName paramsName : String?, uploadProgressBlock block : ((percentage:Progress)-> Void)?) -> URLSessionDataTask? {
        let imageData = UIImageJPEGRepresentation(image, 0.5)
        return post(url, andData: imageData!,withFileName: fileName,andParams: params,andParamsName: paramsName,uploadProgressBlock: block)
    }
    
    public func post(_ url : String, andData data : Data, withFileName fileName : String, andParams params : [String:AnyObject]?, andParamsName paramsName : String?, uploadProgressBlock block : ((progress : Progress)->Void)?) -> URLSessionDataTask? {
        let requestSerializer = AFHTTPRequestSerializer()
        requestSerializer.setValue(LIRequestContentType.ImageJpeg.rawValue, forHTTPHeaderField: "Content-Type")
        if requestWithLogin {
            requestSerializer.setAuthorizationHeaderFieldWithUsername(loginUsername!, password: loginPassword!)
        }
        if let ua = userAgent {
            requestSerializer.setValue(ua, forHTTPHeaderField: "User-Agent")
        }
        var responseSerializer : AFHTTPResponseSerializer
        switch contentType {
        case .ApplicationJson, .TextPlain, .ImageJpeg: responseSerializer = AFJSONResponseSerializer()
        case .TextHtml: responseSerializer = AFHTTPResponseSerializer()
        }
        responseSerializer.acceptableContentTypes = Set<String>(arrayLiteral:  contentType.rawValue,LIRequestContentType.TextPlain.rawValue)
        manager.responseSerializer = responseSerializer
        manager.requestSerializer = requestSerializer
        
        NSLog("Nuova chiamata POST : %@", url)
        
        return manager.post(url, parameters: params, constructingBodyWith: { (formData) -> Void in
            formData.appendPart(fileData: data, name: paramsName ?? "", fileName: fileName, mimeType: LIRequestContentType.ImageJpeg.rawValue)
            }, progress: { (progress) -> Void in
                DispatchQueue.main.async(execute: {
                    block?(progress: progress)
                })
            }, success: { (dataTask, responseObject) -> Void in
                if responseObject is NSData {
                    if [LIRequestContentType.TextHtml,LIRequestContentType.TextPlain].contains(self.contentType) {
                        self.callbackSuccess(responseObject)
                    } else {
                        self.callbackFailure("found data instead object")
                    }
                } else {
                    let obj = responseObject as! [String:AnyObject]
                    if !(obj["success"] as? Bool ?? true) {
                        self.callbackFailure(obj["message"] as! String)
                    } else {
                        let currentCallback = self.callbackName
                        if self.callbackForNextCall {
                            self.callbackForNextCall = false
                            self.callbackName = self.previousCallbackName!
                            self.previousCallbackName = nil
                        }
                        
                        let response = responseObject as! [String:AnyObject]
                        if currentCallback == "" {
                            self.callbackSuccess(response)
                        } else {
                            self.callbackSuccess(response[currentCallback])
                        }
                    }
                }
                self.callbackIsComplete(true)
        }) { (dataTask, error) -> Void in
            self.callbackFailure(error.localizedDescription)
            self.callbackIsComplete(false)
        }
    }
    //MARK: CALLBACK
    func callbackFailure(_ object : AnyObject?,withErrorMessage errorText : String) {
        
    }
    func callbackFailure(_ errorMessage : String) {
        
    }
    
    func callbackSuccess(_ response : AnyObject?) {
        
    }
    
    func callbackIsComplete(_ state : Bool) {
        
    }
    
    public func abortAllOperation() {
        manager.operationQueue.cancelAllOperations()
    }
}

public class LIRequest : LIRequestBase {
    internal var failureObject : ((object : AnyObject?,errorMessage : String)->Void)? = nil
    internal var success : (response:AnyObject?)->Void = {_ in }
    internal var failure : (errorMessage : String)->Void = {_ in }
    internal var isComplete : ((request : LIRequest, state : Bool)->Void)?
    
    public func setIsComplete(_ isCompleteHandler : (request:LIRequest, state : Bool)->Void) {
        isComplete = isCompleteHandler
    }
    
    public func setSuccess(_ successHandler : (responseObject:AnyObject?)->Void) {
        success = successHandler
    }
    
    public func setFailure(_ failureHandler : (errorMessage : String)->Void) {
        failure = failureHandler
    }
    @available(*,unavailable,renamed: "setFailureWithObject(failureHandler:(object:errorMessage:))")
    public func setFailureWithObject(_ failureHandler : (object : AnyObject?)->Void) {}
    
    public func setFailureWithObject(_ failureHandler : (object : AnyObject?,errorMessage : String)->Void) {
        failureObject = failureHandler
    }
    
    override func callbackIsComplete(_ state : Bool) {
        self.isComplete?(request: self,state: state)
    }
    
    override func callbackFailure(_ errorMessage : String) {
        NSLog("Error call : %@", errorMessage)
        failure(errorMessage: errorMessage)
    }
    
    override func callbackFailure(_ object: AnyObject?,withErrorMessage errorText : String) {
        if failureObject != nil {
            failureObject!(object: object,errorMessage : errorText)
        } else {
            failure(errorMessage: errorText)
        }
    }
    
    override func callbackSuccess(_ response: AnyObject?) {
        success(response: response)
    }
}
