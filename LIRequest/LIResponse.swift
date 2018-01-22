//
//  LIResponse.swift
//  LIRequest
//
//  Created by Boris Falcinelli on 16/01/18.
//  Copyright © 2018 Boris Falcinelli. All rights reserved.
//

import Foundation

public class LIResponse : Equatable {
    
    public enum StatusType : Int {
        case unknown = 0
        case ok = 200
        case create = 201
        case Accepted = 202
        case nonAuthoritativeInformation = 203
        case noContent = 204
        case movedPermanently = 301
        case found = 302
        case notModified = 304
        case useProxy = 305
        case temporaryRedirect = 307
        case badRequest = 400
        case notAuthorized = 401
        case paymentRequired = 402
        case forbidden = 403
        case notFound = 404
        case methodNotAllowed = 405
        case notAcceptable = 406
        case proxyAuthenticationRequired = 407
        case requestTimeout = 408
        case conflict = 409
        case gone = 410
        case lengthRequired = 411
        case preconditionFailed = 412
        case internalServerError = 500
        case notImplemented = 501
        case badGateway = 502
        case serviceUnavailable = 503
        case gatewayTimeout = 504
        case httpVersionNotSupported = 505
        
    }
    
    public static func ==(lhs: LIResponse, rhs: LIResponse) -> Bool {
        return lhs.uniqueIdentifier == rhs.uniqueIdentifier
    }
    
    let uniqueIdentifier : String = NSUUID().uuidString
    let url : URL!
    fileprivate(set) var mimeType : MimeType?
    fileprivate(set) var status : StatusType = .unknown
    fileprivate(set) var headerFields : [AnyHashable:Any]?
    
    init(response : URLResponse) {
        url = response.url
        if let m = response.mimeType {
            mimeType = MimeType(mimeText: m)
        }
    }
    
    convenience init(response : HTTPURLResponse) {
        self.init(response: response as! URLResponse)
        status = StatusType(rawValue: response.statusCode) ?? .unknown
        headerFields = response.allHeaderFields
    }
}

extension LIResponse : CustomDebugStringConvertible {
    public var debugDescription: String {
        var string = """
        {
            Url : \(self.url.debugDescription),
            UUID : \(self.uniqueIdentifier.debugDescription),
            Status : \(self.status.rawValue.description),
            Mime Type : \(self.mimeType?.text ?? "nil"),
        """
        
        
        if let hf = headerFields {
            string += "     Header Fields : [\n"+hf.keys.map({return "         \($0) : \(hf[$0] ?? "nil")"}).joined(separator: "\n")+"     ]\n"
        }
        else {
            string += "     Header Fields : nil\n"
        }
        
        string += "}\n"
        return string
    }
    
    
}

