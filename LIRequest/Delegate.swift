//
//  LIRequestDelegate.swift
//  LIRequest
//
//  Created by Boris Falcinelli on 17/10/16.
//  Copyright © 2016 Boris Falcinelli. All rights reserved.
//

import Foundation

internal class LIRequestDelegate : NSObject, URLSessionDelegate, URLSessionTaskDelegate,URLSessionDataDelegate,URLSessionDownloadDelegate {
    
    /// Viene chiamato durante la fase di download dei dati, solitamente, per qualsiasi chiamata POST e GET.
    /// In questo metodo viene chiamato l'oggetto progress associato alla chiamata, se non presente non viene eseguito nulla.
    /// Se totalBytesExpectedToWrite è un dato non conosciuto (a causa dell'header nella risposta) non viene eseguito nessun codice.
    ///
    /// - parameter session:                   sessione alla quale è associata la chiamata
    /// - parameter downloadTask:              task che effettua la chiamata ed il download
    /// - parameter bytesWritten:              numero di bytes ricevuti e scritti nel pacchetto attuale
    /// - parameter totalBytesWritten:         totale dei bytes ricevuti e scritti
    /// - parameter totalBytesExpectedToWrite: totale dei bytes che ci si aspetta di ricevere
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        LIPrint("Download dati in corso... (Scritti : \(totalBytesWritten.description), Da scrivere : \(totalBytesExpectedToWrite.description))")
        
//        <NSProgress: 0x17412f280> : Parent: 0x0 / Fraction completed: 94061.7000 / Completed: 2821851 of 30
        
