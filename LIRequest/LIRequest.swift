//
//  NewLIRequest.swift
//  LIRequest
//
//  Created by Boris Falcinelli on 21/09/16.
//  Copyright © 2016 Boris Falcinelli. All rights reserved.
//

import Foundation
import UIKit

public class LIRequest : Equatable {
    
    public static func ==(lhs: LIRequest, rhs: LIRequest) -> Bool {
        return lhs.uniqueIdentifier == rhs.uniqueIdentifier
    }
    
    let uniqueIdentifier : String = NSUUID().uuidString
    public struct LoginData {
        public let username : String
        public let password : String
        
        public init(username u : String, password p : String) {
            username = u
            password = p
        }
    }
    
    /// Indica la chiave Accept nell'header della richiesta
    public var accept : LIRequest.Accept
    
    /// Indica il Content-Type di default impostato nell'inizializzazione dell'oggetto LIRequest
    public var contentType : LIRequest.ContentType
    
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
    internal var progress : Progress!
    
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
    public init() {
        self.accept = LIRequestInstance.shared.accept
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
    
    /// Effettua una chiamata GET all'indirizzo url con i parametri
    ///
    /// - parameter url:    indica l'url a cui sarà indirizzata la chiamata
    /// - parameter params: specifica i parametri da passare al server durante la chiamata
    public func get(toURL url : URL, withParams params : [String:Any]?) {
        LIPrint("Creo nuova chiamata get")
        LIPrint(url.absoluteString)
        self.action(withMethod: .get, toUrl: url, withParams: params)
    }
    
    /// Effettua una chiamata POST all'indirizzo url con i parametri
    ///
    /// - parameter url:    indica l'url a cui sarà indirizzata la chiamata
    /// - parameter params: specifica i parametri da passare al server durante la chiamata
    public func post(toURL url : URL, withParams params : [String:Any]?) {
        LIPrint("Creo nuova chiamata post")
        LIPrint(url.absoluteString)
        self.action(withMethod: .post, toUrl: url, withParams: params)
    }
    
    internal func action(withMethod method:Method, toUrl url : URL, withParams params : [String:Any]?) {
        var request = self.request(forUrl: url,withMethod: method)
        if let par = params {
            var query : [URLQueryItem]
            if let obj = self.objectConversion {
                do {
                    query = try obj(par)
                } catch {
                    query = []
                    LIPrint("Errore nella codifica dei parametri")
                    let error = LIRequestError(forType: .incorrectParametersToSend,withParameters:par)
                    self.failureObjects.forEach({$0(nil,error)})
                }
            } else {
                query = queryString(fromParameter: par)
            }
            switch method {
            case .get:
                insertQueryForGet(query, inRequest: &request)
            case .post:
                insertQueryForPost(query, inRequest: &request)
            }
        }
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = self.showNetworkActivityIndicator
        }
        let task = LIRequestInstance.shared.session.downloadTask(with: request)
        LIRequestInstance.shared.addNewCall(withTask: task, andRequest: self)
        
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
    
    private func insertQueryForPost(_ query : [URLQueryItem],inRequest request : inout URLRequest) {
        request.httpBody = convertItemsToString(query).data(using: self.encoding)
    }
    
    private func convertItemsToString(_ items : [URLQueryItem]) -> String {
        var string = ""
        for (pos,item) in items.enumerated() {
            if pos != 0 {
                string.append("&")
            }
            string += "\(item.name)=\(item.value ?? "")"
        }
        return string
    }
    
    private func insertQueryForGet(_ query : [URLQueryItem], inRequest request : inout URLRequest) {
        if var components = URLComponents(string: request.url!.absoluteString) {
            var items = components.queryItems ?? []
            items.append(contentsOf: query)
            components.queryItems = items
            let url = components.url
            request.url = url
            return
        }
        request.url = URL(string: "\(request.url!)?\(query)")
    }
    
    private func queryString(fromParameter params : [String:Any]) -> [URLQueryItem] {
        var array : [URLQueryItem] = []
        for (key,value) in params {
            array.append(URLQueryItem(name: percentEncoding(forItem: key), value: percentEncoding(forItem: value)))
        }
        return array
    }
    
    private func percentEncoding(forItem item : Any) -> String {
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")

        let val = description(item).addingPercentEncoding(withAllowedCharacters: allowedCharacters)
        assert(val != nil)
        return val!
    }
    
    private func description(_ item : Any) -> String {
        if let val = item as? String {
            return val.description
        } else if let val = item as? NSNumber {
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

    
    public func post(toURL url : URL, withImage image : UIImage, andFileName fileName : String, andParamImageName paramImageName : String?, andParams params : [String:Any]?) {
        LIPrint("Creo richiesta per invio immagine")
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
        let contentTypeData = NSString(string: "Content-Type:\(ContentType.imageJpeg.key)\r\n\r\n").data(using: self.encoding.rawValue)!
        body.append(contentTypeData)
        body.append(imageData)
        let endData = NSString(string: "\r\n").data(using: self.encoding.rawValue)!
        body.append(endData)
        let endBoundaryData = NSString(string:"--\(boundary)--\r\n").data(using: self.encoding.rawValue)!
        body.append(endBoundaryData)
        request.httpBody = body
        
        let task = LIRequestInstance.shared.session.uploadTask(with: request, from: imageData)
        
        
        LIRequestInstance.shared.addNewCall(withTask: task, andRequest: self)
    }
    
    private func request(forUrl url : URL,withMethod method : Method) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.addValue(self.contentType.key, forHTTPHeaderField: "Content-Type")
        request.addValue(self.accept.key, forHTTPHeaderField: "Accept")
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
    public func setIsComplete(overrideDefault override : Bool=false, withObject object : IsCompleteObject?) {
        if override {
            LIPrint("Sovrascrivo blocco complete")
            self.isCompleteObject = object
        } else {
            LIPrint("Aggiungo blocco complete")
            self.setIsComplete(overrideDefault: true, withObject: { (request, success) in
                LIRequestInstance.shared.isCompleteObject?(request,success)
                object?(request,success)
            })
        }
    }
    
    /// Imposta il blocco da eseguire in caso di errore nella chiamata
    ///
    /// - parameter object:   blocco di errore
    /// - parameter override: se true sovrascrive il blocco, altrimenti esegue prima quello delle configurazioni e poi quello passato
    public func setFailure( overrideDefault override : Bool=false,withObject object : @escaping FailureObject) {
        if override {
            LIPrint("Sovrascrivo blocco failure")
            self.failureObjects = [object]
        } else {
            self.addFailure(withObject: object)
        }
    }
    
    /// Aggiunge il blocco in coda ai blocchi già presenti
    ///
    /// - parameter object: blocco del failure
    public func addFailure(withObject object : @escaping FailureObject) {
        LIPrint("Aggiungo blocco failure")
        self.failureObjects.append(object)
    }
    
    /// Imposta il blocco da eseguire in caso di successo nella chiamata
    ///
    /// - parameter object:   blocco di successo
    /// - parameter override: se true sovrascrive il blocco, altrimenti esegue prima quello delle configurazioni e poi quello passato
    public func setSuccess( overrideDefault override : Bool=false,withObject object : @escaping SuccessObject) {
        if override {
            LIPrint("Sovrascrivo blocco success")
            self.successObjects = [object]
        } else {
            self.addSuccess(withObject: object)
        }
    }
    
    /// Aggiunge il blocco in coda ai blocchi già presenti
    ///
    /// - parameter object: blocco di success
    public func addSuccess(withObject object : @escaping SuccessObject) {
        LIPrint("Aggiungo blocco success")
        self.successObjects.append(object)
    }
    
    /// Imposta il blocco da eseguire durante l'avanzamento della chiamata
    ///
    /// - parameter object:   blocco d'avanzamento
    /// - parameter override: se true sovrascrive il blocco, altrimenti esegue prima quello delle configurazioni e poi quello passato
    public func setProgress( overrideDefault override : Bool=false, withObject object : ProgressObject?) {
        if override {
            LIPrint("Sovrascrivo blocco progress")
            self.progressObject = object
        } else {
            LIPrint("Aggiungo blocco progress")
            self.setProgress(overrideDefault: true, withObject: { (progress) in
                LIRequestInstance.shared.progressObject?(progress)
                object?(progress)
            })
        }
    }
    
    /// Imposta il blocco da eseguire per la validazione dei dati
    ///
    /// - parameter object:   blocco di validazione dati
    /// - parameter override: se true sovrascrive il blocco, altrimenti esegue prima quello delle configurazioni e poi quello passato
    public func setValidation(overrideDefault override : Bool=false,withObject object : @escaping ValidationResponseObject) {
        if override {
            LIPrint("Sovrascrivo blocco validazione")
            self.validationResponseObject = object
        } else {
            LIPrint("Aggiungo blocco validazione")
            self.setValidation(overrideDefault: true, withObject: { (response) -> Bool in
                return LIRequestInstance.shared.validationResponseObject(response) && object(response)
            })
        }
    }
    
    /// Rimuove il blocco della validazione dei dati per l'istanza corrente
    public func removeValidation() {
        LIPrint("Rimuovo  blocco validazione")
        self.setValidation(overrideDefault: true, withObject: { (_) -> Bool in
            return true
        })
    }
    
    internal func callSuccess(withObject object : Any?, andMessage message : String?) {
        LIPrint("Chiamo blocco success")
        self.successObjects.forEach { (success) in
            success(object,message)
        }
    }
    
    internal func callFailure(withObject object:Any?,andError error : Error) {
        LIPrint("Chiamo blocco failure")
        self.failureObjects.forEach { (failure) in
            failure(object,error)
        }
    }
}

func LILocalizedString(_ key : String,comment : String) -> String {
    return NSLocalizedString(key, tableName: "LIRequestLocalizable", comment: comment)
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
                return LILocalizedString("ErrorInvalidUrl", comment: "")
            case .errorInResponse:
                return LILocalizedString("ErrorInResponse", comment: "")
            case .noDataInResponse:
                return LILocalizedString("ErrorNoDataInResponse", comment: "")
            case .incorrectResponseContentType:
                return LILocalizedString("ErrorIncorrectContentType", comment: "")
            case .incorrectParametersToSend:
                return LILocalizedString("ErrorIncorrectParametersToSend", comment: "")
            case .incorrectImageToSend:
                return LILocalizedString("ErrorIncorrectImageToSend", comment: "")
            }
        }
        
        internal var recoverySuggestion: String? {
            switch self {
            case .invalidUrl:
                return LILocalizedString("ErrorInvalidUrlSuggestion", comment: "")
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
    
    var parameters : [AnyHashable:Any]!
    
    init(forType type : ErrorType,
        withUrlString url:String?=nil,
        withErrorString string : String? = nil,
        withParameters params : [AnyHashable:Any]? = nil) {
        let domain = "net.labinfo.LIRequest"
        let code = type.rawValue
        self.parameters = params
        var userInfo : [AnyHashable:Any] = [NSLocalizedDescriptionKey:type.errorDescription ?? "",
                                            NSLocalizedFailureReasonErrorKey:type.failureReason ?? "",
                                            NSLocalizedRecoverySuggestionErrorKey:type.recoverySuggestion ?? ""]
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
