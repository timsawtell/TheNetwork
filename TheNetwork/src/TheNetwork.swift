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
typealias URLSessionTaskCompletion = (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void
typealias URLSessionDownloadTaskCompletion = (location: NSURL!, error: NSError!) -> Void
typealias SessionCompletionHandler = (() -> Void)!

class BlockHolder {
    // because I can't add a declared instances of the typealias closures (NetworkSuccessBlock et al) to a dictionary, I have to wrap them up. Ugly as sin. Need to find a better way.
    var successBlock: NetworkSuccessBlock?                             // programmer defined success completion block
    var errorBlock: NetworkErrorBlock?                                 // programmer defined error block
    var downloadProgressBlock: NetworkDownloadProgressBlock?           // for downloads
    var uploadProgressBlock: NetworkUploadProgressBlock?               // for uploads
    var downloadCompletionBlock: URLSessionDownloadTaskCompletion?      // for downloads
    var uploadCompletedBlock: URLSessionTaskCompletion?                 // for uploads
    var dataTaskData: NSMutableData?                                    // for gets/posts/puts etc
    var dataTaskCompletionBlock: URLSessionTaskCompletion?              // for gets/posts/puts etc
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
        if self.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) == 0
        || self == NSNull()
        || self == ""
        || self.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()) == ""  {
                return false
        }
        return true
    }
}

let Network = TheNetwork() // global variable (singleton)

class TheNetwork: NSObject, NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate, NSURLSessionDataDelegate {
    
    private var baseURL: NSURL = NSURL(string: "")!
    private var defaultConfiguration: NSURLSessionConfiguration
    private var acceptableStatusCodes: NSIndexSet
    private var downloadProgressBlocks = NSMutableDictionary()
    private var downloadCompletionBlocks = NSMutableDictionary()
    private var uploadProgressBlocks = NSMutableDictionary()
    private var uploadCompletionBlocks = NSMutableDictionary()
    private var taskDataBlocks = NSMutableDictionary()
    private var sessionHeaders = Dictionary<String, String>()
    private var downloadsToResume = NSMutableDictionary()
    private var sharedURLSession = NSURLSession()
    private var username = String()
    private var password = String()
    private var activeTasks = 0
    private var securityPolicy: AFSecurityPolicy
    var bodyFormatter: BodyFormatter
    var sessionCompletionHandler: SessionCompletionHandler
    