        guard totalBytesExpectedToWrite != NSURLSessionTransferSizeUnknown else { return }
        if let request = LIRequestInstance.shared.requestForTask[downloadTask] {
            if let progressObject = request.progressObject {
                if request.progress.totalUnitCount != totalBytesExpectedToWrite {
                    request.progress.totalUnitCount = totalBytesExpectedToWrite
                }
                request.progress.completedUnitCount = totalBytesWritten
                progressObject(request.progress)
            }
        }
    }
    
    /// Viene chiamato al termine della fase di download dei dati per qualsiasi chiamata POST e GET
    /// Vengono effettuati i controlli sui dati ricevuti in base al Content-Type impostato nella chiamata, al blocco per la validazione
    ///
    /// Tipi di dati accettati:
    ///     --> applicationZip  : object = Data dati contenuti nel file,       message = nil
    ///     --> applicationJson : object = [String:Any] convertita,     message = testo nel json
    ///     --> textHtml
    ///     --> textPlain
    ///     --> textCss
    ///     --> textCsv         : object = String convertita dai dati,  message = nil
    ///     --> default         : object = Data convertita dai dati,    message = nil
    ///
    /// - parameter session:      sessione alla quale è associata la chiamata
    /// - parameter downloadTask: task che ha effettuato la chiamata ed il download
    /// - parameter location:     url che specifica dove i dati sono stati salvati temporaneamente
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        LIPrint("Download dei dati completato")
        LIRequestInstance.shared.hideNetworkActivity()
        guard let request = LIRequestInstance.shared.requestForTask[downloadTask] else { return }
        guard let data = try? Data(contentsOf: location) else {
            LIPrint("Non sono presenti dati nella risposta")
            self.urlSession(session, task: downloadTask, didCompleteWithError: LIRequestError(forType: .noDataInResponse))
            return
        }
        switch request.accept {
        case LIRequest.Accept.applicationZip:
            if !request.alreadyCalled {
                var validation : (validate : Bool,message : String?) = (true,nil)
                if let zipRequest = request as? LIZipRequest {
                    if let data = try? Data(contentsOf: location) {
                        validation = zipRequest.validationObject?(data) ?? (true,nil)
                    }
                }
                guard validation.validate else {
                    LIPrint("Validazione fallita")
                    self.urlSession(session, task: downloadTask, didCompleteWithError: LIRequestError(forType: .errorInResponse,
                                                                                                      withUrlString: downloadTask.currentRequest?.url?.absoluteString,
                                                                                                      withErrorString:validation.message,
                                                                                                      withParameters : nil))
                    return
                }
                let tmp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                let file = tmp.appendingPathComponent(Date().timeIntervalSince1970.description).appendingPathExtension("zip")
                do {
                    try FileManager.default.moveItem(at: location, to: file)
                    request.callSuccess(withObject: file, andMessage: nil)
                    request.isCompleteObject?(request,true)
                }
                catch {
                    self.urlSession(session, task: downloadTask, didCompleteWithError: LIRequestError(forType: .errorInResponse,
                                                                                                      withUrlString: downloadTask.currentRequest?.url?.absoluteString,
                                                                                                      withErrorString: error.localizedDescription))
                }
            }
        case LIRequest.Accept.applicationJson:
            guard let objectJSON = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) else {
                LIPrint("Oggetto della risposta corrotto")
                self.urlSession(session, task: downloadTask, didCompleteWithError: LIRequestError(forType: .incorrectResponseContentType,
                                                                                                  withUrlString:downloadTask.currentRequest?.url?.absoluteString))
                return
            }
            guard let object = objectJSON as? [AnyHashable:Any] else {
                LIPrint("Oggetto non correttamente formattato")
                self.urlSession(session, task: downloadTask, didCompleteWithError: LIRequestError(forType: .incorrectResponseContentType,
                                                                                                  withUrlString:downloadTask.currentRequest?.url?.absoluteString))
                return
            }
            guard request.validationResponseObject(object) else {
                LIPrint("Validazione fallita")
                self.urlSession(session, task: downloadTask, didCompleteWithError: LIRequestError(forType: .errorInResponse,
                                                                                                  withUrlString: downloadTask.currentRequest?.url?.absoluteString,
                                                                                                  withErrorString:object["message"] as? String,
                                                                                                  withParameters : object))
                return
            }
            if request.callbackName.isEmpty {
                if !request.alreadyCalled {
                    request.callSuccess(withObject: object, andMessage: object["message"] as? String)
                    request.isCompleteObject?(request,true)
                }
            } else {
                if !request.alreadyCalled {
                    request.callSuccess(withObject: object[request.callbackName], andMessage: object["message"] as? String)
                    request.isCompleteObject?(request,true)
                }
            }
        case LIRequest.Accept.textHtml:
            fallthrough
        case LIRequest.Accept.textPlain:
            fallthrough
        case LIRequest.Accept.textCss:
            fallthrough
        case LIRequest.Accept.textCsv:
            if let responseString = String(data: data, encoding: request.encoding) {
                LIPrint("Contenuto nella risposta corretto")
                if !request.alreadyCalled {
                    request.callSuccess(withObject: responseString, andMessage: nil)
                    request.isCompleteObject?(request,true)
                }
            } else {
                LIPrint("Oggetto della risposta corrotto")
                self.urlSession(session, task: downloadTask, didCompleteWithError: LIRequestError(forType: .incorrectResponseContentType,
                                                                                                  withUrlString: downloadTask.currentRequest?.url?.absoluteString))
                return
            }
        default:
            if !request.alreadyCalled {
                request.callSuccess(withObject: data, andMessage: nil)
                request.isCompleteObject?(request,true)
            }
        }
    }
    
    /// Viene chiamato durante la fase di upload dei dati.
    /// In questo metodo viene chiamato l'oggetto progress associato alla chiamata.
    ///
    /// - parameter session:                  sessione alla quale è associata la chiamata
    /// - parameter task:                     task che effettua la chiamata e l'upload
    /// - parameter bytesSent:                numero di bytes inviati nel pacchetto attuale
    /// - parameter totalBytesSent:           numero di bytes inviati nella chiamata
    /// - parameter totalBytesExpectedToSend: numero di bytes che ci si aspetta di inviare
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        LIPrint("Invio dati in corso...")
        if let request = LIRequestInstance.shared.requestForTask[task] {
            if let progressObject = request.progressObject {
                if request.progress == nil {
                    request.progress = Progress(totalUnitCount: totalBytesExpectedToSend)
                }
                request.progress.completedUnitCount = bytesSent
                progressObject(request.progress)
            }
        }
    }
    
    /// Viene chiamato al completamento della chiamata.
    /// Se è presente l'oggetto errore viene chiamato il blocco failure della chiamata
    /// altrimenti viene chiamato il blocco success senza nessun oggetto specificato
    ///
    /// - parameter session: sessione alla quale è associata la chiamata
    /// - parameter task:    task che effettua la chiamata
    /// - parameter error:   eventuale errore ricevuto durante la chiamata
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        LIRequestInstance.shared.hideNetworkActivity()
        guard let request = LIRequestInstance.shared.requestForTask[task] else { return }
        if let currentError = error {
            LIPrint("Errore nella chiamata")
            if !request.alreadyCalled {
                let lierr = (currentError as? LIRequestError)
                request.callFailure(withObject: lierr?.parameters, andError: currentError)
                request.isCompleteObject?(request,false)
            }
        } else {
            LIPrint("Chiamata avvenuta con successo")
            if !request.alreadyCalled {
                request.callSuccess(withObject: nil, andMessage: nil)
                request.isCompleteObject?(request,true)
            }
        }
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(URLSession.ResponseDisposition.allow)
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
}
