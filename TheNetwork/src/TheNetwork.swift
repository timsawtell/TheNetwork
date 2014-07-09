//
//  TSNetworking.swift
//  TSNetworkingSwift
//
//  Created by Tim Sawtell on 11/06/2014.
//
//
import Foundation
import UIKit

typealias NetworkSuccessBlock = (resultObject: AnyObject?, request: NSURLRequest, response: NSURLResponse?) -> Void
typealias NetworkErrorBlock = (resultObject: AnyObject?, error: NSError, request: NSURLRequest?, response: NSURLResponse?) -> Void
typealias NetworkDownloadProgressBlock = (bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) -> Void
typealias NetworkUploadProgressBlock = (bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) -> Void
typealias URLSessionTaskCompletion = (data: NSData!, response: NSURLResponse!, error: NSError!) -> Void
typealias URLSessionDownloadTaskCompletion = (location: NSURL!, error: NSError!) -> Void
typealias SessionCompletionHandler = (() -> Void)!

class BlockHolder {
    // because I can't add a declared instances of the typealias closures (NetworkSuccessBlock et al) to a dictionary, I have to wrap them up. Ugly as sin. Need to find a better way.
    var successBlock: NetworkSuccessBlock?                             // programmer defined success completion block
    var errorBlock: NetworkErrorBlock?                                 // programmer defined error block
    var downloadProgressBlock: NetworkDownloadProgressBlock?           // for downloads
    var uploadProgressBlock: NetworkUploadProgressBlock?               // for uploads
    var downloadCompletionBlock: URLSessionDownloadTaskCompletion?  // for downloads
    var uploadCompletedBlock: URLSessionTaskCompletion?             // for uploads
    var dataTaskData: NSMutableData?                                // for gets/posts/puts etc
    var dataTaskCompletionBlock: URLSessionTaskCompletion?          // for gets/posts/puts etc
}

struct MultipartFormFile {
    var formKeyName: String
    var fileName: String
    var data: NSData
    var mimetype: String
}

enum HTTP_METHOD: String {
    case POST = "POST"
    case GET = "GET"
    case PUT = "PUT"
    case HEAD = "HEAD"
    case DELETE = "DELETE"
    case TRACE = "TRACE"
    case CONNECT = "CONNECT"
    case PATCH = "PATCH"
}

extension String {
    func isSane() -> Bool {
        if self.bridgeToObjectiveC().length == 0
        || self == NSNull()
        || self.bridgeToObjectiveC().isEqualToString("")
        || self.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()) == ""  {
                return false
        }
        return true
    }
}

let Network = TheNetwork()

class TheNetwork: NSObject, NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate, NSURLSessionDataDelegate {
    
    // to be marked private when Swift has access modifiers ...
    var baseURL: NSURL = NSURL.URLWithString("")
    var defaultConfiguration: NSURLSessionConfiguration
    var acceptableStatusCodes: NSIndexSet
    var downloadProgressBlocks = NSMutableDictionary()
    var downloadCompletionBlocks = NSMutableDictionary()
    var uploadProgressBlocks = NSMutableDictionary()
    var uploadCompletionBlocks = NSMutableDictionary()
    var taskDataBlocks = NSMutableDictionary()
    var sessionHeaders = NSMutableDictionary()
    var downloadsToResume = NSMutableDictionary()
    var sharedURLSession = NSURLSession()
    var username = String()
    var password = String()
    var activeTasks = 0
    var sessionCompletionHandler: SessionCompletionHandler
    var securityPolicy: AFSecurityPolicy
    var bodyFormatter: BodyFormatter
    
