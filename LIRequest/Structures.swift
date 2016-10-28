//
//  Structures.swift
//  LIRequest
//
//  Created by Boris Falcinelli on 20/10/16.
//  Copyright © 2016 Boris Falcinelli. All rights reserved.
//

import Foundation

public extension LIRequest {
    
    /// Specifica il metodo utilizzato per la chiamata
    ///
    /// - post: Il protocollo POST passa le coppie nome-valore nel corpo del messaggio di richiesta HTTP.
    /// - get:  Il protocollo GET crea una stringa di query delle coppie nome-valore e quindi aggiunge la stringa di query all'URL
    public enum Method : String {
        case post = "POST"
        case get = "GET"
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

        let key : String
        init(key k : String) {
            key = k
        }
        
        static let textPlain = Accept(key: "text/plain")
        static let textHtml = Accept(key: "text/html")
        static let textCss = Accept(key: "text/css")
        static let textCsv = Accept(key: "text/csv")
        
        static let applicationJson = Accept(key: "application/json")
        static let applicationOctetStream = Accept(key: "application/octet-stream")
        static let applicationFormUrlencoded = Accept(key: "application/x-www-form-urlencoded")
        static let applicationPdf = Accept(key: "application/pdf")
        
        static let imageJpeg = Accept(key: "image/jpeg")
        static let imageBmp = Accept(key: "image/bmp")
        static let imageGif = Accept(key: "image/gif")
    }
}
