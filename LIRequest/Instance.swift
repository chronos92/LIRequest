//
//  Instance.swift
//  LIRequest
//
//  Created by Boris Falcinelli on 17/10/16.
//  Copyright © 2016 Boris Falcinelli. All rights reserved.
//

import Foundation
import UIKit

public class LIRequestInstance : NSObject {
    
    public var testEnable : Bool = false
    
    /// Indica l' Accept di default impostato nell'inizializzazione dell'oggetto LIRequest
    public var accept : MimeType = MimeType(type: .application, subtype: .json)
    
    /// Indica il Content-Type di default impostato nell'inizializzazione dell'oggetto LIRequest
    public var contentType : MimeType = MimeType(type: .application, subtype: .json)
    
    /// Indica il valore della chiave di default contenente l'oggetto utile nella risposta
    public var callbackName : String = ""
    
    /// Indica i dati necessari per effettuare il login durante le richiesta
    public var loginData : LIRequest.LoginData? = nil
    
    /// Indica lo User-Agent di default impostato all'inizializzazione dell'oggetto LIRequest
    public var userAgent : String? = nil
    
    /// Indica se dovrè essere visibile l'indicatore di sistema dell'utilizzo della rete
    public var showNetworkActivityIndicator : Bool = true
    
    /// Contiente l'oggetto richiamato quando la richiesta è terminata.
    /// Può essere sovvrascritto per ogni chiamata
    public var isCompleteObject : IsCompleteObject?
    
    /// Contiene l'oggetto richiamato in caso di errore della richiesta.
    /// Può essere sovvrascritto per ogni chiamata
    public var failureObject : FailureObject?
    
    /// Contiene l'oggetto richiamato in caso di successo della richiesta.
    /// Può essere sovvrascritto per ogni chiamata
    public var successObject : SuccessObject?
    
    /// Contiene l'oggetto responsabile della validazione della chiamata per il controllo del parametro success nel json ricevuto
    /// Può essere sovvrascritto per ogni chiamata
    public var validationResponseObject : ValidationResponseObject = { (_) in return true }
    /// Contiente l'oggetto richiamato durante il download o l'upload dei dati.
    /// Può essere sovvrascritto per ogni chiamata
    public var progressObject : ProgressObject?
    
    /// Contiene l'oggetto responsabile per la conversione dei parametri durante la fase di preparazione della chiamata
    public var objectConversion : ObjectConversion?
    
    /// Indica quale tipo di conversione verrà fatta per la creazione del corpo della chiamata
    /// Default : utf8
    public var encoding : String.Encoding = .utf8
    
    internal var listOfCall : [URLSessionTask] = []
    internal var requestForTask : [URLSessionTask:LIRequest] = [:]
    
    private var requestDelegate : LIRequestDelegate = LIRequestDelegate()
    
    var session : URLSession {
        return URLSession(configuration: URLSessionConfiguration.default, delegate: requestDelegate, delegateQueue: nil)
    }
    
    func addNewCall(withTask task : URLSessionTask, andRequest request: LIRequest) {
        let success = request.successObjects
        request.progress = Progress()
        request.addSuccess { (req, _, _, _) in
            req.successCalled = true
        }
        request.addFailure { (req, _, _) in
            req.failureCalled = true
        }
        let complete = request.isCompleteObject
        let removingCode : IsCompleteObject = {(_, _) in
            self.remove(task: task)
        }
        request.setIsComplete(overrideDefault: true) { (request, completed) in
            complete?(request,(complete != nil))
            removingCode(request, completed)
        }
        requestForTask[task] = request
        listOfCall.append(task)
        LIPrint("Aggiunta nuova richiesta")
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
    
    public func configureLabinfoSettings() {
        callbackName = "data"
        contentType = MimeType(type: .application, subtype: .xWwwFormUrlencoded)
        validationResponseObject = { response in
            guard let object = response else { return false }
            var value : Bool = false
            guard let key = object["success"] else { return false }
            if let int = key as? Int {
                value = int == 0 ? false : true
            } else if let bool = key as? Bool {
                value = bool
            }
            return value
        }

    }
    
    public func stopAllTask() {
        for task in listOfCall {
            task.cancel()
        }
    }
    
    internal func remove(task : URLSessionTask) {
        if let index = listOfCall.index(of: task) {
            listOfCall.remove(at: index)
            requestForTask.removeValue(forKey: task)
        }
    }
}
