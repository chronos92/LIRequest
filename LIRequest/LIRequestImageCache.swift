//
//  LIRequestImageCache.swift
//  LIRequest
//
//  Created by Boris Falcinelli on 20/04/17.
//  Copyright © 2017 Boris Falcinelli. All rights reserved.
//

import Foundation
import UIKit

internal class LICacheImage: NSCache<NSString, UIImage> {
    
    static let shared = LICacheImage()
}
