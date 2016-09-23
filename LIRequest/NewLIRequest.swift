//
//  NewLIRequest.swift
//  LIRequest
//
//  Created by Boris Falcinelli on 21/09/16.
//  Copyright © 2016 Boris Falcinelli. All rights reserved.
//

import Foundation

public struct LoginData {
    let username : String
    let password : String
}

public typealias IsCompleteObject = ((_ request:LIRequest,_ state:Bool)->Void)
public typealias FailureObject = ((_ object:Any?,_ error : Error)->Void)
public typealias SuccessObject = ((_ object:Any?,_ message:String?)->Void)
public typealias ValidationResponseObject = ((_ response:Any?)->Bool)
public typealias ProgressObject = ((_ progress : Progress)->Void)


public class LIRequestInstance : NSObject, URLSessionDelegate, URLSessionTaskDelegate,URLSessionDataDelegate {
    
    var contentType : LIRequest.ContentType = .applicationJson
    var callbackName : String = "data"
    var loginData : LoginData? = nil
    var userAgent : String? = nil
    var showNetworkActivityIndicator : Bool = false
    var isCompleteObject : IsCompleteObject?
    var failureObject : FailureObject?
    var successObject : SuccessObject?
    var validationResponseObject : ValidationResponseObject = { response in
        guard let object = response as? [AnyHashable:Any] else { return false }
        guard let success = object["success"] as? Bool else { return false }
        return success
    }
    var progressObject : ProgressObject?
    
    private var listOfCall : [(request : LIRequest, task : URLSessionTask)] = []
    
    func session(delegate : URLSessionDelegate? = nil) -> URLSession {
        if let del = delegate {
            return URLSession(configuration: URLSessionConfiguration.default, delegate: del, delegateQueue: nil)
        }
        return URLSession(configuration: URLSessionConfiguration.default)
    }
    
    func addNewCall(withRequest request : LIRequest, task : URLSessionTask) {
        listOfCall.append((request,task))
    }
    
    static var shared : LIRequestInstance = LIRequestInstance()
    
    private override init() {

    }
    
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        <#code#>
    }
}

public class LIRequest {

    public var contentType : ContentType
    public var callbackName : String
    public var loginData : LoginData?
    public var userAgent : String?
    public var showNetworkActivityIndicator : Bool
    public var isCompleteObject : IsCompleteObject?
    public var failureObject : FailureObject?
    public var successObject : SuccessObject?
    public var progressObject : ProgressObject?
    public var validationResponseObject : ValidationResponseObject
    fileprivate var progress : Progress!
    
    init() {
        self.contentType = LIRequestInstance.shared.contentType
        self.callbackName = LIRequestInstance.shared.callbackName
        self.loginData = LIRequestInstance.shared.loginData
        self.userAgent = LIRequestInstance.shared.userAgent
        self.showNetworkActivityIndicator = LIRequestInstance.shared.showNetworkActivityIndicator
        self.isCompleteObject = LIRequestInstance.shared.isCompleteObject
        self.failureObject = LIRequestInstance.shared.failureObject
        self.successObject = LIRequestInstance.shared.successObject
        self.validationResponseObject = LIRequestInstance.shared.validationResponseObject
        self.progressObject = LIRequestInstance.shared.progressObject
    }
    
    //failureWithObject
    //successWithObject
    //additionalSuccessWithObject
    //failureWithMessage
    //isComplete
    