    override init() {
        defaultConfiguration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("au.com.sawtellsoftware.thenetwork")
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
        let count = downloadsToResume.count
        for (_, keyValue) in downloadsToResume.enumerate() {
            var dictKeyAsInt = keyValue.key as! Int
            downloadProgressBlocks.removeObjectForKey(dictKeyAsInt)
            downloadCompletionBlocks.removeObjectForKey(dictKeyAsInt)
            
            let downloadTask = sharedURLSession.downloadTaskWithResumeData(keyValue.value as! NSData)
            dictKeyAsInt = downloadTask!.taskIdentifier
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
    
    private func taskCompletionBlockForRequest(request: NSMutableURLRequest,
        successBlock: NetworkSuccessBlock? = nil,
        errorBlock: NetworkErrorBlock? = nil) -> URLSessionTaskCompletion {
            
        weak var weakSelf = self
        let completionBlock: URLSessionTaskCompletion = { (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void in
            if let strongSelf = weakSelf {
                strongSelf.activeTasks = max(strongSelf.activeTasks - 1, 0)
                if Network.activeTasks == 0 {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
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
                
                var encoding: NSStringEncoding = NSUTF8StringEncoding
                var parsedObject: AnyObject? = data
                // is the response an NSHTTPURLResponse?
                // does that response have a content type? 
                // if no to either of these a default value is used to try and parse the response into a usable AnyObject
                if let httpResponse = response as? NSHTTPURLResponse {
                    if let encodingName = httpResponse.textEncodingName as String? {
                        let encodingNameString = encodingName as NSString as CFStringRef
                        encoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding(encodingNameString))
                        
                        if encoding == UInt(kCFStringEncodingInvalidId) {
                            encoding = NSUTF8StringEncoding; // by default
                        }
                    }
                    var responseHeaders = httpResponse.allHeaderFields
                    if let contentType: NSString = responseHeaders["Content-Type"] as? NSString {
                        var useableContentType: NSString = contentType.lowercaseString
                        let location = useableContentType.rangeOfString(";").location
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
    
    private func resultBasedOnContentType(contentType: NSString, encoding: NSStringEncoding, data: NSData?) -> AnyObject {
        
        var secondComponent = NSString()
        let indexOfSlash: Int = contentType.rangeOfString("/").location
        if indexOfSlash > 0 && indexOfSlash < contentType.length - 1 {
            secondComponent = contentType.substringFromIndex(indexOfSlash + 1).lowercaseString
        }
        var parsedString = ""
        if let realData = data {
            if secondComponent.containsString("json") || secondComponent.containsString("javascript") {
                do {
                    let parsedJSON: AnyObject = try NSJSONSerialization.JSONObjectWithData(realData, options: .MutableContainers)
                    return parsedJSON
                } catch  {
                    return data!
                }
            } else if secondComponent.containsString("x-plist") {
                do {
                    let parsedXML: AnyObject = try NSPropertyListSerialization.propertyListWithData(realData, options: NSPropertyListReadOptions.Immutable, format: nil)
                    return parsedXML
                } catch {
                    return data!
                }
            }
            
            parsedString = NSString(data: realData, encoding: encoding)! as String
        }
        
        return parsedString
    }
    
    private func validateResponse(response: NSURLResponse?) -> NSError? {
        if let httpResponse = response as? NSHTTPURLResponse {
            if !acceptableStatusCodes.containsIndex(httpResponse.statusCode) {
                let text = "Request failed: \(NSHTTPURLResponse.localizedStringForStatusCode(httpResponse.statusCode)) (\(httpResponse.statusCode))"
                let error = NSError(domain: NSURLErrorDomain, code: httpResponse.statusCode, userInfo:NSDictionary(object: text, forKey: NSLocalizedDescriptionKey) as [NSObject : AnyObject])
                return error
            }
        } else if nil == response {
            let text = NSLocalizedString("No response", comment: "")
            let error = NSError(domain: NSURLErrorDomain, code: 500, userInfo:NSDictionary(object: text, forKey: NSLocalizedDescriptionKey) as [NSObject : AnyObject])
            return error
        }
        
        return nil
    }
    
    private func addHeaders(headers: NSDictionary?, request: NSMutableURLRequest) {
        if username.isSane() && password.isSane() {
            let encodedStringData = String("\(username):\(password)").dataUsingEncoding(NSUTF8StringEncoding)!
            let base64String = encodedStringData.base64EncodedStringWithOptions(NSDataBase64EncodingOptions())
            let finalString = "Basic " + base64String
            request.setValue(finalString, forHTTPHeaderField: "Authorization")
        }
        if let additionalHeaders = headers {
            for keyVal in additionalHeaders {
                if (request.valueForHTTPHeaderField(keyVal.key as! String) == nil) {
                    request.addValue((keyVal.value as? String)!, forHTTPHeaderField: keyVal.key as! String)
                }
            }
        }
        for (key, val) in sessionHeaders {
            if (request.valueForHTTPHeaderField(key) == nil) {
                request.addValue(val, forHTTPHeaderField: key)
            }
        }
    }
    
    func setBaseURLString(baseURLString: NSString) {
        baseURL = NSURL(string: baseURLString.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!)!
    }
    
    func setBasicAuth(user user: String, pass: String) {
        username = user
        password = pass
    }
    
    func addSessionHeaders(headers: Dictionary<String, String>) {
        for (key, value) in headers {
            sessionHeaders[key] = value
        }
    }
    
    func removeAllSessionHeaders() {
        sessionHeaders = Dictionary<String, String>()
    }
    
    func addDownloadProgressBlock(progressBlock: NetworkDownloadProgressBlock, task: NSURLSessionTask) {
        switch task.state {
        case .Running, .Suspended:
            let holder = BlockHolder()
            holder.downloadProgressBlock = progressBlock
            downloadProgressBlocks.setObject(holder, forKey: task.taskIdentifier)
            
        default:
            break
        }
    }
    
    func addUploadProgressBlock(progressBlock: NetworkUploadProgressBlock, task: NSURLSessionTask) {
        if NSURLSessionTaskState.Running == task.state {
            let holder = BlockHolder()
            holder.uploadProgressBlock = progressBlock
            uploadProgressBlocks.setObject(holder, forKey: task.taskIdentifier)
        }
    }
    
    func removeQueuedDownloadForTask(task: NSURLSessionTask) {
        // Use case that this covers: you lose network connection while a download is in progress. TheNetwork adds the downloaded data
        // to downloadsToResume. You then cancel the download while you are offline (through UI). We need to remove the saved
        // data in downloadsToResume for this download task so that it doesn't automatically start again when we finally get network
        // access again (dl starts again in - (NSInteger)resumePausedDownloads;)
        
        for keyVal in downloadsToResume {
            if (keyVal.key.isKindOfClass(NSNumber.self)) { return }
            
            if task.taskIdentifier == keyVal.key as? Int {
                activeTasks = max(activeTasks - 1, 0)
                if (Network.activeTasks == 0 ) {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                }
                downloadProgressBlocks.removeObjectForKey(keyVal.key)
                downloadCompletionBlocks.removeObjectForKey(keyVal.key)
                downloadsToResume.removeObjectForKey(keyVal.key)
                break
            }
        }
    }
    
    func performDataTask(relativePath relativePath: String?,
        method: HTTP_METHOD,
        parameters: NSDictionary? = nil,
        additionalHeaders: NSDictionary? = nil,
        successBlock: NetworkSuccessBlock? = nil,
        errorBlock: NetworkErrorBlock? = nil) ->NSURLSessionDataTask? {
            
        var requestURL = baseURL
        if let suppliedPath = relativePath {
            requestURL = requestURL.URLByAppendingPathComponent(suppliedPath)
        }
        let request = NSMutableURLRequest(URL: requestURL, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData, timeoutInterval: defaultConfiguration.timeoutIntervalForRequest)
        request.HTTPMethod = method.rawValue
            
        switch method {
        case HTTP_METHOD.POST, HTTP_METHOD.PUT, HTTP_METHOD.PATCH:
            // The body formatter based on either the `paramters` (if there are any) or the manual body formatter block will be run to assign data to request.HTTPBody
            if let error = bodyFormatter.formatData(parameters, userRequest:request) {
                NSLog("Error attempting to format request body: \(error.localizedDescription). Using no HTTPBody this request.");
            }
            
        default:
            if let params = parameters { // make sure that the user has actually supplied some parameters
                var urlString = request.URL?.absoluteString
                var addQMark = true
                let start = urlString!.startIndex
                let end = (urlString!).characters.indexOf("?")
                if end > start {
                    addQMark = false
                }
                for keyVal in params {
                    if addQMark {
                        urlString = urlString! + ("?\(keyVal.key)=\(keyVal.value)")
                        addQMark = false
                    } else {
                        urlString = urlString! + ("&\(keyVal.key)=\(keyVal.value)")
                    }
                }
                
                request.URL = NSURL(string: urlString!.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!)
            }
        }
        
        let completionBlock: URLSessionTaskCompletion = taskCompletionBlockForRequest(request, successBlock: successBlock, errorBlock: errorBlock)
        addHeaders(additionalHeaders, request: request)
        if let task = sharedURLSession.dataTaskWithRequest(request) {
            let holder = BlockHolder()
            holder.dataTaskCompletionBlock = completionBlock
            taskDataBlocks.setObject(holder, forKey: task.taskIdentifier)
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            activeTasks++
            task.resume()
            return task
        }
        return nil
    }
    
    func download(fullSourceURL fullSourceURL: String,
        destinationPathString: String,
        additionalHeaders: NSDictionary? = nil,
        successBlock: NetworkSuccessBlock? = nil,
        errorBlock: NetworkErrorBlock? = nil,
        progressBlock: NetworkDownloadProgressBlock? = nil) -> NSURLSessionDownloadTask? {
            
        let request = NSMutableURLRequest(URL: NSURL(string: fullSourceURL.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!)!)
        request.HTTPMethod = HTTP_METHOD.GET.rawValue
        
        weak var weakSelf = self
        
        let completionBlock: URLSessionDownloadTaskCompletion = { (location: NSURL!, error: NSError!) -> Void in
            if let strongSelf = weakSelf {
                strongSelf.activeTasks = max(strongSelf.activeTasks - 1, 0)
                if Network.activeTasks == 0 {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                }
                
                if let realError = error {
                    if let realErrorBlock = errorBlock {
                        realErrorBlock(resultObject: nil, error: realError, request: request, response: nil)
                    }
                    return
                }
                
                if let tempLocation = location {
                    let fm = NSFileManager()
                    // does the downloaded file exist?
                    
                    if !fm.fileExistsAtPath(tempLocation.path!) {
                        // aint this some shit, it finished without error, but the file is not available at location
                        let text = NSLocalizedString("Unable to locate downloaded file", comment: "")
                        let notFoundError = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotOpenFile, userInfo:NSDictionary(object: text, forKey: NSLocalizedDescriptionKey) as [NSObject : AnyObject])
                        if let realErrorBlock = errorBlock {
                            realErrorBlock(resultObject: nil, error: notFoundError, request: request, response: nil)
                        }
                        return
                    }
                    
                    // delete an existing file at the programmers destination path string

                    if fm.fileExistsAtPath(destinationPathString as String) {
                        do {
                            try fm.removeItemAtPath(destinationPathString)
                        } catch {
                            let text = NSLocalizedString("Download success, however destination path already exists, and that file was unable to be deleted", comment: "")
                            let cantDeleteError = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotRemoveFile, userInfo:NSDictionary(object: text, forKey: NSLocalizedDescriptionKey) as [NSObject : AnyObject])
                            if let realErrorBlock = errorBlock {
                                realErrorBlock(resultObject: nil, error: cantDeleteError, request: request, response: nil)
                            }
                            return
                        }
                    }
                    
                    do {
                        // move the file to the programmers destination
                        try fm.moveItemAtPath(tempLocation.path!, toPath:destinationPathString)
                    } catch {
                        let text = NSLocalizedString("Download success, however unable to move downloaded file to the destination path.", comment: "")
                        let cantMoveError = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotRemoveFile, userInfo:NSDictionary(object: text, forKey: NSLocalizedDescriptionKey) as [NSObject : AnyObject])
                        if let realErrorBlock = errorBlock {
                            realErrorBlock(resultObject: nil, error: cantMoveError, request: request, response: nil)
                        }
                        return
                    }
                    
                    // all worked as intended
                    let finalLocation = NSURL(fileURLWithPath: destinationPathString)
                    if let realSuccessBlock = successBlock {
                        realSuccessBlock(resultObject: finalLocation, request: request, response: nil)
                    }
                    return
                }
                
                let text = NSLocalizedString("Unable to locate downloaded file.", comment: "")
                let cantFindError = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotRemoveFile, userInfo:NSDictionary(object: text, forKey: NSLocalizedDescriptionKey) as [NSObject : AnyObject])
                if let realErrorBlock = errorBlock {
                    realErrorBlock(resultObject: nil, error: cantFindError, request: request, response: nil)
                }
            }
        }
        
        addHeaders(additionalHeaders, request: request)
        if let downloadTask = sharedURLSession.downloadTaskWithRequest(request) {
            if let realProgressBlock = progressBlock {
                let holder = BlockHolder()
                holder.downloadProgressBlock = realProgressBlock
                downloadProgressBlocks.setObject(holder, forKey: downloadTask.taskIdentifier)
            }
            let holder = BlockHolder()
            holder.downloadCompletionBlock = completionBlock
            downloadCompletionBlocks.setObject(holder, forKey: downloadTask.taskIdentifier)
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            activeTasks++
            downloadTask.resume()
            return downloadTask
        }
        return nil
    }
    
    func upload(sourceURL sourceURL: NSURL,
        destinationFullURLString: NSString,
        additionalHeaders: NSDictionary? = nil,
        successBlock: NetworkSuccessBlock? = nil,
        errorBlock: NetworkErrorBlock? = nil,
        progressBlock: NetworkUploadProgressBlock? = nil) -> NSURLSessionUploadTask? {
       
        let request = NSMutableURLRequest(URL: NSURL(string: destinationFullURLString.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!)!)
        request.HTTPMethod = HTTP_METHOD.POST.rawValue
        let completionBlock = taskCompletionBlockForRequest(request, successBlock: successBlock, errorBlock: errorBlock)
        addHeaders(additionalHeaders, request: request)
            
        if let uploadTask = sharedURLSession.uploadTaskWithRequest(request, fromFile:sourceURL) {
            if let realProgressBlock = progressBlock {
                let holder = BlockHolder()
                holder.uploadProgressBlock = realProgressBlock
                uploadProgressBlocks.setObject(holder, forKey: uploadTask.taskIdentifier)
            }
            
            let holder = BlockHolder()
            holder.uploadCompletedBlock = completionBlock
            uploadCompletionBlocks.setObject(holder, forKey: uploadTask.taskIdentifier)
            
            let dataHolder = BlockHolder() // so that the server's response to the upload can be captured
            taskDataBlocks.setObject(dataHolder, forKey: uploadTask.taskIdentifier)
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            activeTasks++
            uploadTask.resume()
            return uploadTask
        }
        return nil
    }
    
    func multipartFormPost(relativePath: String? = nil,
        parameters: NSDictionary? = nil,
        additionalHeaders: NSDictionary? = nil,
        multipartFormFiles: [MultipartFormFile]? = nil,
        successBlock: NetworkSuccessBlock? = nil,
        errorBlock: NetworkErrorBlock? = nil) ->NSURLSessionDataTask? {
        
        var requestURL = baseURL
        if let suppliedPath = relativePath {
            requestURL = requestURL.URLByAppendingPathComponent(suppliedPath)
        }
        let request = NSMutableURLRequest(URL: requestURL, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData, timeoutInterval: defaultConfiguration.timeoutIntervalForRequest)
        request.HTTPMethod = HTTP_METHOD.POST.rawValue
        let boundary = "Z2FiZW5pc2xvdmVnYWJlbmlzbGlmZQ=="
        let contentType = "multipart/form-data; boundary=\(boundary)"

        let body = NSMutableData(data: String("--\(boundary)\r\n").dataUsingEncoding(NSUTF8StringEncoding)!)
        
        if let params = parameters {
            for (_, keyValue) in params.enumerate() {
                body.appendData(String("Content-Disposition: form-data; name=\"\(keyValue.key)\"\r\n\r\n\(keyValue.value)\r\n--\(boundary)\r\n").dataUsingEncoding(NSUTF8StringEncoding)!)
            }
        }
        
        if let files = multipartFormFiles {
            for file in files {
                body.appendData(String("Content-Disposition: form-data; name=\"\(file.formKeyName)\"; filename=\"\(file.fileName)\"\r\n").dataUsingEncoding(NSUTF8StringEncoding)!)
                body.appendData(String("Content-Type: \(file.mimetype)\r\n").dataUsingEncoding(NSUTF8StringEncoding)!)
                body.appendData(String("Content-Transfer-Encoding: binary\r\n\r\n").dataUsingEncoding(NSUTF8StringEncoding)!)
                body.appendData(file.data)
                body.appendData(String("\r\n--\(boundary)\r\n").dataUsingEncoding(NSUTF8StringEncoding)!)
            }
        }
        
        let headers = NSMutableDictionary(object: contentType, forKey: "Content-Type")
        headers.setValue("\(body.length)", forKey: "Content-Length")
        if let userHeaders = additionalHeaders {
            headers.addEntriesFromDictionary(userHeaders as [NSObject : AnyObject])
        }
        addHeaders(headers, request: request)
        request.HTTPBody = body
        
        let completionBlock: URLSessionTaskCompletion = taskCompletionBlockForRequest(request, successBlock: successBlock, errorBlock: errorBlock)
        if let task = sharedURLSession.dataTaskWithRequest(request) {
            let holder = BlockHolder()
            holder.dataTaskCompletionBlock = completionBlock
            taskDataBlocks.setObject(holder, forKey: task.taskIdentifier)
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            activeTasks++
            task.resume()
            return task
        }
        return nil
    }

    // NSURLSessionDelegate
    
    func URLSession(session: NSURLSession, didReceiveChallenge challenge: NSURLAuthenticationChallenge, completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential?) -> Void) {
        var disposition = NSURLSessionAuthChallengeDisposition.PerformDefaultHandling
        var credential: NSURLCredential? = nil
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if securityPolicy.evaluateServerTrust(challenge.protectionSpace.serverTrust, forDomain: challenge.protectionSpace.host) {
                disposition = .UseCredential
                credential = NSURLCredential(forTrust: challenge.protectionSpace.serverTrust!)
            } else {
                disposition = .CancelAuthenticationChallenge
            }
        } else {
            disposition = .CancelAuthenticationChallenge
        }
        completionHandler(disposition, credential)
    }
    
    func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession) {
        if let completionHandler = sessionCompletionHandler {
            completionHandler()
            sessionCompletionHandler = nil
        }
    }
    
    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {

        if let blockHolder: BlockHolder = taskDataBlocks.objectForKey(dataTask.taskIdentifier) as? BlockHolder {
            if nil == blockHolder.dataTaskData {
                blockHolder.dataTaskData = NSMutableData()
            }
            blockHolder.dataTaskData?.appendData(data)
        }
    }
    
    // NSURLSessionTaskDelegate
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
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
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        
        // if it finishes with error, but has downloaded data, and we have network access: resume the download.
        // if it finishes with error, but has downloaded data, and we do not have network access: save the task (and data) to retry later
        if let realError = error {
            if let downloadedData = realError.userInfo[NSURLSessionDownloadTaskResumeData] as? NSData {
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
                dataTaskCompletionBlock(data: blockHolder.dataTaskData, response: task.response, error: error)
            }
            taskDataBlocks.removeObjectForKey(task.taskIdentifier)
        }
        
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        if let blockHolder: BlockHolder = downloadProgressBlocks.objectForKey(downloadTask.taskIdentifier) as? BlockHolder {
            if let progress = blockHolder.downloadProgressBlock {
                dispatch_async(dispatch_get_main_queue(), {
                    progress(bytesWritten: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
                    })
            }
        }
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        
        if let blockHolder: BlockHolder = downloadCompletionBlocks.objectForKey(downloadTask.taskIdentifier) as? BlockHolder {
            if let completionBlock = blockHolder.downloadCompletionBlock {
                completionBlock(location: location, error: nil)
            }
            downloadCompletionBlocks.removeObjectForKey(downloadTask.taskIdentifier)
            downloadProgressBlocks.removeObjectForKey(downloadTask.taskIdentifier)
        }
    }
}
