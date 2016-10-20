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
        guard totalBytesExpectedToWrite != NSURLSessionTransferSizeUnknown else { return }
        if let request = LIRequestInstance.shared.requestForTask[downloadTask.taskIdentifier] {
            if let progressObject = request.progressObject {
                if request.progress == nil {
                    request.progress = Progress(totalUnitCount: totalBytesExpectedToWrite)
                }
                request.progress.completedUnitCount = totalBytesWritten
                progressObject(request.progress)
            }
        }
    }
    
    /// Viene chiamato al termine della fase di download dei dati per qualsiasi chiamata POST e GET
    /// Vengono effettuati i controlli sui dati ricevuti in base al Content-Type impostato nella chiamata, al blocco per la validazione
    ///
    /// - parameter session:      sessione alla quale è associata la chiamata
    /// - parameter downloadTask: task che ha effettuato la chiamata ed il download
    /// - parameter location:     url che specifica dove i dati sono stati salvati temporaneamente
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        LIRequestInstance.shared.hideNetworkActivity()
        guard let request = LIRequestInstance.shared.requestForTask[downloadTask.taskIdentifier] else { return }
        guard let data = try? Data(contentsOf: location) else {
            self.urlSession(session, task: downloadTask, didCompleteWithError: LIRequestError(forType: .noDataInResponse))
            return
        }
        switch request.accept {
        case LIRequest.Accept.applicationJson:
            guard let objectJSON = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) else {
                self.urlSession(session, task: downloadTask, didCompleteWithError: LIRequestError(forType: .incorrectResponseContentType,
                                                                                                  withUrlString:downloadTask.currentRequest?.url?.absoluteString))
                return
            }
            guard let object = objectJSON as? [AnyHashable:Any] else {
                self.urlSession(session, task: downloadTask, didCompleteWithError: LIRequestError(forType: .incorrectResponseContentType,
                                                                                                  withUrlString:downloadTask.currentRequest?.url?.absoluteString))
                return
            }
            guard request.validationResponseObject(object) else {
                self.urlSession(session, task: downloadTask, didCompleteWithError: LIRequestError(forType: .errorInResponse,
                                                                                                  withUrlString: downloadTask.currentRequest?.url?.absoluteString,
                                                                                                  withErrorString:object["message"] as? String))
                return
            }
            if request.callbackName.isEmpty {
                if !request.alreadyCalled {
                    request.successObjects.forEach({ $0(object,object["message"] as? String)})
                    request.isCompleteObject?(request,true)
                }
            } else {
                if !request.alreadyCalled {
                    request.successObjects.forEach({ $0([request.callbackName],object["message"] as? String)})
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
                if !request.alreadyCalled {
                    request.successObjects.forEach({ $0(responseString,nil) })
                    request.isCompleteObject?(request,true)
                }
            } else {
                self.urlSession(session, task: downloadTask, didCompleteWithError: LIRequestError(forType: .incorrectResponseContentType,
                                                                                                  withUrlString: downloadTask.currentRequest?.url?.absoluteString))
                return
            }
        default:
            if !request.alreadyCalled {
                request.successObjects.forEach({ $0(data,nil) })
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
        if let request = LIRequestInstance.shared.requestForTask[task.taskIdentifier] {
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
        guard let request = LIRequestInstance.shared.requestForTask[task.taskIdentifier] else { return }
        if let currentError = error {
            if !request.alreadyCalled {
                request.failureObjects.forEach({$0(nil,currentError)})
                request.isCompleteObject?(request,false)
            }
        } else {
            if !request.alreadyCalled {
                request.successObjects.forEach({$0(nil,nil)})
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
