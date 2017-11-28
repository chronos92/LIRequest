//
//  UIImageView+Download.swift
//  LIRequest
//
//  Created by Boris Falcinelli on 20/04/17.
//  Copyright © 2017 Boris Falcinelli. All rights reserved.
//

import Foundation
import UIKit

public extension UIImageView {
    public func setImage(withUrl url : URL!) {
        self.setImage(withUrl: url, showLoadIndicator: false)
    }
    public func setImage(withUrl url : URL!, showLoadIndicator:Bool) {
        self.setImage(withUrl: url, placeholderImage: nil, showLoadIndicator: showLoadIndicator)
    }
    public func setImage(withUrl url : URL!, placeholderImage : UIImage!) {
        self.setImage(withUrl: url, placeholderImage: placeholderImage,showLoadIndicator:false)
    }
    public func setImage(withUrl url : URL!, placeholderImage : UIImage!, showLoadIndicator:Bool) {
        if url != nil {
            if let image = LICacheImage.shared.object(forKey: url.absoluteString as NSString) {
                debugPrint("use cache")
                self.image = image
            }
            else {
                debugPrint("call")
                let request = LIImageRequest()
                request.setProgress(withObject: { (progress) in
                    self.indicatorView?.progress = CGFloat(progress.fractionCompleted)
                })
                request.setImageSuccess(withObject: { (request, image, message) in
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
                })
                if showLoadIndicator {
                    DispatchQueue.main.async {
                        self.showIndicator()
                    }
                }
                request.get(toURL: url, withParams: nil)
            }
        }
        else {
            self.image = placeholderImage
        }
    }
    
    internal var indicatorView : CircularLoaderView? {
        get {
            return self.viewWithTag(9876) as? CircularLoaderView
        }
    }
    

    private func showIndicator() {
        let indicatorView = CircularLoaderView(frame: .zero)
        indicatorView.tag = 9876
        addSubview(indicatorView)
        addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "V:|[v]|", options: .init(rawValue: 0),
            metrics: nil, views: ["v": indicatorView]))
        addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "H:|[v]|", options: .init(rawValue: 0),
            metrics: nil, views:  ["v": indicatorView]))
        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        indicatorView.reveal()
    }

}
