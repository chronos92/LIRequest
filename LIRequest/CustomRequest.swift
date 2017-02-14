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
        self.accept = .imageJpeg
    }
    
    public func setImageSuccess(withObject object : @escaping ImageSuccessObject) {
        LIPrint("Set success image block")
        self.imageSuccess = object
    }
    
    override func callSuccess(withObject object: Any?, andMessage message: String?) {
        if let imageObject = self.imageSuccess, let data = object as? Data, let image = UIImage(data:data)  {
            LIPrint("Call success image block")
            imageObject(image, message)
        }
        else {
            LIPrint("Success image block not set, call success block")
            super.callSuccess(withObject: object, andMessage: message)
        }
    }
    
    @available(*,unavailable,renamed: "setImageSuccess(withObject:)")
    public override func setSuccess(overrideDefault override: Bool, withObject object: @escaping SuccessObject) {}
    @available(*,unavailable,renamed: "setImageSuccess(withObject:)")
    public override func addSuccess(withObject object: @escaping SuccessObject) {}
}

public class LIZipRequest : LIRequest {
    
    internal var zipSuccess : ZipSuccessObject?
    
    public override init() {
        super.init()
        self.accept = .applicationZip
    }
    
    public func setZipSuccess(withObject object : @escaping ZipSuccessObject) {
        LIPrint("Set success zip block")
        self.zipSuccess = object
    }
    
    override func callSuccess(withObject object: Any?, andMessage message: String?) {
        if let zip = self.zipSuccess, let dataObject = object as? URL {
            LIPrint("Call success zip block")
            zip(dataObject, message)
        } else {
            LIPrint("Success zip block not set, call success block")
            super.callSuccess(withObject: object, andMessage: message)
        }
    }
    @available(*,unavailable,renamed: "setZipSuccess(withObject:)")
    public override func setSuccess(overrideDefault override: Bool, withObject object: @escaping SuccessObject) {}
    @available(*,unavailable,renamed: "setZipSuccess(withObject:)")
    public override func addSuccess(withObject object: @escaping SuccessObject) {}
}

public class LIJSONRequest : LIRequest {
    internal var jsonSuccess : JSONSuccessObject?
    
    public override init() {
        super.init()
        self.accept = .applicationJson
    }
    
    public func setJSONSuccess(withObject object : @escaping JSONSuccessObject) {
        LIPrint("Set success JSON block")
        self.jsonSuccess = object
    }
    
    override func callSuccess(withObject object: Any?, andMessage message: String?) {
        if let json = self.jsonSuccess, let jsonObject = object as? [AnyHashable:Any] {
            LIPrint("Call success JSON block")
            json(jsonObject, message)
        }
        else {
            LIPrint("Success json block not set, call success block")
            super.callSuccess(withObject: object, andMessage: message)
        }
    }
    
    @available(*,unavailable,renamed: "setJSONSuccess(withObject:)")
    public override func setSuccess(overrideDefault override: Bool, withObject object: @escaping SuccessObject) {}
    @available(*,unavailable,renamed: "setJSONSuccess(withObject:)")
    public override func addSuccess(withObject object: @escaping SuccessObject) {}
}
