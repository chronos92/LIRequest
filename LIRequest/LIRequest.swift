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
    case TextPlain = "text/plain"
    case ApplicationJson = "application/json"
    case TextHtml = "text/html"
    case ImageJpeg = "image/jpeg"
}

public class LIRequestBase {
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
    private var manager : AFHTTPSessionManager = AFHTTPSessionManager()
    private var readingOption : NSJSONReadingOptions? = nil
    //MARK: INIT & SET
    public init(contentType ct : LIRequestContentType, callbackName cn : String = "data") {
        contentType = ct
        callbackName = cn
    }
    
    public func setCallbackNameForNextCall(callback : String) {
        callbackForNextCall = true
        previousCallbackName = callbackName
        callbackName = callback
    }
    
    public func setContentTypeForNextCall(contentType : LIRequestContentType, subContentType sub : LIRequestContentType? = nil, readingOption : NSJSONReadingOptions? = nil) {
        self.subContentType = sub
        self.readingOption = readingOption
        contentTypeForNexCall = true
        previousContentType = self.contentType
        self.contentType = contentType
    }
    
    public func setLoginUsername(username : String, andLoginPassword password : String) {
        requestWithLogin = true
        loginUsername = username
        loginPassword = password
    }
    //MARK: GET
    public func get(url : String, andParams params : [String: AnyObject]? = nil) {
        let requestSerializer = AFHTTPRequestSerializer()
        if requestWithLogin {
            requestSerializer.setAuthorizationHeaderFieldWithUsername(self.loginUsername!, password: self.loginPassword!)
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
        manager.GET(url, parameters: params, progress: nil, success: { (dataTask, responseObject) -> Void in
            NSLog("Risposta success per : %@", url)
            if self.contentType == .ApplicationJson || self.contentType == .TextPlain {
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
            } else {
                self.callbackSuccess(responseObject)
            }
            if self.contentTypeForNexCall {
                self.contentTypeForNexCall = false
                self.contentType = self.previousContentType!
            }
            }) { (dataTask, error) -> Void in
                NSLog("Risposta failure per : %@", url)
                self.callbackFailure(error.localizedDescription)
        }
    }
    //MARK: POST
    public func post(url : String, andParams params : [String:AnyObject]? = nil) {
        let requestSerializer = AFHTTPRequestSerializer()
        if params != nil {
        let data = try! NSJSONSerialization.dataWithJSONObject(params!, options: NSJSONWritingOptions.PrettyPrinted)
         NSLog("%@",String(data: data, encoding: NSUTF8StringEncoding)!)
        }
        if requestWithLogin {
            requestSerializer.setAuthorizationHeaderFieldWithUsername(self.loginUsername!, password: self.loginPassword!)
        }
        var responseSerializer : AFHTTPResponseSerializer
        switch contentType {
        case .ApplicationJson, .TextPlain,.ImageJpeg: responseSerializer = AFJSONResponseSerializer()
        case .TextHtml : responseSerializer = AFHTTPResponseSerializer()
        }
        responseSerializer.acceptableContentTypes = Set<String>(arrayLiteral: contentType.rawValue,LIRequestContentType.TextHtml.rawValue)
        manager.responseSerializer = responseSerializer
        manager.requestSerializer = requestSerializer
        
        NSLog("Nuova chiamata POST : %@", url)
        
        manager.POST(url, parameters: params, progress: nil, success: { (dataTask, responseObject) -> Void in
            if self.contentType == .ApplicationJson || self.contentType == .TextPlain {
                if let obj = responseObject as? [String:AnyObject] {
                    if !(obj["success"] as? Bool ?? true) {
                        self.callbackFailure(obj["message"] as! String)
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
                    self.callbackSuccess(nil)
                }
            } else {
                self.callbackSuccess(responseObject)
            }
            if self.contentTypeForNexCall {
                self.contentTypeForNexCall = false
                self.contentType = self.previousContentType!
            }
            }) { (dataTask, error) -> Void in
                NSLog("Risposta failure per : %@", url)
                self.callbackFailure(error.localizedDescription)
        }
    }
    
    public func post(url : String, andImage image : UIImage, withFileName name : String, andParams params : [String:AnyObject]?) {
        post(url, andImage: image, withFileName: name, andParams: params, andParamsName: nil, uploadProgressBlock: nil)
    }
    
    public func post(url : String, andImage image : UIImage, withFileName name : String, andParams params : [String:AnyObject]?, uploadProgressBlock block : (percentage:Double)->Void) {
        post(url, andImage: image, withFileName: name, andParams: params, andParamsName: nil, uploadProgressBlock: block)
    }
    
    public func post(url : String, andImage image : UIImage, withFileName fileName : String, andParams params : [String:AnyObject]?, andParamsName paramsName : String?, uploadProgressBlock block : ((percentage:Double)-> Void)?) {
        let imageData = UIImageJPEGRepresentation(image, 0.5)
        let requestSerializer = AFHTTPRequestSerializer()
        requestSerializer.setValue(LIRequestContentType.ImageJpeg.rawValue, forHTTPHeaderField: "Content-Type")
        if requestWithLogin {
            requestSerializer.setAuthorizationHeaderFieldWithUsername(loginUsername!, password: loginPassword!)
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
        
        manager.POST(url, parameters: params, constructingBodyWithBlock: { (formData) -> Void in
            formData.appendPartWithFileData(imageData!, name: paramsName ?? "", fileName: fileName, mimeType: LIRequestContentType.ImageJpeg.rawValue)
            }, progress: { (progress) -> Void in
                    block?(percentage: progress.fractionCompleted)
            }, success: { (dataTask, responseObject) -> Void in
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
            }) { (dataTask, error) -> Void in
                self.callbackFailure(error.localizedDescription)
        }
        
    }
    //MARK: CALLBACK
    func callbackFailure(errorMessage : String) {
        
    }
    
    func callbackSuccess(response : AnyObject?) {
        
    }
    
    public func abortAllOperation() {
        manager.operationQueue.cancelAllOperations()
    }
    
}

public class LIRequest : LIRequestBase {
    private var success : (response:AnyObject?)->Void = {_ in }
    private var failure : (errorMessage : String)->Void = {_ in }
    
    
    public func setSuccess(successHandler : (responseObject:AnyObject?)->Void) {
        success = successHandler
    }
    
    public func setFailure(failureHandler : (errorMessage : String)->Void) {
        failure = failureHandler
    }
    
    override func callbackFailure(errorMessage : String) {
        NSLog("Error call : %@", errorMessage)
        failure(errorMessage: errorMessage)
    }
    
    override func callbackSuccess(response: AnyObject?) {
        success(response: response)
    }
}