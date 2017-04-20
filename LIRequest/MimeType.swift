//
//  MimeTypes.swift
//  LIRequest
//
//  Created by Boris Falcinelli on 20/10/16.
//  Copyright © 2016 Boris Falcinelli. All rights reserved.
//

import Foundation

public class MimeType {
    public var type : TypeObject
    public var subtype : SubtypeObject
    
    var text : String {
        return "\(type.rawValue)/\(subtype.rawValue)"
    }
    
    public enum TypeObject : String {
        case application = "application"
        case audio = "audio"
        case image = "image"
        case text = "text"
//        case example = "example"
//        case font = "font"
//        case message = "message"
//        case model = "model"
        case multipart = "multipart"
        case video = "video"
    }
    public enum SubtypeObject : String {
        case all = "*"
        //application
        case javascript = "javascript"
        case json = "json"
        case xWwwFormUrlencoded = "x-www-form-urlencoded"
        case xml = "xml"
        case zip = "zip"
        case pdf = "pdf"
        case octetStream = "octet-stream"
        case java = "java"
        case mspowerpoint = "mspowerpoint"
        case powerpoint = "powerpoint"
        case vndMsPowerpoint = "vnd.ms-powerpoint"
        case xMspowerpoint = "x-mspowerpoint"
        case rtf = "rtf"
        case excel = "excel"
        case vndMsExcel = "vnd.ms-excel"
        case xExcel = "x-excel"
        //audio
        case mpeg = "mpeg"
        case vorbis = "vorbis"
        case midi = "midi"
        case wav = "wav"
        //video
        case avi = "avi"
        //multipart
        case formData = "form-data"
        //text
        case css = "css"
        case html = "html"
        case plain = "plain"
        case asp = "asp"
        case richtext = "richtext"
        
        //image
        case png = "png"
        case jpeg = "jpeg"
        case gif = "gif"
        case bmp = "bmp"
    }
    
    public init(mimeText:String) {
        let comps = mimeText.components(separatedBy: "/")
        let typeName = comps.first ?? TypeObject.text.rawValue
        let subtypeName = comps.last ?? "*"
        
        self.type = TypeObject(rawValue: typeName) ?? .text
        self.subtype = SubtypeObject(rawValue: subtypeName) ?? .all
    }
    
    public init(type : TypeObject, subtype : SubtypeObject) {
        self.type = type
        self.subtype = subtype
    }
}
