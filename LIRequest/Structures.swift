//
//  Structures.swift
//  LIRequest
//
//  Created by Boris Falcinelli on 20/10/16.
//  Copyright © 2016 Boris Falcinelli. All rights reserved.
//

import Foundation

internal func LIPrint(_ text : String) {
    if LIRequestInstance.shared.testEnable {
        debugPrint(String(format: "[LIRequest] %@", text))
    }
}

public extension LIRequest {
    
    /// Specifica il metodo utilizzato per la chiamata
    ///
    /// - post: Il protocollo POST passa le coppie nome-valore nel corpo del messaggio di richiesta HTTP.
    /// - get:  Il protocollo GET crea una stringa di query delle coppie nome-valore e quindi aggiunge la stringa di query all'URL
    public enum Method : String {
        case post = "POST"
        case get = "GET"
        case delete = "DELETE"
        case put = "PUT"
    }
    
    /// Specifica il Content-Type impostato nella richiesta
    ///
    /// - text/plain
    /// - text/html
    /// - text/css
    /// - text/csv
    ///
    /// - application/json
    /// - application/octet-stream
    /// - application/x-www-form-urlencoded
    /// - application/pdf
    ///
    /// - image/jpeg
    /// - image/bmp
    /// - image/gif
    ///
    /// - multipart/form-data
    public class ContentType : Equatable {
        /// Returns a Boolean value indicating whether two values are equal.
        ///
        /// Equality is the inverse of inequality. For any values `a` and `b`,
        /// `a == b` implies that `a != b` is `false`.
        ///
        /// - Parameters:
        ///   - lhs: A value to compare.
        ///   - rhs: Another value to compare.
        public static func ==(lhs: LIRequest.ContentType, rhs: LIRequest.ContentType) -> Bool {
            return lhs.key == rhs.key
        }
        
        public let key : String
        public init(key k : String) {
            key = k
        }
        public static let textPlain = ContentType(key: "text/plain")
        public static let textHtml = ContentType(key: "text/html")
        public static let textCss = ContentType(key: "text/css")
        public static let textCsv = ContentType(key: "text/csv")
        
        public static let applicationJson = ContentType(key: "application/json")
        public static let applicationOctetStream = ContentType(key: "application/octet-stream")
        public static let applicationFormUrlencoded = ContentType(key: "application/x-www-form-urlencoded")
        public static let applicationPdf = ContentType(key: "application/pdf")
        
        public static let imageJpeg = ContentType(key: "image/jpeg")
        public static let imageBmp = ContentType(key: "image/bmp")
        public static let imageGif = ContentType(key: "image/gif")
        
        
        static let multipartFormData = ContentType(key: "multipart/form-data")
        
    }
    
    /// Specifica l' Accept impostato nella richiesta
    ///
    /// - text/plain
    /// - text/html
    /// - text/css
    /// - text/csv
    ///
    /// - application/json
    /// - application/octet-stream
    /// - application/x-www-form-urlencoded
    /// - application/pdf
    /// - application/zip
    ///
    /// - image/jpeg
    /// - image/bmp
    /// - image/gif
    ///
    /// - multipart/form-data
    public class Accept :Equatable {
        /// Returns a Boolean value indicating whether two values are equal.
        ///
        /// Equality is the inverse of inequality. For any values `a` and `b`,
        /// `a == b` implies that `a != b` is `false`.
        ///
        /// - Parameters:
        ///   - lhs: A value to compare.
        ///   - rhs: Another value to compare.
        public static func ==(lhs: LIRequest.Accept, rhs: LIRequest.Accept) -> Bool {
            return lhs.key == rhs.key
        }
        
        var key : String {
            return "\(typeName)/\(subtypeName)"
        }
        internal(set) var typeName: PrimaryTypeList
        internal var subtypeName: String
        init(key k : String) {
            let comps = k.components(separatedBy: "/")
            if let first = comps.first {
                typeName = PrimaryTypeList(rawValue: first) ?? .all
            }
            else {
                typeName = .all
            }
            if comps.count > 1 {
                subtypeName = (comps[1] != "" && comps[1] != "-") ? comps[1] : "*"
            }
            else {
                subtypeName = "*"
            }
            
        }
        
        public class text {
            public static let plain = Accept(key: "text/plain")
            public static let html = Accept(key: "text/html")
            public static let css = Accept(key: "text/css")
            public static let csv = Accept(key: "text/csv")
        }
        public class application {
            public static let json = Accept(key: "application/json")
            public static let octetStream = Accept(key: "application/octet-stream")
            public static let formUrlencoded = Accept(key: "application/x-www-form-urlencoded")
            public static let pdf = Accept(key: "application/pdf")
            public static let zip = Accept(key: "application/zip")
        }
        public class image {
            public static let jpeg = Accept(key: "image/jpeg")
            public static let bmp = Accept(key: "image/bmp")
            public static let gif = Accept(key: "image/gif")
        }
        
        enum PrimaryTypeList : String {
            case text = "text"
            case application = "application"
            case image = "image"
            case all = "*"
        }
        
        @available(*,unavailable,renamed: "text.plain")
        public static let textPlain = Accept(key: "text/plain")
        @available(*,unavailable,renamed: "text.html")
        public static let textHtml = Accept(key: "text/html")
        @available(*,unavailable,renamed: "text.css")
        public static let textCss = Accept(key: "text/css")
        @available(*,unavailable,renamed: "text.csv")
        public static let textCsv = Accept(key: "text/csv")
        
        @available(*,unavailable,renamed: "application.json")
        public static let applicationJson = Accept(key: "application/json")
        @available(*,unavailable,renamed: "application.octetStream")
        public static let applicationOctetStream = Accept(key: "application/octet-stream")
        @available(*,unavailable,renamed: "application.formUrlencoded")
        public static let applicationFormUrlencoded = Accept(key: "application/x-www-form-urlencoded")
        @available(*,unavailable,renamed: "application.pdf")
        public static let applicationPdf = Accept(key: "application/pdf")
        @available(*,unavailable,renamed: "application.zip")
        public static let applicationZip = Accept(key: "application/zip")
        
        @available(*,unavailable,renamed: "image.jpeg")
        public static let imageJpeg = Accept(key: "image/jpeg")
        @available(*,unavailable,renamed: "image.bmp")
        public static let imageBmp = Accept(key: "image/bmp")
        @available(*,unavailable,renamed: "image.gif")
        public static let imageGif = Accept(key: "image/gif")
    }
}

func == (lhs:URLSessionTask, rhs:URLSessionTask) -> Bool {
    return lhs.originalRequest == rhs.originalRequest
}