    init() {
        defaultConfiguration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("au.com.sawtellsoftware.tsnetworking")
        acceptableStatusCodes = NSIndexSet(indexesInRange: NSMakeRange(200, 100))
        securityPolicy = AFSecurityPolicy.defaultPolicy()
        bodyFormatter = BodyFormatterJSON()
        super.init()
        defaultConfiguration.allowsCellularAccess = true
        defaultConfiguration.timeoutIntervalForRequest = 30
        defaultConfiguration.timeoutIntervalForResource = 18000 // 5 hours to download a single resource should be enough. Right?

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleNetworkChange:", name: kReachabilityChangedNotification, object: nil)
        sharedURLSession = NSURLSession(configuration: defaultConfiguration, delegate: self, delegateQueue: nil)
        Reachability.reachabilityForInternetConnection().startNotifier()
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func setSecurityPolicyPinningMode(mode: AFSSLPinningMode) {
        if mode == AFSSLPinningMode.None {
            securityPolicy = AFSecurityPolicy.defaultPolicy()
        } else {
            securityPolicy = AFSecurityPolicy(pinningMode: mode)
        }
    }
    
    func handleNetworkChange(object: AnyObject?) {
        if let notification = object as? NSNotification {
            if let reachability = notification.object as? Reachability {
                if NetworkStatus.NotReachable != reachability.currentReachabilityStatus() {
                    objc_sync_enter(self)
                    resumePausedDownloads()
                    objc_sync_exit(self)
                }
            }
        }
    }
    
    func resumePausedDownloads() -> NSInteger {
        var count = downloadsToResume.count
        for (key, keyValue) in enumerate(downloadsToResume) {
            var dictKeyAsInt = keyValue.key as Int
            downloadProgressBlocks.removeObjectForKey(dictKeyAsInt)
            downloadCompletionBlocks.removeObjectForKey(dictKeyAsInt)
            
            var downloadTask = sharedURLSession.downloadTaskWithResumeData(keyValue.value as NSData)
            dictKeyAsInt = downloadTask.taskIdentifier
            if let progress : AnyObject = downloadProgressBlocks.objectForKey(dictKeyAsInt) {
                downloadProgressBlocks.setObject(progress, forKey: dictKeyAsInt)
            }
            if let completion : AnyObject = downloadCompletionBlocks.objectForKey(dictKeyAsInt) {
                downloadCompletionBlocks.setObject(completion, forKey: dictKeyAsInt)
            }
        }
        downloadsToResume = NSMutableDictionary() // clear it out
        return count
    }
    
    func taskCompletionBlockForRequest(request: NSMutableURLRequest,
        successBlock: NetworkSuccessBlock? = nil,
        errorBlock: NetworkErrorBlock? = nil) -> URLSessionTaskCompletion {
            
        weak var weakSelf = self
        var completionBlock: URLSessionTaskCompletion = { (data: NSData!, response: NSURLResponse!, error: NSError!) -> Void in
            if let strongSelf = weakSelf {
                strongSelf.activeTasks = max(strongSelf.activeTasks - 1, 0)
                if Network.activeTasks == 0 {
                    if let sharedApp = UIApplication.sharedApplication() {
                        sharedApp.networkActivityIndicatorVisible = false
                    }
                }
                
                if let responseError = error {
                    if let realErrorBlock = errorBlock {
                        realErrorBlock(resultObject: nil, error: responseError, request: request, response: response)
                    }
                    return
                } else if let anError = strongSelf.validateResponse(response) {
                    if let realErrorBlock = errorBlock {
                        realErrorBlock(resultObject: nil, error: anError, request: request, response: response)
                    }
                    return
                }
                
                var useableContentType: String
                var encoding: NSStringEncoding = NSUTF8StringEncoding
                var parsedObject: AnyObject? = data
                // is the response an NSHTTPURLResponse?
                // does that response have a content type? 
                // if no to either of these a default value is used to try and parse the response into a usable AnyObject
                if let httpResponse = response as? NSHTTPURLResponse {
                    if let encodingName = httpResponse.textEncodingName  {
                        var tmpEncoding = CFStringConvertIANACharSetNameToEncoding(encodingName.bridgeToObjectiveC() as CFString)
                        if tmpEncoding != kCFStringEncodingInvalidId {
                            encoding = CFStringConvertEncodingToNSStringEncoding(tmpEncoding)
                        }
                    }
                    var responseHeaders = httpResponse.allHeaderFields
                    if let contentType: NSString = responseHeaders["Content-Type"] as? NSString {
                        var useableContentType: NSString = contentType.lowercaseString
                        var location = useableContentType.rangeOfString(";").location
                        if location > 0 && location < useableContentType.length - 1 {
                            useableContentType = useableContentType.substringToIndex(location)
                        }
                        parsedObject = strongSelf.resultBasedOnContentType(useableContentType, encoding: encoding, data: data)
                    } else {
                        parsedObject = strongSelf.resultBasedOnContentType("text", encoding: encoding, data: data)
                    }
                } else {
                    parsedObject = strongSelf.resultBasedOnContentType("text", encoding: encoding, data: data)
                }
                if let realSuccessBlock = successBlock {
                    realSuccessBlock(resultObject: parsedObject, request: request, response: response)
                }
            }
        }
        return completionBlock
    }
    
    func resultBasedOnContentType(contentType: NSString, encoding: NSStringEncoding, data: NSData?) -> AnyObject {
        
        var firstComponent = NSString(), secondComponent = NSString()
        var indexOfSlash: Int = contentType.rangeOfString("/").location
        if indexOfSlash > 0 && indexOfSlash < contentType.length - 1 {
            firstComponent = contentType.substringToIndex(indexOfSlash).lowercaseString
            secondComponent = contentType.substringFromIndex(indexOfSlash + 1).lowercaseString
        } else {
            firstComponent = contentType.lowercaseString
        }
        
        var parseError: NSError?
        if secondComponent.containsString("json") || secondComponent.containsString("javascript") {
            if let parsedJSON: AnyObject = NSJSONSerialization.JSONObjectWithData(data, options: .MutableContainers, error: &parseError) {
                return parsedJSON
            }
        } else if secondComponent.containsString("x-plist") {
            var format: NSPropertyListFormat?
            if let parsedXML: AnyObject = NSPropertyListSerialization.propertyListWithData(data, options: 0, format: nil, error: &parseError) {
                return parsedXML
            }
        }
        
        var parsedString = NSString(data: data, encoding: encoding)
        return parsedString
    }
    
    func validateResponse(response: NSURLResponse?) -> NSError? {
        if let httpResponse = response as? NSHTTPURLResponse {
            if !acceptableStatusCodes.containsIndex(httpResponse.statusCode) {
                var text = "Request failed: \(NSHTTPURLResponse.localizedStringForStatusCode(httpResponse.statusCode)) (\(httpResponse.statusCode))"
                var converted = NSLocalizedString(text, comment: "")
                let error = NSError.errorWithDomain(NSURLErrorDomain, code: httpResponse.statusCode, userInfo:NSDictionary(object: text, forKey: NSLocalizedDescriptionKey))
                return error
            }
        } else if nil == response {
            var text = NSLocalizedString("No response", comment: "")
            let error = NSError.errorWithDomain(NSURLErrorDomain, code: 500, userInfo:NSDictionary(object: text, forKey: NSLocalizedDescriptionKey))
            return error
        }
        
        return nil
    }
    
    func addHeaders(headers: NSDictionary?, request: NSMutableURLRequest) {
        if username.isSane() && password.isSane() {
            var base64Encoded = "Basic " + String("\(username):\(password)").dataUsingEncoding(NSUTF8StringEncoding)!.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.fromRaw(0)!)
            request.setValue(base64Encoded, forHTTPHeaderField: "Authorization")
        }
        if let additionalHeaders = headers {
            for keyVal in additionalHeaders {
                if let existing = request.valueForHTTPHeaderField(keyVal.key as String) {} else {
                    request.addValue(keyVal.value as String, forHTTPHeaderField: keyVal.key as String)
                }
            }
        }
        for keyVal in sessionHeaders {
            if let existing = request.valueForHTTPHeaderField(keyVal.key as String) {} else {
                request.addValue(keyVal.value as String, forHTTPHeaderField: keyVal.key as String)
            }
        }
    }
    
