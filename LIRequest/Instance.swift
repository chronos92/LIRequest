//
//  Instance.swift
//  LIRequest
//
//  Created by Boris Falcinelli on 17/10/16.
//  Copyright © 2016 Boris Falcinelli. All rights reserved.
//

import Foundation

public class LIRequestInstance : NSObject {
    
    /// Indica il Content-Type di default impostato nell'inizializzazione dell'oggetto LIRequest
    var contentType : LIRequest.ContentType = .applicationJson
    
    /// Indica il valore della chiave di default contenente l'oggetto utile nella risposta
    var callbackName : String = "data"
    
    /// Indica i dati necessari per effettuare il login durante le richiesta
    var loginData : LIRequest.LoginData? = nil
    
    /// Indica lo User-Agent di default impostato all'inizializzazione dell'oggetto LIRequest
    var userAgent : String? = nil
    
    /// Indica se dovrè essere visibile l'indicatore di sistema dell'utilizzo della rete
    var showNetworkActivityIndicator : Bool = true
    
    /// Contiente l'oggetto richiamato quando la richiesta è terminata.
    /// Può essere sovvrascritto per ogni chiamata
    var isCompleteObject : IsCompleteObject?
    
    /// Contiene l'oggetto richiamato in caso di errore della richiesta.
    /// Può essere sovvrascritto per ogni chiamata
    var failureObject : FailureObject?
    
    /// Contiene l'oggetto richiamato in caso di successo della richiesta.
    /// Può essere sovvrascritto per ogni chiamata
    var successObject : SuccessObject?
    
    /// Contiene l'oggetto responsabile della validazione della chiamata per il controllo del parametro success nel json ricevuto
    /// Può essere sovvrascritto per ogni chiamata
    var validationResponseObject : ValidationResponseObject = { response in
        guard let object = response as? [AnyHashable:Any] else { return false }
        guard let success = object["success"] as? Bool else { return false }
        return success
    }
    
    /// Contiente l'oggetto richiamato durante il download o l'upload dei dati.
    /// Può essere sovvrascritto per ogni chiamata
    var progressObject : ProgressObject?
    
    /// Contiene l'oggetto responsabile per la conversione dei parametri durante la fase di preparazione della chiamata
    var objectConversion : ObjectConversion?
    
    /// Indica quale tipo di conversione verrà fatta per la creazione del corpo della chiamata
    /// Default : utf8
    var encoding : String.Encoding = .utf8
    
    internal var listOfCall : [URLSessionTask] = []
    internal var requestForTask : [Int:LIRequest] = [:]
    
    private var requestDelegate : LIRequestDelegate = LIRequestDelegate()
    
    var session : URLSession {
        return URLSession(configuration: URLSessionConfiguration.default, delegate: requestDelegate, delegateQueue: nil)
    }
    
    func addNewCall(withTash task : URLSessionTask, andRequest request: LIRequest) {
        let success = request.successObjects
        request.setSuccess(withObject: { (obj, msg) in
            DispatchQueue.main.async {
                success.forEach({ $0(obj,msg) })
            }
            request.successCalled = true
            }, overrideDefault: true)
        let failure = request.failureObjects
        request.setFailure(withObject: { (obj, msg) in
            DispatchQueue.main.async {
                failure.forEach({ $0(obj,msg) })
            }
            request.failureCalled = true
            }, overrideDefault: true)
        requestForTask[task.taskIdentifier] = request
        listOfCall.append(task)
        task.resume()
    }
    
    static public var shared : LIRequestInstance = LIRequestInstance()
    
    private override init() {
        
    }
    
    internal func hideNetworkActivity() {
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }
    }
}
