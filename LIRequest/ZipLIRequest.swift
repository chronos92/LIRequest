//
//  ZipLIRequest.swift
//  LIRequest
//
//  Created by Boris Falcinelli on 09/01/17.
//  Copyright © 2017 Boris Falcinelli. All rights reserved.
//

import Foundation
import UIKit

public class LIZipRequest : LIRequest {
    
    internal var zipSuccess : ZipSuccessObject?
    
    override init() {
        super.init()
        self.accept = .applicationZip
    }
    
    public func setZipSuccess(withObject object : @escaping ZipSuccessObject) {
        LIPrint("Set success zip block")
        self.zipSuccess = object
    }
    
    override func callSuccess(withObject object: Any?, andMessage message: String?) {
        if let zip = self.zipSuccess, let dataObject = object as? Data {
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
