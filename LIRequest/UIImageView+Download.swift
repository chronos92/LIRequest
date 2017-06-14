//
//  UIImageView+Download.swift
//  LIRequest
//
//  Created by Boris Falcinelli on 20/04/17.
//  Copyright © 2017 Boris Falcinelli. All rights reserved.
//

import Foundation
import UIKit

extension UIImageView {
    func setImage(withUrl url : URL) {
        self.setImage(withUrl: url, showLoadIndicator: false)
    }
    func setImage(withUrl url : URL, showLoadIndicator:Bool) {
        self.setImage(withUrl: url, placeholderImage: nil, showLoadIndicator: showLoadIndicator)
    }
    func setImage(withUrl url : URL, placeholderImage : UIImage) {
        self.setImage(withUrl: url, placeholderImage: placeholderImage,showLoadIndicator:false)
    }
    func setImage(withUrl url : URL, placeholderImage : UIImage,showLoadIndicator : Bool) {
        self.setImage(withUrl: url, placeholderImage: placeholderImage, showLoadIndicator: showLoadIndicator)
    }
    private func setImage(withUrl url : URL, placeholderImage : UIImage?, showLoadIndicator:Bool) {
        if let image = LICacheImage.shared.object(forKey: url.absoluteString as NSString) {
            debugPrint("use cache")
            self.image = image
        }
        else {
            debugPrint("call")
            let request = LIImageRequest()
            request.setImageSuccess(withObject: { (image, response, _) in
                debugPrint("call success")
                DispatchQueue.main.async {
                    if let img = image {
                        LICacheImage.shared.setObject(img, forKey: url.absoluteString as NSString)
                        self.image = img
                    }
                    else {
                        self.image = placeholderImage
                    }
                }
            })
            request.setFailure(overrideDefault: true, withObject: { (_,_, _) in
                debugPrint("call failure")
                DispatchQueue.main.async {
                    self.image = placeholderImage
                }
            })
            request.setIsComplete(overrideDefault: true, withObject: { (_, _) in
                debugPrint("call complete")
                DispatchQueue.main.async {
                    self.hideIndicator()
                }
            })
            if showLoadIndicator {
                DispatchQueue.main.async {
                    self.showIndicator()
                }
            }
            request.get(toURL: url, withParams: nil)
        }
    }
    
    private func hideIndicator() {
        self.viewWithTag(9876)?.removeFromSuperview()
    }
    private func showIndicator() {
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        indicator.tag = 9876
        indicator.center = self.center
        indicator.startAnimating()
        self.addSubview(indicator)
    }
}
