//
//  NewLIRequest.swift
//  LIRequest
//
//  Created by Boris Falcinelli on 21/09/16.
//  Copyright © 2016 Boris Falcinelli. All rights reserved.
//

import Foundation

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
public typealias ValidationResponseObject = ((_ response:Any?)->Bool)

/// - parameter progress : oggetto Progress contenente le informazione del progresso
public typealias ProgressObject = ((_ progress : Progress)->Void)

public typealias ObjectConversion = ((_ parameters : [String:Any]) throws ->String)

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
    
    static var shared : LIRequestInstance = LIRequestInstance()
    
    private override init() {

    }
    
    internal func hideNetworkActivity() {
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }
    }
}

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
        let string = String(data: data, encoding: .utf8)
        debugPrint(string)
        if [.applicationJson,.textPlain].contains(request.contentType) {
            guard let objectJSON = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) else {
                self.urlSession(session, task: downloadTask, didCompleteWithError: LIRequestError(forType: .incorrectResponseContentType,withUrlString:downloadTask.currentRequest?.url?.absoluteString))
                return
            }
            guard let object = objectJSON as? [AnyHashable:Any] else {
                self.urlSession(session, task: downloadTask, didCompleteWithError: LIRequestError(forType: .incorrectResponseContentType,withUrlString:downloadTask.currentRequest?.url?.absoluteString))
                return
            }
            guard request.validationResponseObject(object) else {
                self.urlSession(session, task: downloadTask, didCompleteWithError: LIRequestError(forType: .errorInResponse, withUrlString: downloadTask.currentRequest?.url?.absoluteString,withErrorString:object["message"] as? String))
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
        } else {
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

public class LIRequest {
    
    public struct LoginData {
        let username : String
        let password : String
    }
    
    /// Indica il Content-Type di default impostato nell'inizializzazione dell'oggetto LIRequest
    public var contentType : ContentType
    
    /// Indica il valore della chiave di default contenente l'oggetto utile nella risposta
    public var callbackName : String
    
    /// Indica i dati necessari per effettuare il login durante le richiesta
    public var loginData : LoginData?
    
    /// Indica lo User-Agent di default impostato all'inizializzazione dell'oggetto LIRequest
    public var userAgent : String?
    
    /// Indica se dovrè essere visibile l'indicatore di sistema dell'utilizzo della rete
    public var showNetworkActivityIndicator : Bool
    internal var isCompleteObject : IsCompleteObject?
    internal var failureObjects : [FailureObject]
    internal var successObjects : [SuccessObject]
    internal var progressObject : ProgressObject?
    internal var validationResponseObject : ValidationResponseObject
    fileprivate var progress : Progress!
    
    internal var failureCalled : Bool = false
    internal var successCalled : Bool = false
    internal var alreadyCalled : Bool { return failureCalled || successCalled }
    
    /// Indica quale tipo di codifica dovrà essere utilizzata durante la fase di invio dei parametri nel corpo della richiesta.
    var encoding : String.Encoding
    
    /// Contiene l'oggetto responsabile per la conversione dei parametri durante la fase di preparazione della chiamata.
    var objectConversion : ObjectConversion?
    
    /// Crea una nuova istanza della classe LIRequest.
    /// I dati per l'inizializzazione di questa istanza vengono presi dal singleton LIRequestInstance
    ///
    /// - returns: nuova istanza di LIRequest
    init() {
        self.contentType = LIRequestInstance.shared.contentType
        self.callbackName = LIRequestInstance.shared.callbackName
        self.loginData = LIRequestInstance.shared.loginData
        self.userAgent = LIRequestInstance.shared.userAgent
        self.showNetworkActivityIndicator = LIRequestInstance.shared.showNetworkActivityIndicator
        self.isCompleteObject = LIRequestInstance.shared.isCompleteObject
        self.failureObjects = LIRequestInstance.shared.failureObject != nil ? [LIRequestInstance.shared.failureObject!] : []
        self.successObjects = LIRequestInstance.shared.successObject != nil ? [LIRequestInstance.shared.successObject!] : []
        self.validationResponseObject = LIRequestInstance.shared.validationResponseObject
        self.progressObject = LIRequestInstance.shared.progressObject
        self.objectConversion = LIRequestInstance.shared.objectConversion
        self.encoding = LIRequestInstance.shared.encoding
    }
    
    /// Specifica il metodo utilizzato per la chiamata
    ///
    /// - post: Il protocollo POST passa le coppie nome-valore nel corpo del messaggio di richiesta HTTP.
    /// - get:  Il protocollo GET crea una stringa di query delle coppie nome-valore e quindi aggiunge la stringa di query all'URL
    public enum Method : String {
        case post = "POST"
        case get = "GET"
    }
    
    /// Specifica il Content-Type impostato nella richiesta e l' Accept della risposta
    ///
    /// - textPlain:
    /// - applicationJson:
    /// - textHtml:
    /// - imageJpeg:
    public enum ContentType : String {
        case textPlain = "text/plain"
        case applicationJson = "application/json"
        case textHtml = "text/html"
        case imageJpeg = "image/jpeg"
        case applicationFormUrlencoded = "application/x-www-form-urlencoded"
    }
    
    /// Effettua una chiamata GET all'indirizzo url con i parametri
    ///
    /// - parameter url:    indica l'url a cui sarà indirizzata la chiamata
    /// - parameter params: specifica i parametri da passare al server durante la chiamata
    public func get(toURL url : URL, withParams params : [String:Any]?) {
        self.action(withMethod: .get, toUrl: url, withParams: params)
    }
    
    /// Effettua una chiamata POST all'indirizzo url con i parametri
    ///
    /// - parameter url:    indica l'url a cui sarà indirizzata la chiamata
    /// - parameter params: specifica i parametri da passare al server durante la chiamata
    public func post(toURL url : URL, withParams params : [String:Any]?) {
        self.action(withMethod: .post, toUrl: url, withParams: params)
    }
    
    internal func action(withMethod method:Method, toUrl url : URL, withParams params : [String:Any]?) {
        var request = self.request(forUrl: url,withMethod: method)
        if let par = params {
            var query : String
            if let obj = self.objectConversion {
                do {
                    query = try obj(par)
                } catch {
                    query = ""
                    let error = LIRequestError(forType: .incorrectParametersToSend,withParameters:par)
                    self.failureObjects.forEach({$0(nil,error)})
                }
            } else {
                query = queryString(fromParameter: par)
            }
            request.httpBody = query.data(using: self.encoding)
        }
        if let body = request.httpBody {
            let string = String(data: body, encoding: self.encoding)
            debugPrint(string)
        }
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = self.showNetworkActivityIndicator
        }
        let task = LIRequestInstance.shared.session.downloadTask(with: request)
        LIRequestInstance.shared.addNewCall(withTash: task, andRequest: self)
        
        //        - (NSURLRequest *)requestBySerializingRequest:(NSURLRequest *)request
        //        withParameters:(id)parameters
        //        error:(NSError *__autoreleasing *)error
        //        {
        //            NSParameterAssert(request);
        //
        //            NSMutableURLRequest *mutableRequest = [request mutableCopy];
        //
        //            [self.HTTPRequestHeaders enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
        //                if (![request valueForHTTPHeaderField:field]) {
        //                [mutableRequest setValue:value forHTTPHeaderField:field];
        //                }
        //                }];
        //
        //            NSString *query = nil;
        //            if (parameters) {
        //                if (self.queryStringSerialization) {
        //                    NSError *serializationError;
        //                    query = self.queryStringSerialization(request, parameters, &serializationError);
        //
        //                    if (serializationError) {
        //                        if (error) {
        //                            *error = serializationError;
        //                        }
        //
        //                        return nil;
        //                    }
        //                } else {
        //                    switch (self.queryStringSerializationStyle) {
        //                    case AFHTTPRequestQueryStringDefaultStyle:
        //                        query = AFQueryStringFromParameters(parameters);
        //                        break;
        //                    }
        //                }
        //            }
        //
        //            if ([self.HTTPMethodsEncodingParametersInURI containsObject:[[request HTTPMethod] uppercaseString]]) {
        //                if (query && query.length > 0) {
        //                    mutableRequest.URL = [NSURL URLWithString:[[mutableRequest.URL absoluteString] stringByAppendingFormat:mutableRequest.URL.query ? @"&%@" : @"?%@", query]];
        //                }
        //            } else {
        //                // #2864: an empty string is a valid x-www-form-urlencoded payload
        //                if (!query) {
        //                    query = @"";
        //                }
        //                if (![mutableRequest valueForHTTPHeaderField:@"Content-Type"]) {
        //                    [mutableRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        //                }
        //                [mutableRequest setHTTPBody:[query dataUsingEncoding:self.stringEncoding]];
        //            }
        //            
        //            return mutableRequest;
        //        }
        
    }
    
    private func queryString(fromParameter params : [String:Any]) -> String {
        var array : [String] = []
        for (key,value) in params {
            array.append(String(format:"%@=%@",key,description(value)))
        }
        
        return array.joined(separator: "&")
    }
    
    private func description(_ item : Any) -> String {
        if let val = item as? String {
            return val.description
        } else
        if let val = item as? Int {
            return val.description
        } else
        if let val = item as? Double {
              return val.description
        } else
        if let val = item as? Float {
              return val.description
        } else
        if let val = item as? UInt {
              return val.description
        } else {
            assertionFailure("No valid type in description")
            return ""
        }
    
    //        NSString * AFQueryStringFromParameters(NSDictionary *parameters) {
    //            NSMutableArray *mutablePairs = [NSMutableArray array];
    //            for (AFQueryStringPair *pair in AFQueryStringPairsFromDictionary(parameters)) {
    //                [mutablePairs addObject:[pair URLEncodedStringValue]];
    //            }
    //
    //            return [mutablePairs componentsJoinedByString:@"&"];
    //        }
    }
    
//    private func encode(key : String, andValue value : String?) -> String {
//        if value == nil {
//            return percentEscaped(fromString: key)
//        } else {
//            return String(format: "%@=%@", percentEscaped(fromString: key),percentEscaped(fromString: value!))
//        }
//    }
    //        - (NSString *)URLEncodedStringValue {
    //            if (!self.value || [self.value isEqual:[NSNull null]]) {
    //                return AFPercentEscapedStringFromString([self.field description]);
    //            } else {
    //                return [NSString stringWithFormat:@"%@=%@", AFPercentEscapedStringFromString([self.field description]), AFPercentEscapedStringFromString([self.value description])];
    //            }
    //        }

//    private func percentEscaped(fromString string : String) -> String {
//        let generalDelimiters = ":#[]@"
//        let subDelimiters = "!$&'()*+,;="
//        var charset = CharacterSet.urlQueryAllowed
//        charset.remove(charactersIn: generalDelimiters)
//        charset.remove(charactersIn: subDelimiters)
//        
//        let batchSize : Int = 50
//        var index : Int = 0
//        var escaped = ""
//        while index<string.characters.count {
//            let length = min(string.characters.count - index, batchSize)
//            let l = index as! String.Index
//            let u = length as! String.Index
//            var range = Range<String.Index>(uncheckedBounds: (lower: l, upper: u))
//            range = string.rangeOfComposedCharacterSequences(for: range)
//            let substring = string.substring(with: range)
//            let encoded = substring.addingPercentEncoding(withAllowedCharacters: charset)
//            escaped.append(encoded!)
//            index += range.upperBound
//        }
//        return escaped
//    }
//    NSString * AFPercentEscapedStringFromString(NSString *string) {
//    static NSString * const kAFCharactersGeneralDelimitersToEncode = @":#[]@"; // does not include "?" or "/" due to RFC 3986 - Section 3.4
//    static NSString * const kAFCharactersSubDelimitersToEncode = @"!$&'()*+,;=";
//    
//    NSMutableCharacterSet * allowedCharacterSet = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
//    [allowedCharacterSet removeCharactersInString:[kAFCharactersGeneralDelimitersToEncode stringByAppendingString:kAFCharactersSubDelimitersToEncode]];
//    
//    // FIXME: https://github.com/AFNetworking/AFNetworking/pull/3028
//    // return [string stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet];
//    
//    static NSUInteger const batchSize = 50;
//    
//    NSUInteger index = 0;
//    NSMutableString *escaped = @"".mutableCopy;
//    
//    while (index < string.length) {
//    #pragma GCC diagnostic push
//    #pragma GCC diagnostic ignored "-Wgnu"
//    NSUInteger length = MIN(string.length - index, batchSize);
//    #pragma GCC diagnostic pop
//    NSRange range = NSMakeRange(index, length);
//    
//    // To avoid breaking up character sequences such as 👴🏻👮🏽
//    range = [string rangeOfComposedCharacterSequencesForRange:range];
//    
//    NSString *substring = [string substringWithRange:range];
//    NSString *encoded = [substring stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet];
//    [escaped appendString:encoded];
//    
//    index += range.length;
//    }
//    
//    return escaped;
//    }
    
    public func post(toURL url : URL, withImage image : UIImage, andFileName fileName : String, andParamImageName paramImageName : String?, andParams params : [String:Any]?) {
        

//        NSArray * AFQueryStringPairsFromKeyAndValue(NSString *key, id value) {
//            NSMutableArray *mutableQueryStringComponents = [NSMutableArray array];
//            
//            NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"description" ascending:YES selector:@selector(compare:)];
//            
//            if ([value isKindOfClass:[NSDictionary class]]) {
//                NSDictionary *dictionary = value;
//                // Sort dictionary keys to ensure consistent ordering in query string, which is important when deserializing potentially ambiguous sequences, such as an array of dictionaries
//                for (id nestedKey in [dictionary.allKeys sortedArrayUsingDescriptors:@[ sortDescriptor ]]) {
//                    id nestedValue = dictionary[nestedKey];
//                    if (nestedValue) {
//                        [mutableQueryStringComponents addObjectsFromArray:AFQueryStringPairsFromKeyAndValue((key ? [NSString stringWithFormat:@"%@[%@]", key, nestedKey] : nestedKey), nestedValue)];
//                    }
//                }
//            } else if ([value isKindOfClass:[NSArray class]]) {
//                NSArray *array = value;
//                for (id nestedValue in array) {
//                    [mutableQueryStringComponents addObjectsFromArray:AFQueryStringPairsFromKeyAndValue([NSString stringWithFormat:@"%@[]", key], nestedValue)];
//                }
//            } else if ([value isKindOfClass:[NSSet class]]) {
//                NSSet *set = value;
//                for (id obj in [set sortedArrayUsingDescriptors:@[ sortDescriptor ]]) {
//                    [mutableQueryStringComponents addObjectsFromArray:AFQueryStringPairsFromKeyAndValue(key, obj)];
//                }
//            } else {
//                [mutableQueryStringComponents addObject:[[AFQueryStringPair alloc] initWithField:key value:value]];
//            }
//            
//            return mutableQueryStringComponents;
//        }

        
        
        var request = self.request(forUrl: url,withMethod: .post)
        request.setValue("multipart/form-data", forHTTPHeaderField: "Content-Type")
        guard let imageData = UIImagePNGRepresentation(image) else {
            self.failureObjects.forEach({ $0(nil,LIRequestError(forType: .incorrectImageToSend))})
            return
        }
        var body = Data()
        let boundary = generateBoundaryString()
        let boundaryData = NSString(string:"--\(boundary)\r\n").data(using: self.encoding.rawValue)
        body.append(boundaryData!)
        let contentDispositionData = NSString(string:"Content-Disposition:form-data;name\"test\"\r\n\r\n").data(using: self.encoding.rawValue)!
        body.append(contentDispositionData)
        let contentTypeData = NSString(string: "Content-Type:\(ContentType.imageJpeg.rawValue)\r\n\r\n").data(using: self.encoding.rawValue)!
        body.append(contentTypeData)
        body.append(imageData)
        let endData = NSString(string: "\r\n").data(using: self.encoding.rawValue)!
        body.append(endData)
        let endBoundaryData = NSString(string:"--\(boundary)--\r\n").data(using: self.encoding.rawValue)!
        body.append(endBoundaryData)
        request.httpBody = body
        
        let task = LIRequestInstance.shared.session.uploadTask(with: request, from: imageData)
        
        
        LIRequestInstance.shared.addNewCall(withTash: task, andRequest: self)
    }
    
    private func request(forUrl url : URL,withMethod method : Method) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.addValue(self.contentType.rawValue, forHTTPHeaderField: "Content-Type")
        request.addValue(self.contentType.rawValue, forHTTPHeaderField: "Accept")
        if let ua = userAgent {
            request.addValue(ua, forHTTPHeaderField: "User-Agent")
        }
        if let ld = loginData {
            let userString = NSString(format:"%@:%@",ld.username,ld.password)
            let authData = userString.data(using: self.encoding.rawValue)
            let base64EncodedCredential = authData!.base64EncodedData()
            let authString = "Basic \(base64EncodedCredential)"
            request.addValue(authString, forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    private func generateBoundaryString() -> String{
        return "Boundary-\(NSUUID().uuidString)"
    }
    
    /// Imposta il blocco da eseguire al completamento della chiamata.
    /// Viene richiamato sia che la chiamata è andata a buon fine che in errore
    ///
    /// - parameter object:   blocco di completamento
    /// - parameter override: se true sovrascrive il blocco, altrimenti esegue prima quello delle configurazioni e poi quello passato
    public func setIsComplete(withObject object : IsCompleteObject?, overrideDefault override : Bool) {
        if override {
            self.isCompleteObject = object
        } else {
            self.setIsComplete(withObject: { (request, success) in
                LIRequestInstance.shared.isCompleteObject?(request,success)
                object?(request,success)
                }, overrideDefault: true)
        }
    }
    
    /// Imposta il blocco da eseguire in caso di errore nella chiamata
    ///
    /// - parameter object:   blocco di errore
    /// - parameter override: se true sovrascrive il blocco, altrimenti esegue prima quello delle configurazioni e poi quello passato
    public func setFailure(withObject object : @escaping FailureObject, overrideDefault override : Bool) {
        if override {
            self.failureObjects = [object]
        } else {
            self.addFailure(withObject: object)
        }
    }
    
    /// Aggiunge il blocco in coda ai blocchi già presenti
    ///
    /// - parameter object: blocco del failure
    public func addFailure(withObject object : @escaping FailureObject) {
        self.failureObjects.append(object)
    }
    
    /// Imposta il blocco da eseguire in caso di successo nella chiamata
    ///
    /// - parameter object:   blocco di successo
    /// - parameter override: se true sovrascrive il blocco, altrimenti esegue prima quello delle configurazioni e poi quello passato
    public func setSuccess(withObject object : @escaping SuccessObject, overrideDefault override : Bool) {
        if override {
            self.successObjects = [object]
        } else {
            self.addSuccess(withObject: object)
        }
    }
    
    /// Aggiunge il blocco in coda ai blocchi già presenti
    ///
    /// - parameter object: blocco di success
    public func addSuccess(withObject object : @escaping SuccessObject) {
        self.successObjects.append(object)
    }
    
    /// Imposta il blocco da eseguire durante l'avanzamento della chiamata
    ///
    /// - parameter object:   blocco d'avanzamento
    /// - parameter override: se true sovrascrive il blocco, altrimenti esegue prima quello delle configurazioni e poi quello passato
    public func setProgress(withObject object : ProgressObject?, overrideDefault override : Bool) {
        if override {
            self.progressObject = object
        } else {
            self.setProgress(withObject: { (progress) in
                LIRequestInstance.shared.progressObject?(progress)
                object?(progress)
                }, overrideDefault: true)
        }
    }
    
    /// Imposta il blocco da eseguire per la validazione dei dati
    ///
    /// - parameter object:   blocco di validazione dati
    /// - parameter override: se true sovrascrive il blocco, altrimenti esegue prima quello delle configurazioni e poi quello passato
    public func setValidation(withObject object : @escaping ValidationResponseObject, overrideDefault override : Bool) {
        if override {
            self.validationResponseObject = object
        } else {
            self.setValidation(withObject: { (response) -> Bool in
                return LIRequestInstance.shared.validationResponseObject(response) && object(response)
                }, overrideDefault: true)
        }
    }
    
    /// Rimuove il blocco della validazione dei dati per l'istanza corrente
    public func removeValidation() {
        self.setValidation(withObject: { (_) -> Bool in
            return true
            }, overrideDefault: true)
    }
}

class LIRequestError : NSError {

    /// Definisce il tipo di errore possibile in LIRequest.
    /// Per ogni tipo di errore definisce la descrizione dell'errore, il motivo per cui si è verificato ed un eventuale metodo di risoluzione
    ///
    /// - invalidUrl
    /// - errorInRespose
    /// - noDataInResponse
    /// - incorrectResponseContentType
    /// - incorrectParametersToSend
    /// - incorrectImageToSend
    internal enum ErrorType : Int, LocalizedError {
        case invalidUrl = 400
        case errorInResponse = 406
        case noDataInResponse = 407
        case incorrectResponseContentType = 500
        case incorrectParametersToSend = 600
        case incorrectImageToSend = -145
        
        internal var errorDescription: String? {
            switch self {
            default:
                return NSLocalizedString("ErrorCall", comment: "")
            }
        }
        
        var failureReason: String? {
            switch self {
            case .invalidUrl:
                return NSLocalizedString("ErrorInvalidUrl", comment: "")
            case .errorInResponse:
                return NSLocalizedString("ErrorInResponse", comment: "")
            case .noDataInResponse:
                return NSLocalizedString("ErrorNoDataInResponse", comment: "")
            case .incorrectResponseContentType:
                return NSLocalizedString("ErrorIncorrectContentType", comment: "")
            case .incorrectParametersToSend:
                return NSLocalizedString("ErrorIncorrectParametersToSend", comment: "")
            case .incorrectImageToSend:
                return NSLocalizedString("ErrorIncorrectImageToSend", comment: "")
            }
        }
        
        internal var recoverySuggestion: String? {
            switch self {
            case .invalidUrl:
                return NSLocalizedString("ErrorInvalidUrlSuggestion", comment: "")
            case .incorrectImageToSend:
                fallthrough
            case .incorrectParametersToSend:
                fallthrough
            case .noDataInResponse:
                fallthrough
            case .incorrectResponseContentType:
                fallthrough
            case .errorInResponse:
                return nil
            }
        }
    }
    
    init(forType type : ErrorType,
        withUrlString url:String?=nil,
        withErrorString string : String? = nil,
        withParameters params : [AnyHashable:Any]? = nil) {
        let domain = "net.labinfo.LIRequest"
        let code = type.rawValue
        var userInfo : [AnyHashable:Any] = [NSLocalizedDescriptionKey:type.errorDescription,
                                            NSLocalizedFailureReasonErrorKey:type.failureReason,
                                            NSLocalizedRecoverySuggestionErrorKey:type.recoverySuggestion]
        if let u = url {
            userInfo["LIRequestURL"] = u
        }
        if let e = string {
            userInfo[NSLocalizedDescriptionKey] = e
        }
        if let p = params {
            userInfo["LIRequestParametersCausedError"] = "\(type.failureReason ?? "") : \(p)"
        }
        super.init(domain: domain, code: code, userInfo: userInfo)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
