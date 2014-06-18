//
//  TSNetworking.swift
//  TSNetworkingSwift
//
//  Created by Tim Sawtell on 11/06/2014.
//
//
import Foundation
import UIKit

typealias TSNWSuccessBlock = (resultObject: AnyObject?, request: NSURLRequest, response: NSURLResponse?) -> Void
typealias TSNWErrorBlock = (resultObject: AnyObject?, error: NSError, request: NSURLRequest?, response: NSURLResponse?) -> Void
typealias TSNWDownloadProgressBlock = (bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) -> Void
typealias TSNWUploadProgressBlock = (bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) -> Void
typealias URLSessionTaskCompletion = (data: NSData!, response: NSURLResponse!, error: NSError!) -> Void
typealias URLSessionDownloadTaskCompletion = (location: NSURL!, error: NSError!) -> Void
typealias SessionCompletionHandler = (() -> Void)!

class BlockHolder {
    // because I can't add a declared instances of the typealias closures (TSNWSuccessBlock et al) to a dictionary, I have to wrap them up. Ugly as sin. Need to find a better way.
    var successBlock: TSNWSuccessBlock?
    var errorBlock: TSNWErrorBlock?
    var downloadProgressBlock: TSNWDownloadProgressBlock?
    var uploadProgressBlock: TSNWUploadProgressBlock?
    var downloadCompletionBlock: URLSessionDownloadTaskCompletion?
    var uploadCompletedBlock: URLSessionTaskCompletion?
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

let TSNWForeground = TSNetworking(background:false)
let TSNWBackground = TSNetworking(background:true)

class TSNetworking: NSObject, NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate, NSURLSessionDataDelegate {
    
    // to be marked private when Swift has access modifiers ...
    var defaultConfiguration: NSURLSessionConfiguration
    var baseURL: NSURL
    var acceptableStatusCodes: NSIndexSet
    var downloadProgressBlocks: NSMutableDictionary = NSMutableDictionary()
    var downloadCompletionBlocks: NSMutableDictionary = NSMutableDictionary()
    var uploadProgressBlocks: NSMutableDictionary = NSMutableDictionary()
    var uploadCompletedBlocks: NSMutableDictionary = NSMutableDictionary()
    var sessionHeaders: NSMutableDictionary = NSMutableDictionary()
    var downloadsToResume: NSMutableDictionary = NSMutableDictionary()
    var sharedURLSession: NSURLSession
    var username = String()
    var password = String()
    var isBackgroundConfiguration: Bool
    var activeTasks = 0
    var sessionCompletionHandler: SessionCompletionHandler
    
