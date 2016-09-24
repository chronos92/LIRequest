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


public class LIRequestInstance : NSObject, URLSessionDelegate, URLSessionTaskDelegate,URLSessionDataDelegate,URLSessionDownloadDelegate {

    
    
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
    
    private var listOfCall : [URLSessionTask] = []
    private var requestForTask : [Int:LIRequest]
    
    func session(delegate : URLSessionDelegate? = nil) -> URLSession {
        if let del = delegate {
            return URLSession(configuration: URLSessionConfiguration.default, delegate: del, delegateQueue: nil)
        }
        return URLSession(configuration: URLSessionConfiguration.default)
    }
    
    func addNewCall(withTash task : URLSessionTask, andRequest request: LIRequest) {
        requestForTask[task.taskIdentifier] = request
        listOfCall.append(task)
    }
    
    static var shared : LIRequestInstance = LIRequestInstance()
    
    private override init() {

    }
    
    
    
    //per chiamate post e get
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        debugprint("Content size - \(downloadTask.response.expectedContentLength)")

        if let request = requestForTask[downloadTask.taskIdentifier] {
            if let progressObject = request.progressObject {
                if request.progress == nil {
                    request.progress = Progress(totalUnitCount: totalBytesExpectedToWrite)
                }
                request.progress.completedUnitCount = totalBytesWritten
                progressObject(request.progress)
            }
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        self.hideNetworkActivity()
        guard let request = requestForTask[downloadTask.taskIdentifier] else { return }
        guard let data = try? Data(contentsOf: location) else {
            self.urlSession(session, task: task, didCompleteWithError: LIRequestError(forType: .noDataInResponse))
            return
        }
        if [.applicationJson,.textPlain].contains(request.contentType) {
            guard let objectJSON = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) else {
                self.urlSession(session, task: downloadTask, didCompleteWithError: LIRequestError(forType: .incorrectResponseContentType,withUrlString:downloadTask.currentRequest?.url?.absoluteString))
                return
            }
            guard let object = objectJSON as? [AnyHashable:Any] else {
                self.urlSession(session, task: downloadTask, didCompleteWithError: LIRequestError(forType: .incorrectResponseContentType,withUrlString:downloadTask.currentRequest?.url?.absoluteString))
                return
            }
            guard request.validationResponseObject(object) else {
                self.urlSession(session, task: task, didCompleteWithError: LIRequestError(forType: .errorInResponse, withUrlString: downloadTask.currentRequest?.url?.absoluteString))
                return
            }
            if request.callbackName.isEmpty {
                request.successObject?(object,object["message"] as? String)
            } else {
                request.successObject?(object[request.callbackName],object["message"] as? String)
            }
            request.isCompleteObject?(request,true)
        } else {
            request.successObject?(data,nil)
            request.isCompleteObject?(request,true)
        }
    }
    
    //per chiamate con upload
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        if let request = requestForTask[task.taskIdentifier] {
            if let progressObject = request.progressObject {
            if request.progress == nil {
                request.progress = Progress(totalUnitCount: totalBytesExpectedToSend)
            }
            request.progress.completedUnitCount = bytesSent
            progressObject(request.progress)
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.hideNetworkActivity()
        guard let request = requestForTask[task.taskIdentifier] else { return }
        if let currentError = error {
            request.failureObject?(nil,currentError)
            request.isCompleteObject?(request,false)
        } else {
            request.successObject?(nil,nil)
            request.isCompleteObject?(request,true)
        }
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(URLSession.ResponseDisposition.allow)
    }
    
    
    private func hideNetworkActivity() {
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }
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
        let task = LIRequestInstance.shared.session().downloadTask(with: request)
        LIRequestInstance.shared.addNewCall(withTash: task, andRequest: self)
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
        
        let task = LIRequestInstance.shared.session().uploadTask(with: request, from: imageData)
        
        
        LIRequestInstance.shared.addNewCall(withTash: task, andRequest: self)
    }
    
    private func request(forUrl url : URL,withMethod method : Method) -> URLRequest {
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


class LIRequestError : NSError {
    /**
     Definisce il tipo di errore possibile in LIRequest.
     Per ogni tipo di errore definisce la descrizione dell'errore, il motivo per cui si è verificato l'errore ed un eventuale metodo di risoluzione
     
     - invalidUrl
     - errorInResponse
     - noDataInResponse
     - incorrectResponseContentType
     - incorrectParametersToSend
     - incorrectImageToSend
     */
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
    
    init(forType type : ErrorType,
        withUrlString url:String?=nil,
        withErrorString string : String? = nil,
        withParameters params : [AnyHashable:Any]? = nil) {
        let domain = "net.labinfo.LIRequest"
        let code = type.rawValue
        var userInfo : [AnyHashable:Any] = [NSLocalizedDescriptionKey:type.errorDescription,
                                            NSLocalizedFailureReasonErrorKey:type.failureReason,
                                            NSLocalizedRecoverySuggestionErrorKey:type.recoverySuggestion]
        if let u = url {
            userInfo["LIRequestURL"] = u
        }
        if let e = string {
            userInfo[NSLocalizedDescriptionKey] = e
        }
        if let p = params {
            userInfo["LIRequestParametersCausedError"] = "\(type.failureReason ?? "") : \(p)"
        }
        super.init(domain: domain, code: code, userInfo: userInfo)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