    // PUBLIC (when apple get around to giving us access modifiers like private and protected etc)
    
    func setBaseURLString(baseURLString: NSString) {
        baseURL = NSURL.URLWithString(baseURLString.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding))
    }
    
    func setBasicAuth(#user: NSString, pass: NSString) {
        username = user
        password = pass
    }
    
    func addSessionHeaders(headers: NSDictionary) {
        sessionHeaders.addEntriesFromDictionary(headers)
    }
    
    func removeAllSessionHeaders() {
        sessionHeaders = NSMutableDictionary()
    }
    
    func addDownloadProgressBlock(progressBlock: NetworkDownloadProgressBlock, task: NSURLSessionTask) {
        switch task.state {
        case .Running, .Suspended:
            var holder = BlockHolder()
            holder.downloadProgressBlock = progressBlock
            downloadProgressBlocks.setObject(holder, forKey: task.taskIdentifier)
            
        default:
            break
        }
    }
    
    func addUploadProgressBlock(progressBlock: NetworkUploadProgressBlock, task: NSURLSessionTask) {
        if NSURLSessionTaskState.Running == task.state {
            var holder = BlockHolder()
            holder.uploadProgressBlock = progressBlock
            uploadProgressBlocks.setObject(holder, forKey: task.taskIdentifier)
        }
    }
    
    func removeQueuedDownloadForTask(task: NSURLSessionTask) {
        // Use case that this covers: you lose network connection while a download is in progress. TSNetworking adds the downloaded data
        // to downloadsToResume. You then cancel the download while you are offline (through UI). We need to remove the saved
        // data in downloadsToResume for this download task so that it doesn't automatically start again when we finally get network
        // access again (dl starts again in - (NSInteger)resumePausedDownloads;)
        
        for keyVal in downloadsToResume {
            if (keyVal.key.isKindOfClass(NSNumber.self)) { return }
            
            if task.taskIdentifier === keyVal.key {
                activeTasks = max(activeTasks - 1, 0)
                if (Network.activeTasks == 0 ) {
                    if let sharedApp = UIApplication.sharedApplication() {
                        sharedApp.networkActivityIndicatorVisible = false
                    }
                }
                downloadProgressBlocks.removeObjectForKey(keyVal.key)
                downloadCompletionBlocks.removeObjectForKey(keyVal.key)
                downloadsToResume.removeObjectForKey(keyVal.key)
                break
            }
        }
    }
    
    func performDataTask(#relativePath: NSString?,
        method: HTTP_METHOD,
        successBlock: NetworkSuccessBlock? = nil,
        errorBlock: NetworkErrorBlock? = nil,
        parameters: NSDictionary? = nil,
        additionalHeaders: NSDictionary? = nil) ->NSURLSessionDataTask {
            
        var requestURL = baseURL
        if let suppliedPath = relativePath {
            requestURL = requestURL.URLByAppendingPathComponent(suppliedPath)
        }
        var request = NSMutableURLRequest(URL: requestURL, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData, timeoutInterval: defaultConfiguration.timeoutIntervalForRequest)
        request.HTTPMethod = method.toRaw()
            
        switch method {
        case HTTP_METHOD.POST, HTTP_METHOD.PUT, HTTP_METHOD.PATCH:
            // The body formatter based on either the `paramters` (if there are any) or the manual body formatter block will be run to assign data to request.HTTPBody
            if let error = bodyFormatter.formatData(parameters, userRequest:request) {
                NSLog("Error attempting to format request body: \(error.localizedDescription). Using no HTTPBody this request.");
            }
            
        default:
            if let params = parameters { // make sure that the user has actually supplied some parameters
                var urlString = request.URL.absoluteString.bridgeToObjectiveC()
                var range = urlString.rangeOfString("?")
                var addQMark = false
                if let locOfQMark = Int?(range.location) {
                    addQMark = locOfQMark > 0
                }
                for keyVal in params {
                    if addQMark {
                        urlString = urlString.stringByAppendingString("?\(keyVal.key)=\(keyVal.value)")
                        addQMark = false
                    } else {
                        urlString = urlString.stringByAppendingString("&\(keyVal.key)=\(keyVal.value)")
                    }
                }
                request.URL = NSURL(string: urlString.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding))
            }
        }
        
        var completionBlock: URLSessionTaskCompletion = taskCompletionBlockForRequest(request, successBlock: successBlock, errorBlock: errorBlock)
        addHeaders(additionalHeaders, request: request)
        var task = sharedURLSession.dataTaskWithRequest(request, nil)
        
        var holder = BlockHolder()
        holder.dataTaskCompletionBlock = completionBlock
        taskDataBlocks.setObject(holder, forKey: task.taskIdentifier)
        if let sharedApp = UIApplication.sharedApplication() {
            sharedApp.networkActivityIndicatorVisible = true
        }
        activeTasks++
        task.resume()
        return task
    }
    
    func download(#fullSourceURL: NSString,
        destinationPathString: NSString,
        successBlock: NetworkSuccessBlock? = nil,
        errorBlock: NetworkErrorBlock? = nil,
        progressBlock: NetworkDownloadProgressBlock? = nil,
        additionalHeaders: NSDictionary? = nil) -> NSURLSessionDownloadTask {
            
        var request = NSMutableURLRequest(URL: NSURL(string: fullSourceURL.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)))
        request.HTTPMethod = HTTP_METHOD.GET.toRaw()
        
        weak var weakSelf = self
        
        var completionBlock: URLSessionDownloadTaskCompletion = { (location: NSURL!, error: NSError!) -> Void in
            if let strongSelf = weakSelf {
                strongSelf.activeTasks = max(strongSelf.activeTasks - 1, 0)
                if Network.activeTasks == 0 {
                    if let sharedApp = UIApplication.sharedApplication() {
                        sharedApp.networkActivityIndicatorVisible = false
                    }
                }
                
                if let realError = error {
                    if let realErrorBlock = errorBlock {
                        realErrorBlock(resultObject: nil, error: realError, request: request, response: nil)
                    }
                    return
                }
                
                if let tempLocation = location {
                    var fm = NSFileManager()
                    // does the downloaded file exist?
                    
                    if !fm.fileExistsAtPath(tempLocation.path) {
                        // aint this some shit, it finished without error, but the file is not available at location
                        var text = NSLocalizedString("Unable to locate downloaded file", comment: "")
                        let notFoundError = NSError.errorWithDomain(NSURLErrorDomain, code: NSURLErrorCannotOpenFile, userInfo:NSDictionary(object: text, forKey: NSLocalizedDescriptionKey))
                        if let realErrorBlock = errorBlock {
                            realErrorBlock(resultObject: nil, error: notFoundError, request: request, response: nil)
                        }
                        return
                    }
                    
                    // delete an existing file at the programmers destination path string
                    var fileBasedError: NSError?
                    if fm.fileExistsAtPath(destinationPathString) {
                        fm.removeItemAtPath(destinationPathString, error: &fileBasedError)
                    }
                    
                    if nil != fileBasedError {
                        // son of a bitch
                        var text = NSLocalizedString("Download success, however destination path already exists, and that file was unable to be deleted", comment: "")
                        let cantDeleteError = NSError.errorWithDomain(NSURLErrorDomain, code: NSURLErrorCannotRemoveFile, userInfo:NSDictionary(object: text, forKey: NSLocalizedDescriptionKey))
                        if let realErrorBlock = errorBlock {
                            realErrorBlock(resultObject: nil, error: cantDeleteError, request: request, response: nil)
                        }
                        return
                    }
                    
                    // move the file to the programmers destination
                    fm.moveItemAtPath(tempLocation.path, toPath:destinationPathString, error:&fileBasedError)
                    if nil != fileBasedError {
                        // double son of a bitch
                        var text = NSLocalizedString("Download success, however unable to move downloaded file to the destination path.", comment: "")
                        let cantMoveError = NSError.errorWithDomain(NSURLErrorDomain, code: NSURLErrorCannotRemoveFile, userInfo:NSDictionary(object: text, forKey: NSLocalizedDescriptionKey))
                        if let realErrorBlock = errorBlock {
                            realErrorBlock(resultObject: nil, error: cantMoveError, request: request, response: nil)
                        }
                        return
                    }
                    // all worked as intended
                    var finalLocation = NSURL(fileURLWithPath: destinationPathString)
                    if let realSuccessBlock = successBlock {
                        realSuccessBlock(resultObject: finalLocation, request: request, response: nil)
                    }
                    return
                }
                
                var text = NSLocalizedString("Unable to locate downloaded file.", comment: "")
                let cantFindError = NSError.errorWithDomain(NSURLErrorDomain, code: NSURLErrorCannotRemoveFile, userInfo:NSDictionary(object: text, forKey: NSLocalizedDescriptionKey))
                if let realErrorBlock = errorBlock {
                    realErrorBlock(resultObject: nil, error: cantFindError, request: request, response: nil)
                }
            }
        }
        
        addHeaders(additionalHeaders, request: request)
        var downloadTask = sharedURLSession.downloadTaskWithRequest(request)
        if let realProgressBlock = progressBlock {
            var holder = BlockHolder()
            holder.downloadProgressBlock = realProgressBlock
            downloadProgressBlocks.setObject(holder, forKey: downloadTask.taskIdentifier)
        }
        var holder = BlockHolder()
        holder.downloadCompletionBlock = completionBlock
        downloadCompletionBlocks.setObject(holder, forKey: downloadTask.taskIdentifier)
        if let sharedApp = UIApplication.sharedApplication() {
            sharedApp.networkActivityIndicatorVisible = true
        }
        activeTasks++
        downloadTask.resume()
        return downloadTask
    }
    
    func upload(#sourceURL: NSURL,
        destinationFullURLString: NSString,
        successBlock: NetworkSuccessBlock? = nil,
        errorBlock: NetworkErrorBlock? = nil,
        progressBlock: NetworkUploadProgressBlock? = nil,
        additionalHeaders: NSDictionary? = nil) -> NSURLSessionUploadTask {
        
        var fm = NSFileManager()
        var error: NSError?
       
        var request = NSMutableURLRequest(URL: NSURL(string: destinationFullURLString.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)))
        request.HTTPMethod = HTTP_METHOD.POST.toRaw()
        var completionBlock = taskCompletionBlockForRequest(request, successBlock: successBlock, errorBlock: errorBlock)
        addHeaders(additionalHeaders, request: request)
        var uploadTask = sharedURLSession.uploadTaskWithRequest(request, fromFile:sourceURL)

        if let realProgressBlock = progressBlock {
            var holder = BlockHolder()
            holder.uploadProgressBlock = realProgressBlock
            uploadProgressBlocks.setObject(holder, forKey: uploadTask.taskIdentifier)
        }

        var holder = BlockHolder()
        holder.uploadCompletedBlock = completionBlock
        uploadCompletionBlocks.setObject(holder, forKey: uploadTask.taskIdentifier)
        
        var dataHolder = BlockHolder() // so that the server's response to the upload can be captured
        taskDataBlocks.setObject(dataHolder, forKey: uploadTask.taskIdentifier)
            
        if let sharedApp = UIApplication.sharedApplication() {
            sharedApp.networkActivityIndicatorVisible = true
        }
        activeTasks++
        uploadTask.resume()
        return uploadTask
    }
    
    func multipartFormPost(#relativePath: NSString?,
        parameters: NSDictionary? = nil,
        multipartFormFiles: [MultipartFormFile]? = nil,
        successBlock: NetworkSuccessBlock? = nil,
        errorBlock: NetworkErrorBlock? = nil,
        additionalHeaders: NSDictionary? = nil) ->NSURLSessionDataTask {
        
        var requestURL = baseURL
        if let suppliedPath = relativePath {
            requestURL = requestURL.URLByAppendingPathComponent(suppliedPath)
        }
        var request = NSMutableURLRequest(URL: requestURL, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData, timeoutInterval: defaultConfiguration.timeoutIntervalForRequest)
        request.HTTPMethod = HTTP_METHOD.POST.toRaw()
        let boundary = "Z2FiZW5pc2xvdmVnYWJlbmlzbGlmZQ=="
        let contentType = "multipart/form-data; boundary=\(boundary)"

        var body = NSMutableData(data: String("--\(boundary)\r\n").dataUsingEncoding(NSUTF8StringEncoding))
        
        if let params = parameters {
            for (key, keyValue) in enumerate(params) {
                body.appendData(String("Content-Disposition: form-data; name=\"\(keyValue.key)\"\r\n\r\n\(keyValue.value)\r\n--\(boundary)\r\n").dataUsingEncoding(NSUTF8StringEncoding))
            }
        }
        
        if let files = multipartFormFiles {
            for file in files {
                body.appendData(String("Content-Disposition: form-data; name=\"\(file.formKeyName)\"; filename=\"\(file.fileName)\"\r\n").dataUsingEncoding(NSUTF8StringEncoding))
                body.appendData(String("Content-Type: \(file.mimetype)\r\n").dataUsingEncoding(NSUTF8StringEncoding))
                body.appendData(String("Content-Transfer-Encoding: binary\r\n\r\n").dataUsingEncoding(NSUTF8StringEncoding))
                body.appendData(file.data)
                body.appendData(String("\r\n--\(boundary)\r\n").dataUsingEncoding(NSUTF8StringEncoding))
            }
        }
        
        var headers = NSMutableDictionary(object: contentType, forKey: "Content-Type")
        headers.setValue("\(body.length)", forKey: "Content-Length")
        if let userHeaders = additionalHeaders {
            headers.addEntriesFromDictionary(userHeaders)
        }
        addHeaders(headers, request: request)
        request.HTTPBody = body
        
        var completionBlock: URLSessionTaskCompletion = taskCompletionBlockForRequest(request, successBlock: successBlock, errorBlock: errorBlock)

        var task = sharedURLSession.dataTaskWithRequest(request, nil)
        
        var holder = BlockHolder()
        holder.dataTaskCompletionBlock = completionBlock
        taskDataBlocks.setObject(holder, forKey: task.taskIdentifier)
            
        if let sharedApp = UIApplication.sharedApplication() {
            sharedApp.networkActivityIndicatorVisible = true
        }
        activeTasks++
        task.resume()
        return task
    }
    
    // NSURLSessionDelegate
    func URLSession(session: NSURLSession!, didReceiveChallenge challenge: NSURLAuthenticationChallenge!, completionHandler: ((NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void)!) {
        var disposition = NSURLSessionAuthChallengeDisposition.PerformDefaultHandling
        var credential: NSURLCredential? = nil
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if securityPolicy.evaluateServerTrust(challenge.protectionSpace.serverTrust, forDomain: challenge.protectionSpace.host) {
                disposition = .UseCredential
                credential = NSURLCredential(forTrust: challenge.protectionSpace.serverTrust)
            } else {
                disposition = .CancelAuthenticationChallenge
            }
        } else {
            disposition = .CancelAuthenticationChallenge
        }
        if let handler = completionHandler {
            handler(disposition, credential)
        }
    }
    
    func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession!) {
        if let completionHandler = sessionCompletionHandler {
            completionHandler()
            sessionCompletionHandler = nil
        }
    }
    
    func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask!, didReceiveData data: NSData!) {

        if let blockHolder: BlockHolder = taskDataBlocks.objectForKey(dataTask.taskIdentifier) as? BlockHolder {
            if nil == blockHolder.dataTaskData {
                blockHolder.dataTaskData = NSMutableData()
            }
            blockHolder.dataTaskData?.appendData(data)
        }
    }
    
    // NSURLSessionTaskDelegate
    
    func URLSession(session: NSURLSession!, task: NSURLSessionTask!, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        if let blockHolder: BlockHolder = uploadProgressBlocks.objectForKey(task.taskIdentifier) as? BlockHolder {
            if let progress: NetworkUploadProgressBlock = blockHolder.uploadProgressBlock {
                dispatch_async(dispatch_get_main_queue(), {
                    progress(bytesSent: bytesSent, totalBytesSent: totalBytesSent, totalBytesExpectedToSend: totalBytesExpectedToSend)
                    })
            }
        }
    }
    
    // NSURLSessionDownloadDelegate
    /*
    * I have to listen to the 3 delegate methods for the downloadTask instead of assigning
    * a single completionblock when I created the downloadTask. I also have to keep a local
    * dictionary of progress and completion blocks due to this protocol
    */
    
    func URLSession(session: NSURLSession!, task: NSURLSessionTask!, didCompleteWithError error: NSError!) {
        
        // if it finishes with error, but has downloaded data, and we have network access: resume the download.
        // if it finishes with error, but has downloaded data, and we do not have network access: save the task (and data) to retry later
        if let realError = error {
            if let downloadedData = error.userInfo[NSURLSessionDownloadTaskResumeData] as? NSData {
                if (NetworkStatus.NotReachable != Reachability.reachabilityForInternetConnection().currentReachabilityStatus()) {
                    sharedURLSession.downloadTaskWithResumeData(downloadedData)
                } else {
                    downloadsToResume.setObject(downloadedData, forKey:task.taskIdentifier)
                }
                return
            }
        }
         // it didn't fail, so remove the paused download task if it existed in the downloadsToResume dict.
        downloadsToResume.removeObjectForKey(task.taskIdentifier)

        // We can be in this method at the end of the 4 API methods for TSNetworkingSwift: performDataTask, upload, download, multipartFormPost
        if let blockHolder: BlockHolder = uploadCompletionBlocks.objectForKey(task.taskIdentifier) as? BlockHolder {
            if let uploadCompletionBlock = blockHolder.uploadCompletedBlock {
                var data: NSData? = nil
                // try and find the data that was written via URLSession(session:, dataTask:, didReceiveData data:)
                if let dataBlockHolder: BlockHolder = taskDataBlocks.objectForKey(task.taskIdentifier) as? BlockHolder {
                    data = dataBlockHolder.dataTaskData
                    taskDataBlocks.removeObjectForKey(task.taskIdentifier)
                }
                uploadCompletionBlock(data: data, response: task.response, error: error)
            }
            uploadCompletionBlocks.removeObjectForKey(task.taskIdentifier) // remove the block holder as its served its purpose
            uploadProgressBlocks.removeObjectForKey(task.taskIdentifier) // no need to hold on to the progress block for a completed task
            
        } else if let blockHolder: BlockHolder = downloadCompletionBlocks.objectForKey(task.taskIdentifier) as? BlockHolder {
            // why this is here? If a user cancels a download before it's finished
            if let downloadCompletionBlock = blockHolder.downloadCompletionBlock {
                downloadCompletionBlock(location: nil, error: error)
            }
            downloadCompletionBlocks.removeObjectForKey(task.taskIdentifier) // remove the block holder as its served its purpose
            downloadProgressBlocks.removeObjectForKey(task.taskIdentifier) // no need to hold on to the progress block for a completed task
            
        } else if let blockHolder: BlockHolder = taskDataBlocks.objectForKey(task.taskIdentifier) as? BlockHolder {
            if let dataTaskCompletionBlock = blockHolder.dataTaskCompletionBlock {
                dataTaskCompletionBlock(data: blockHolder.dataTaskData?, response: task.response, error: error)
            }
            taskDataBlocks.removeObjectForKey(task.taskIdentifier)
        }
        
    }
    
    func URLSession(session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        if let blockHolder: BlockHolder = downloadProgressBlocks.objectForKey(downloadTask.taskIdentifier) as? BlockHolder {
            if let progress = blockHolder.downloadProgressBlock {
                dispatch_async(dispatch_get_main_queue(), {
                    progress(bytesWritten: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
                    })
            }
        }
    }
    
    func URLSession(session: NSURLSession!, downloadTask: NSURLSessionDownloadTask!, didFinishDownloadingToURL location: NSURL!) {
        
        if let blockHolder: BlockHolder = downloadCompletionBlocks.objectForKey(downloadTask.taskIdentifier) as? BlockHolder {
            if let completionBlock = blockHolder.downloadCompletionBlock {
                completionBlock(location: location, error: nil)
            }
            downloadCompletionBlocks.removeObjectForKey(downloadTask.taskIdentifier)
            downloadProgressBlocks.removeObjectForKey(downloadTask.taskIdentifier)
        }
    }
}