    init(background: Bool) {
        
        if background {
            defaultConfiguration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("au.com.sawtellsoftware.tsnetworking")
        } else {
            defaultConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
        }
        baseURL = NSURL.URLWithString("")
        defaultConfiguration.allowsCellularAccess = true
        defaultConfiguration.timeoutIntervalForRequest = 30
        defaultConfiguration.timeoutIntervalForResource = 18000 // 5 hours to download a single resource should be enough. Right?
        sharedURLSession = NSURLSession(configuration: defaultConfiguration)
        acceptableStatusCodes = NSIndexSet(indexesInRange: NSMakeRange(200, 100))
        isBackgroundConfiguration = background
        
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleNetworkChange", name: kReachabilityChangedNotification, object: nil)
        Reachability.reachabilityForInternetConnection().startNotifier()
        
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func handleNetworkChange(notification: NSNotification) {
        if let reachability = notification.object as? Reachability {
            if NetworkStatus.NotReachable != reachability.currentReachabilityStatus() {
                resumePausedDownloads()
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
    
    func taskCompletionBlockForRequest(request: NSMutableURLRequest, successBlock: TSNWSuccessBlock, errorBlock: TSNWErrorBlock) -> URLSessionTaskCompletion {
        weak var weakSelf = self
        var completionBlock: URLSessionTaskCompletion = { (data: NSData!, response: NSURLResponse!, error: NSError!) -> Void in
            if let strongSelf = weakSelf {
                strongSelf.activeTasks = max(strongSelf.activeTasks - 1, 0)
                if TSNWForeground.activeTasks == 0 && TSNWBackground.activeTasks == 0 {
                    if let sharedApp = UIApplication.sharedApplication() {
                        sharedApp.networkActivityIndicatorVisible = false
                    }
                }
                var useableContentType = "text" //reassign this value if appropriate
                var encoding: NSStringEncoding = NSUTF8StringEncoding
                if let httpResponse = response as? NSHTTPURLResponse {
                    var responseHeaders = httpResponse.allHeaderFields
                    if let contentType: NSString = responseHeaders.valueForKey("Content-Type") as? NSString {
                        var useableContentType: NSString = contentType.lowercaseString
                        
                        if let locOfSemi = Int?(useableContentType.rangeOfString(";").location) {
                            useableContentType = useableContentType.substringToIndex(locOfSemi)
                        }
                    }
                    if let encodingName = httpResponse.textEncodingName  {
                        var tmpEncoding = CFStringConvertIANACharSetNameToEncoding(encodingName.bridgeToObjectiveC() as CFString)
                        if tmpEncoding != kCFStringEncodingInvalidId {
                            encoding = CFStringConvertEncodingToNSStringEncoding(tmpEncoding)
                        }
                    }
                }
                var parsedObject: AnyObject? = nil
                
                if let actualError = error {
                    if let actualData = data {
                        if actualData.length <= 0 {
                            parsedObject = actualError
                        }
                    }
                } else {
                    parsedObject = strongSelf.resultBasedOnContentType(useableContentType, encoding: encoding, data: data)
                }
                if let anError = strongSelf.validateResponse(response) {
                    errorBlock(resultObject: parsedObject, error: anError, request: request, response: response)
                } else {
                    successBlock(resultObject: parsedObject, request: request, response: response)
                }
            }
        }
        return completionBlock
    }
    
    func resultBasedOnContentType(contentType: NSString, encoding: NSStringEncoding, data: NSData) -> AnyObject {
        var indexOfSlash: Int = contentType.rangeOfString("/").location
        var firstComponent = NSString(), secondComponent = NSString()

        if indexOfSlash > 0 && indexOfSlash < contentType.length - 1 {
            NSLog("\(indexOfSlash)")
            firstComponent = contentType.substringToIndex(indexOfSlash).lowercaseString
            secondComponent = contentType.substringFromIndex(indexOfSlash + 1).lowercaseString
        } else {
            firstComponent = contentType.lowercaseString
        }
        var parseError: NSError?
        if firstComponent == "application" {
            if secondComponent.containsString("json") {
                var parsedJSON: AnyObject = NSJSONSerialization.JSONObjectWithData(data, options: .MutableContainers, error: &parseError)
                return parsedJSON
            }
        } else if firstComponent == "text" {
            var parsedString = NSString(data: data, encoding: encoding)
            NSLog("\(parsedString)")
            return parsedString
        }
        return data
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
            var base64Encoded = "Basic " + "\(username):\(password)".dataUsingEncoding(NSUTF8StringEncoding).base64EncodedStringWithOptions(NSDataBase64EncodingOptions.fromRaw(0)!)
            request.addValue(base64Encoded, forHTTPHeaderField: "Authorization")
        }
        if let additionalHeaders = headers {
            for keyVal in additionalHeaders {
                request.addValue(keyVal.value as String, forHTTPHeaderField: keyVal.key as String)
            }
        }
        for keyVal in sessionHeaders {
            request.addValue(keyVal.value as String, forHTTPHeaderField: keyVal.key as String)
        }
    }
    
    // PUBLIC (when apple get around to giving us access modifiers like private and protected etc)
    
    func setBaseURLString(baseURLString: NSString) {
        baseURL = NSURL.URLWithString(baseURLString.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding))
    }
    
    func setBasicAuth(name: NSString, pass: NSString) {
        username = name
        password = pass
    }
    
    func addSessionHeaders(headers: NSDictionary) {
        sessionHeaders.addEntriesFromDictionary(headers)
    }
    
    func removeAllSessionHeaders() {
        sessionHeaders = NSMutableDictionary()
    }
    
    func addDownloadProgressBlock(progressBlock: TSNWDownloadProgressBlock, task: NSURLSessionTask) {
        if NSURLSessionTaskState.Running == task.state {
            if nil != progressBlock {
                var holder = BlockHolder()
                holder.downloadProgressBlock = progressBlock
                downloadProgressBlocks.setObject(holder, forKey: task.taskIdentifier)
            }
        }
    }
    
    func addUploadProgressBlock(progressBlock: TSNWUploadProgressBlock, task: NSURLSessionTask) {
        if NSURLSessionTaskState.Running == task.state {
            if nil != progressBlock {
                var holder = BlockHolder()
                holder.uploadProgressBlock = progressBlock
                uploadProgressBlocks.setObject(holder, forKey: task.taskIdentifier)
            }
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
                if (TSNWForeground.activeTasks == 0 && TSNWBackground.activeTasks == 0) {
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
    
    func performDataTaskWithRelativePath(path: NSString?, method: HTTP_METHOD, parameters: NSDictionary?, additionalHeaders: NSDictionary?, successBlock: TSNWSuccessBlock?, errorBlock: TSNWErrorBlock?) {
        assert(!isBackgroundConfiguration, "Must be run in foreground session, not background session")
        var requestURL = baseURL
        if nil != path {
            requestURL = requestURL.URLByAppendingPathComponent(path)
        }
        var request = NSMutableURLRequest(URL: requestURL, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData, timeoutInterval: defaultConfiguration.timeoutIntervalForRequest)
        request.HTTPMethod = method.toRaw()
        
        if let params = parameters {
            switch method {
            case HTTP_METHOD.POST, HTTP_METHOD.PUT, HTTP_METHOD.PATCH:
                var error: NSError?
                var jsonData = NSJSONSerialization.dataWithJSONObject(parameters, options: NSJSONWritingOptions.PrettyPrinted, error: &error)
                if nil != jsonData {
                    request.HTTPBody = jsonData
                }
            default:
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
        
        var completionBlock: URLSessionTaskCompletion = taskCompletionBlockForRequest(request, successBlock: successBlock!, errorBlock: errorBlock!)
        addHeaders(additionalHeaders, request: request)
        var task = sharedURLSession.dataTaskWithRequest(request, completionHandler:completionBlock)
        if let sharedApp = UIApplication.sharedApplication() {
            sharedApp.networkActivityIndicatorVisible = true
        }
        activeTasks++
        NSLog("\(request.URL)")
        task.resume()
    }
    
    func downloadFromFullFullURL(sourceURLString: NSString, destinationPathString: NSString, additionalHeaders: NSDictionary?, progressBlock: TSNWDownloadProgressBlock, successBlock: TSNWSuccessBlock, errorBlock: TSNWErrorBlock) -> NSURLSessionDownloadTask {
        
        var request = NSMutableURLRequest(URL: NSURL(string: sourceURLString.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)))
        request.HTTPMethod = HTTP_METHOD.POST.toRaw()
        
        weak var weakSelf = self
        
        var completionBlock: URLSessionDownloadTaskCompletion = { (location, error) -> Void in
            if let strongSelf = weakSelf {
                strongSelf.activeTasks = max(strongSelf.activeTasks - 1, 0)
                if (TSNWForeground.activeTasks == 0 && TSNWBackground.activeTasks == 0) {
                    if let sharedApp = UIApplication.sharedApplication() {
                        sharedApp.networkActivityIndicatorVisible = false
                    }
                }
                
                if nil != error {
                    if nil != errorBlock {
                        errorBlock(resultObject: nil, error: error, request: request, response: nil)
                    }
                    return
                }
                
                // does the downloaded file exist?
                var fm = NSFileManager()
                if !fm.fileExistsAtPath(location.path) {
                    // aint this some shit, it finished without error, but the file is not available at location
                    var text = NSLocalizedString("Unable to locate downloaded file", comment: "")
                    let notFoundError = NSError.errorWithDomain(NSURLErrorDomain, code: NSURLErrorCannotOpenFile, userInfo:NSDictionary(object: text, forKey: NSLocalizedDescriptionKey))
                    if nil != errorBlock {
                        errorBlock(resultObject: nil, error: notFoundError, request: request, response: nil)
                    }
                    return
                }
                
                // delete an existing file at the programmers destination path string
                var error: NSError?
                if fm.fileExistsAtPath(destinationPathString) {
                    fm.removeItemAtPath(destinationPathString, error: &error)
                }
                
                if (nil != error) {
                    // son of a bitch
                    var text = NSLocalizedString("Download success, however destination path already exists, and that file was unable to be deleted", comment: "")
                    let cantDeleteError = NSError.errorWithDomain(NSURLErrorDomain, code: NSURLErrorCannotRemoveFile, userInfo:NSDictionary(object: text, forKey: NSLocalizedDescriptionKey))
                    if nil != errorBlock {
                        errorBlock(resultObject: nil, error: cantDeleteError, request: request, response: nil)
                    }
                    return
                }
                
                // move the file to the programmers destination
                fm.moveItemAtPath(location.path, toPath:destinationPathString, error:&error)
                if (nil != error) {
                    // double son of a bitch
                    var text = NSLocalizedString("Download success, however unable to move downloaded file to the destination path.", comment: "")
                    let cantMoveError = NSError.errorWithDomain(NSURLErrorDomain, code: NSURLErrorCannotRemoveFile, userInfo:NSDictionary(object: text, forKey: NSLocalizedDescriptionKey))
                    if nil != errorBlock {
                        errorBlock(resultObject: nil, error: cantMoveError, request: request, response: nil)
                    }
                    return
                }
                
                // all worked as intended
                if nil != successBlock {
                    successBlock(resultObject: location, request: request, response: nil)
                }
            }
        }
        
        addHeaders(additionalHeaders, request: request)
        var downloadTask = sharedURLSession.downloadTaskWithRequest(request)
        if nil != progressBlock {
            var holder = BlockHolder()
            holder.downloadProgressBlock = progressBlock
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
    
    func uploadInBackground(localsourcePath: NSString, destinationFullURLString: NSString, additionalHeaders: NSDictionary?, progressBlock: TSNWUploadProgressBlock, successBlock: TSNWSuccessBlock, errorBlock: TSNWErrorBlock) -> NSURLSessionUploadTask? {
        
        assert(isBackgroundConfiguration, "Must be run with TSNWBackground, not TSNWForeground")
        var fm = NSFileManager()
        var error: NSError?
        
        if !fm.fileExistsAtPath(localsourcePath) {
            var text = NSLocalizedString("Unable to locate file to upload", comment: "")
            let cantOpenError = NSError.errorWithDomain(NSURLErrorDomain, code: NSURLErrorCannotOpenFile, userInfo:NSDictionary(object: text, forKey: NSLocalizedDescriptionKey))
            if nil != errorBlock {
                errorBlock(resultObject: nil, error: cantOpenError, request: nil, response: nil)
            }
            return nil
        }
        
        var request = NSMutableURLRequest(URL: NSURL(string: destinationFullURLString.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)))
        request.HTTPMethod = HTTP_METHOD.POST.toRaw()
        var completionBlock = taskCompletionBlockForRequest(request, successBlock: successBlock, errorBlock: errorBlock)
        addHeaders(additionalHeaders, request: request)
        var uploadTask = sharedURLSession.uploadTaskWithRequest(request, fromFile:NSURL(fileURLWithPath: localsourcePath))
        if nil != progressBlock {
            var holder = BlockHolder()
            holder.uploadProgressBlock = progressBlock
            uploadProgressBlocks.setObject(holder, forKey: uploadTask.taskIdentifier)
        }
        if nil != completionBlock {
            var holder = BlockHolder()
            holder.uploadCompletedBlock = completionBlock
            uploadCompletedBlocks.setObject(holder, forKey: uploadTask.taskIdentifier)
        }
        if let sharedApp = UIApplication.sharedApplication() {
            sharedApp.networkActivityIndicatorVisible = true
        }
        activeTasks++
        uploadTask.resume()
        return uploadTask
    }
    
    func uploadInForeground(data: NSData, destinationFullURLString: NSString, additionalHeaders: NSDictionary?, progressBlock: TSNWUploadProgressBlock, successBlock: TSNWSuccessBlock, errorBlock: TSNWErrorBlock) -> NSURLSessionUploadTask? {
        
        assert(!isBackgroundConfiguration, "Must be run with TSNWForeground, not TSNWBackground")
        
        var request = NSMutableURLRequest(URL: NSURL(string: destinationFullURLString.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)))
        request.HTTPMethod = HTTP_METHOD.POST.toRaw()
        var completionBlock = taskCompletionBlockForRequest(request, successBlock: successBlock, errorBlock: errorBlock)
        addHeaders(additionalHeaders, request: request)
        var uploadTask = sharedURLSession.uploadTaskWithRequest(request, fromData: data)
        if nil != progressBlock {
            var holder = BlockHolder()
            holder.uploadProgressBlock = progressBlock
            uploadProgressBlocks.setObject(holder, forKey: uploadTask.taskIdentifier)
        }
        if nil != completionBlock {
            var holder = BlockHolder()
            holder.uploadCompletedBlock = completionBlock
            uploadCompletedBlocks.setObject(holder, forKey: uploadTask.taskIdentifier)
        }
        if let sharedApp = UIApplication.sharedApplication() {
            sharedApp.networkActivityIndicatorVisible = true
        }
        activeTasks++
        uploadTask.resume()
        return uploadTask
    }
    
    // NSURLSessionDelegate
    func URLSession(session: NSURLSession!, didReceiveChallenge challenge: NSURLAuthenticationChallenge!, completionHandler: ((NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void)!) {
        
    }
    
    func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession!) {
        if let completionHandler = sessionCompletionHandler {
            completionHandler()
            sessionCompletionHandler = nil
        }
    }
    
    // NSURLSessionTaskDelegate
    
    func URLSession(session: NSURLSession!, task: NSURLSessionTask!, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        if let blockHolder: BlockHolder = uploadProgressBlocks.objectForKey(task.taskIdentifier) as? BlockHolder {
            if let progress: TSNWUploadProgressBlock = blockHolder.uploadProgressBlock {
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
        if nil != error {
            if let downloadedData = error.userInfo.objectForKey(NSURLSessionDownloadTaskResumeData) as? NSData {
                if (NetworkStatus.NotReachable != Reachability.reachabilityForInternetConnection().currentReachabilityStatus()) {
                    sharedURLSession.downloadTaskWithResumeData(downloadedData)
                } else {
                    downloadsToResume.setObject(downloadedData, forKey:task.taskIdentifier)
                }
                return
            }
             // it didn't fail, so remove the paused download task if it existed in the downloadsToResume dict.
            downloadsToResume.removeObjectForKey(task.taskIdentifier)
            
            // at this stage we could be finishing from a download task or an upload task (this delegate is called for both)
            if let blockHolder: BlockHolder = uploadCompletedBlocks.objectForKey(task.taskIdentifier) as? BlockHolder {
                if let uploadCompletionBlock = blockHolder.uploadCompletedBlock {
                    uploadCompletionBlock(data: nil, response: task.response, error: error)
                }
                uploadCompletedBlocks.removeObjectForKey(task.taskIdentifier) // remove the block holder as its served its purpose
                uploadProgressBlocks.removeObjectForKey(task.taskIdentifier) // no need to hold on to the progress block for a completed task
            }
            if let blockHolder: BlockHolder = downloadCompletionBlocks.objectForKey(task.taskIdentifier) as? BlockHolder {
                if let downloadCompletionBlock = blockHolder.downloadCompletionBlock {
                    downloadCompletionBlock(location: nil, error: error)
                }
                downloadCompletionBlocks.removeObjectForKey(task.taskIdentifier) // remove the block holder as its served its purpose
                downloadProgressBlocks.removeObjectForKey(task.taskIdentifier) // no need to hold on to the progress block for a completed task
            }
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
                dispatch_async(dispatch_get_main_queue(), {
                    completionBlock(location: location, error: nil)
                    })
            }
            downloadCompletionBlocks.removeObjectForKey(downloadTask.taskIdentifier)
            downloadProgressBlocks.removeObjectForKey(downloadTask.taskIdentifier)
        }
    }
}
