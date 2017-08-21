//
//  ZipLIRequest.swift
//  LIRequest
//
//  Created by Boris Falcinelli on 09/01/17.
//  Copyright © 2017 Boris Falcinelli. All rights reserved.
//

import Foundation
import UIKit

public class LIImageRequest : LIRequest {
    
    internal var imageSuccess : ImageSuccessObject?
    
    public override init() {
        super.init()
        self.accept = MimeType(type: .image, subtype: .jpeg)
    }
    
    public func setImageSuccess(withObject object : @escaping ImageSuccessObject) {
        LIPrint("Set success image block")
        self.imageSuccess = object
    }
    
    override func callSuccess(withObject object: Any?, andMessage message: String?) {
        if let imageObject = self.imageSuccess, let data = object as? Data, let image = UIImage(data:data)  {
            LIPrint("Call success image block")
            imageObject(self,image, message)
        }
        else {
            LIPrint("Success image block not set")
        }
    }
    
    @available(*,unavailable,renamed: "setImageSuccess(withObject:)")
    public override func setSuccess(overrideDefault override: Bool, withObject object: @escaping SuccessObject) {}
    @available(*,unavailable,renamed: "setImageSuccess(withObject:)")
    public override func addSuccess(withObject object: @escaping SuccessObject) {}
}

public class LIDownloadRequest : LIRequest {
    internal var downloadSuccess : DownloadSuccessObject?
    internal var validationObject: DownloadValidationResponseObject?
    
    public override init() {
        super.init()
        self.accept = MimeType(type: .application, subtype: .octetStream)
    }
    
    public func setValidation(overrideDefault override: Bool, withObject object: @escaping DownloadValidationResponseObject) {
        self.validationObject = object
    }
    
    public func setDownloadSuccess(withObject object : @escaping DownloadSuccessObject) {
        LIPrint("Set success download block")
        self.downloadSuccess = object
    }
    
    override func callSuccess(withObject object: Any?, andMessage message: String?) {
        let temporaryUrl = object as? URL
        if let download = self.downloadSuccess, temporaryUrl != nil {
            LIPrint("Call success download block")
            self.successCalled = true
            download(self,temporaryUrl!, message)
        }
        else {
            LIPrint("Success download block not set")
        }
    }
    @available(*,unavailable,renamed: "setValidation(overrideDefault:withObject:)")
    public override func setValidation(overrideDefault override: Bool, withObject object: @escaping ValidationResponseObject) {}
    @available(*,unavailable,renamed: "setZipSuccess(withObject:)")
    public override func setSuccess(overrideDefault override: Bool, withObject object: @escaping SuccessObject) {}
    @available(*,unavailable,renamed: "setZipSuccess(withObject:)")
    public override func addSuccess(withObject object: @escaping SuccessObject) {}

}

public class LIJSONRequest : LIRequest {
    internal var jsonSuccess : JSONSuccessObject?
    
    public override init() {
        super.init()
        self.accept = MimeType(type: .application, subtype: .json)
        self.contentType = MimeType(type: .application, subtype: .xWwwFormUrlencoded)
    }
    
    public func setJSONSuccess(withObject object : @escaping JSONSuccessObject) {
        LIPrint("Set success JSON block")
        self.jsonSuccess = object
    }
    
    override func callSuccess(withObject object: Any?, andMessage message: String?) {
        if let json = self.jsonSuccess {
            LIPrint("Call success JSON block")
            json(self,object as? [AnyHashable:Any] ?? [:], message)
        }
        else {
            LIPrint("Success json block not set")
        }
    }
    
    @available(*,unavailable,renamed: "setJSONSuccess(withObject:)")
    public override func setSuccess(overrideDefault override: Bool, withObject object: @escaping SuccessObject) {}
    @available(*,unavailable,renamed: "setJSONSuccess(withObject:)")
    public override func addSuccess(withObject object: @escaping SuccessObject) {}
}


@available(*,deprecated: 10.0,renamed:"LIDownloadRequest")
public class LIZipRequest : LIRequest {
    
    internal var zipSuccess : ZipSuccessObject?
    internal var validationObject : ZipValidationResponseObject?
    
    public override init() {
        super.init()
        self.accept = MimeType(type: .application, subtype: .zip)
    }
    
    public func setValidation(overrideDefault override: Bool, withObject object: @escaping ZipValidationResponseObject) {
        self.validationObject = object
    }
    
    public func setZipSuccess(withObject object : @escaping ZipSuccessObject) {
        LIPrint("Set success zip block")
        self.zipSuccess = object
    }
    
    override func callSuccess(withObject object: Any?, andMessage message: String?) {
        let dataObject = object as? URL
        if let zip = self.zipSuccess, dataObject != nil {
            LIPrint("Call success zip block")
            self.successCalled = true
            zip(self,dataObject!, message)
        } else {
            LIPrint("Success zip block not set")
        }
    }
    
    @available(*,unavailable,renamed: "setValidation(overrideDefault:withObject:)")
    public override func setValidation(overrideDefault override: Bool, withObject object: @escaping ValidationResponseObject) {}
    @available(*,unavailable,renamed: "setZipSuccess(withObject:)")
    public override func setSuccess(overrideDefault override: Bool, withObject object: @escaping SuccessObject) {}
    @available(*,unavailable,renamed: "setZipSuccess(withObject:)")
    public override func addSuccess(withObject object: @escaping SuccessObject) {}
}