    /**
     The method used in call
     
     - get
     - post
     */
    public enum Method : String {
        case post = "POST"
        case get = "GET"
    }
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
    }
    
    public func get(toURL url : URL, withParams params : [String:Any]?) {
        self.action(withMethod: .get, toUrl: url, withParams: params)
    }
    
    public func post(toURL url : URL, withParams params : [String:Any]?) {
        self.action(withMethod: .post, toUrl: url, withParams: params)
    }
    
    internal func action(withMethod method:Method, toUrl url : URL, withParams params : [String:Any]?) {
        var request = self.request(forUrl: url)
        if let par = params {
            guard let paramsData = try? JSONSerialization.data(withJSONObject: par, options: .init(rawValue: 0)) else {
                self.failureObject?(nil,self.error(forType: .incorrectParametersToSend,withParameters:par))
                return
            }
            request.httpBody = paramsData
        }
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = self.showNetworkActivityIndicator
        }
        let task = LIRequestInstance.shared.session().dataTask(with: request) { (requestData, response, error) in
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
            guard error == nil else {
                self.failureObject?(requestData,error!)
                self.isCompleteObject?(self,false)
                return
            }
            guard let data = requestData else {
                self.failureObject?(nil, self.error(forType: .noDataInResponse))
                self.isCompleteObject?(self,false)
                return
            }
            
            if self.contentType == .applicationJson || self.contentType == .textPlain {
                guard let objectJSON = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) else {
                    self.failureObject?(data,self.error(forType: .incorrectResponseContentType))
                    self.isCompleteObject?(self,false)
                    return
                }
                guard let object = objectJSON as? [AnyHashable:Any] else {
                    self.failureObject?(data,self.error(forType: .incorrectResponseContentType))
                    self.isCompleteObject?(self,false)
                    return
                }
                guard self.validationResponseObject(object) else {
                    self.failureObject?(object,self.error(forType: .errorInResponse, withErrorString: object["message"] as? String))
                    self.isCompleteObject?(self,false)
                    return
                }
                if self.callbackName.isEmpty {
                    self.successObject?(object,object["message"] as? String)
                } else {
                    self.successObject?(object[self.callbackName],object["message"] as? String)
                }
            } else {
                self.successObject?(data,nil)
                self.isCompleteObject?(self,true)
            }
        }
        LIRequestInstance.shared.addNewCall(withRequest: self, task: task)
    }
    
    
    public func post(toURL url : URL, withImage image : UIImage, andFileName fileName : String, andParamImageName paramImageName : String?, andParams params : [String:Any]?) {
        var request = self.request(forUrl: url)
        request.setValue("multipart/form-data", forHTTPHeaderField: "Content-Type")
        guard let imageData = UIImagePNGRepresentation(image) else {
            self.failureObject?(nil,self.error(forType: .incorrectImageToSend))
            return
        }
        var body = Data()
        let boundary = generateBoundaryString()
        let boundaryData = NSString(string:"--\(boundary)\r\n").data(using: String.Encoding.utf8.rawValue)
        body.append(boundaryData!)
        let contentDispositionData = NSString(string:"Content-Disposition:form-data;name\"test\"\r\n\r\n").data(using: String.Encoding.utf8.rawValue)!
        body.append(contentDispositionData)
        let contentTypeData = NSString(string: "Content-Type:\(ContentType.imageJpeg.rawValue)\r\n\r\n").data(using: String.Encoding.utf8.rawValue)!
        body.append(contentTypeData)
        body.append(imageData)
        let endData = NSString(string: "\r\n").data(using: String.Encoding.utf8.rawValue)!
        body.append(endData)
        let endBoundaryData = NSString(string:"--\(boundary)--\r\n").data(using: String.Encoding.utf8.rawValue)!
        body.append(endBoundaryData)
        request.httpBody = body
        
        
        let task = LIRequestInstance.shared.session().uploadTask(with: request, from: imageData) { (data, _, error) in
            
        }
        
        LIRequestInstance.shared.addNewCall(withRequest: self, task: task)
    }
    
    private func request(forUrl url : URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.addValue(self.contentType.rawValue, forHTTPHeaderField: "Content-Type")
        request.addValue(self.contentType.rawValue, forHTTPHeaderField: "Accept")
        if let ua = userAgent {
            request.addValue(ua, forHTTPHeaderField: "User-Agent")
        }
        if let ld = loginData {
            let userString = NSString(format:"%@:%@",ld.username,ld.password)
            let authData = userString.data(using: String.Encoding.utf8.rawValue)
            let base64EncodedCredential = authData!.base64EncodedData()
            let authString = "Basic \(base64EncodedCredential)"
            request.addValue(authString, forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    private func generateBoundaryString() -> String{
        return "Boundary-\(NSUUID().uuidString)"
    }
}

//MARK:gestione degli errori NON UTILIZZATA
extension LIRequest {
    internal enum ErrorType : Int, LocalizedError {
        case invalidUrl = 400
        case errorInResponse = 406
        case noDataInResponse = 407
        case incorrectResponseContentType = 500
        case incorrectParametersToSend = 600
        case incorrectImageToSend = -145
        
        internal var errorDescription: String? {
            switch self {
            default:
                return NSLocalizedString("ErrorCall", comment: "")
            }
        }
        
        var failureReason: String? {
            switch self {
            case .invalidUrl:
                return NSLocalizedString("ErrorInvalidUrl", comment: "")
            case .errorInResponse:
                return NSLocalizedString("ErrorInResponse", comment: "")
            case .noDataInResponse:
                return NSLocalizedString("ErrorNoDataInResponse", comment: "")
            case .incorrectResponseContentType:
                return NSLocalizedString("ErrorIncorrectContentType", comment: "")
            case .incorrectParametersToSend:
                return NSLocalizedString("ErrorIncorrectParametersToSend", comment: "")
            case .incorrectImageToSend:
                return NSLocalizedString("ErrorIncorrectImageToSend", comment: "")
            }
        }
        
        internal var recoverySuggestion: String? {
            switch self {
            case .invalidUrl:
                return NSLocalizedString("ErrorInvalidUrlSuggestion", comment: "")
            case .incorrectParametersToSend:
                fallthrough
            case .noDataInResponse:
                fallthrough
            case .incorrectResponseContentType:
                fallthrough
            case .errorInResponse:
                return nil
            }
        }
    }
    
    internal func error(forType type : ErrorType,
                       withUrlString url:String?=nil,
                       withErrorString string : String? = nil,
                       withParameters params : [AnyHashable:Any]? = nil) -> Error {
        
        let domain = "net.labinfo.LIRequest"
        var userInfo : [AnyHashable:Any] = [NSLocalizedDescriptionKey:type.errorDescription,
                                            NSLocalizedFailureReasonErrorKey:type.failureReason,
                                            NSLocalizedRecoverySuggestionErrorKey:type.recoverySuggestion]
        switch type {
        case .invalidUrl:
            if let u = url {
                userInfo[NSLocalizedFailureReasonErrorKey] = "\(type.failureReason ?? "") : \(u)"
            }
        case .errorInResponse:
            if let e = string {
                userInfo[NSLocalizedDescriptionKey] = e
            }
        case .incorrectParametersToSend:
            if let p = params {
                userInfo[NSLocalizedFailureReasonErrorKey] = "\(type.failureReason ?? "") : \(p)"
            }
        default:
            break
        }
        let error = NSError(domain: domain, code: type.rawValue, userInfo: userInfo)
        return error
    }
}
