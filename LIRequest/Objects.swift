//
//  LIRequestObjects.swift
//  LIRequest
//
//  Created by Boris Falcinelli on 17/10/16.
//  Copyright © 2016 Boris Falcinelli. All rights reserved.
//

import Foundation
import UIKit

/// - parameter request : oggetto che ha effettuato la richiesta
/// - parameter state: definisce se la richiesta è andata a buon fine oppure è fallita
public typealias IsCompleteObject = ((_ request:LIRequest,_ state:Bool)->Void)

/// - parameter object : oggetto ricevuto dal server
/// - parameter error : specifica che tipo di errore c'è stato
public typealias FailureObject = ((_ object:Any?,_ error : Error)->Void)

/// - parameter object : oggetto ricevuto dal server
/// - parameter message : messaggio ricevuto dal server
public typealias SuccessObject = ((_ object:Any?,_ message:String?)->Void)

/// - parameter response : oggetto ricevuto dal server
/// - returns : true se l'oggetto rispetta la validazione altrimenti false
public typealias ValidationResponseObject = ((_ response:[AnyHashable:Any]?)->Bool)

/// - parameter progress : oggetto Progress contenente le informazione del progresso
public typealias ProgressObject = ((_ progress : Progress)->Void)

public typealias ObjectConversion = ((_ parameters : [String:Any]) throws ->[URLQueryItem])

public typealias ZipSuccessObject = ((_ data : URL,_ message:String?)->Void)

public typealias ZipValidationResponseObject = ((_ response : Any?)->(validate:Bool,message:String?))

public typealias JSONSuccessObject = ((_ jsonObject : [AnyHashable:Any],_ message : String?)->Void)

public typealias ImageSuccessObject = ((_ image : UIImage?,_ message : String?)->Void)
