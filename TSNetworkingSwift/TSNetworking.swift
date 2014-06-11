//
//  TSNetworking.swift
//  TSNetworkingSwift
//
//  Created by Tim Sawtell on 11/06/2014.
//
//
import Foundation
import UIKit

typealias TSNWSuccessBlock = (resultObject: AnyObject, request: NSURLRequest, response: NSURLResponse?) -> Void
typealias TSNWErrorBlock = (resultObject: AnyObject?, error: NSError, request: NSURLRequest, response: NSURLResponse?) -> Void
typealias TSNWDownloadProgressBlock = (bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) -> Void
typealias TSNWUploadProgressBlock = (bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) -> Void
typealias URLSessionTaskCompletion = (data: NSData!, response: NSURLResponse!, error: NSError!) -> Void
typealias URLSessionDownloadTaskCompletion = (location: NSURL!, error: NSError!) -> Void

class blockHolder {
    // because I can't add a declared instances of the typealias closures (TSNWSuccessBlock et al) to a dictionary, I have to wrap them up. Ugly as sin. Need to find a better way.
    var successBlock: TSNWSuccessBlock?
    var errorBlock: TSNWErrorBlock?
    var downloadProgressBlock: TSNWDownloadProgressBlock?
    var uploadProgressBlock: TSNWUploadProgressBlock?
    var downloadCompletionBlock: URLSessionDownloadTaskCompletion?
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
    var username = ""
    var password = ""
    var isBackgroundConfiguration: Bool
    var activeTasks = 0
    
    init(background: Bool) {
        if background {
            defaultConfiguration = NSURLSessionConfiguration.backgroundSessionConfiguration("au.com.sawtellsoftware.tsnetworking")
        } else {
            defaultConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
        }
        defaultConfiguration.allowsCellularAccess = true
        defaultConfiguration.timeoutIntervalForRequest = 30
        defaultConfiguration.timeoutIntervalForResource = 18000 // 5 hours to download a single resource should be enough. Right?
        sharedURLSession = NSURLSession(configuration: defaultConfiguration)
        acceptableStatusCodes = NSIndexSet(indexesInRange: NSMakeRange(200, 100))
        isBackgroundConfiguration = background
        
        super.init()
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
    
    func taskCompletionBlockForRequest(weakRequest: NSMutableURLRequest, successBlock: TSNWSuccessBlock, errorBlock: TSNWErrorBlock) -> URLSessionTaskCompletion {
        weak var weakSelf = self
        var completionBlock: URLSessionTaskCompletion = { (data, response, error) -> Void in
            if let strongSelf = weakSelf {
                strongSelf.activeTasks = max(strongSelf.activeTasks - 1, 0)
                if TSNWForeground.activeTasks == 0 && TSNWBackground.activeTasks == 0 {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                }
                var stringEncoding = NSUTF8StringEncoding
                var useableContentType = ""
                var encoding: NSStringEncoding = NSUTF8StringEncoding
                if let httpResponse = response as? NSHTTPURLResponse {
                    var responseHeaders = httpResponse.allHeaderFields
                    if let contentType: NSString = responseHeaders.valueForKey("Content-Type") as? NSString {
                        var useableContentType: NSString = contentType.lowercaseString
                        var indexOfSemi = useableContentType.rangeOfString(";").location
                        if indexOfSemi != NSNotFound { // looks like we're still doing this in Swift :(
                            useableContentType = useableContentType.substringToIndex(indexOfSemi)
                        }
                    }
                    if let encodingName = httpResponse.textEncodingName  {
                        var tmpEncoding = CFStringConvertIANACharSetNameToEncoding(encodingName.bridgeToObjectiveC() as CFString)
                        if tmpEncoding != kCFStringEncodingInvalidId {
                            encoding = CFStringConvertEncodingToNSStringEncoding(tmpEncoding)
                        }
                    }
                }
                var parsedObject: NSObject
                if nil != error && (nil == data || data.length <= 0) {
                    parsedObject = error!.localizedDescription;
                } else {
                    if useableContentType == "" {
                        useableContentType = "text"
                    }
                    var parsedObject: AnyObject = strongSelf.resultBasedOnContentType(useableContentType, encoding: encoding, data: data)
                }
                if let anError = strongSelf.validateResponse(response) {
                    if nil != errorBlock {
                        errorBlock(resultObject: parsedObject, error: anError, request: weakRequest, response: response)
                    }
                    return
                }
                if nil != successBlock {
                    successBlock(resultObject: parsedObject, request: weakRequest, response: response)
                }
            }
        };
        return completionBlock
    }
    
    func resultBasedOnContentType(contentType: NSString, encoding: NSStringEncoding, data: NSData) -> AnyObject {
        var indexOfSlash = contentType.rangeOfString("/")
        var firstComponent: NSString, secondComponent: NSString
        if indexOfSlash.location != NSNotFound {
            firstComponent = contentType.substringToIndex(indexOfSlash.location).lowercaseString
            secondComponent = contentType.substringFromIndex(indexOfSlash.location + 1).lowercaseString
        } else {
            firstComponent = contentType.lowercaseString
        }
        var parseError: NSError?
        if firstComponent.isEqualToString("application") {
            if secondComponent.containsString("json") {
                var parsedJSON: AnyObject = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &parseError)
                return parsedJSON
            }
        } else if firstComponent.isEqualToString("text") {
            var parsedString = NSString(data: data, encoding: encoding)
            return parsedString
        }
        return data
    }
    
    func validateResponse(response: NSURLResponse) -> NSError? {
        if let httpResponse = response as? NSHTTPURLResponse {
            if !acceptableStatusCodes.containsIndex(httpResponse.statusCode) {
                var text = "Request failed: \(NSHTTPURLResponse.localizedStringForStatusCode(httpResponse.statusCode)) (\(httpResponse.statusCode))"
                var converted = NSLocalizedString(text, comment: "")
                let error = NSError.errorWithDomain(NSURLErrorDomain, code: httpResponse.statusCode, userInfo:NSDictionary(object: text, forKey: NSLocalizedDescriptionKey))
                return error
            }
        }
        
        return nil
    }
    
    func addHeaders(headers: NSDictionary, request: NSMutableURLRequest) {
        if nil != username && nil != password {
            var base64Encoded = "\(username):\(password)".dataUsingEncoding(NSUTF8StringEncoding).base64EncodedStringWithOptions(NSDataBase64EncodingOptions.fromRaw(0)!)
            request.setValue(base64Encoded, forKey: "Authorization")
        }
        for keyVal in headers {
            request.addValue(keyVal.value as String, forHTTPHeaderField: keyVal.key as String)
        }
        for keyVal in sessionHeaders {
            request.addValue(keyVal.value as String, forHTTPHeaderField: keyVal.key as String)
        }
    }
    
    // PUBLIC
    
    func setBaseURLString(baseURLString: NSString) {
        self.baseURL = NSURL.URLWithString(baseURLString.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding));
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
                var holder = blockHolder()
                holder.downloadProgressBlock = progressBlock
                self.downloadProgressBlocks.setObject(holder, forKey: task.taskIdentifier)
            }
        }
    }
    
    func addUploadProgressBlock(progressBlock: TSNWUploadProgressBlock, task: NSURLSessionTask) {
        if NSURLSessionTaskState.Running == task.state {
            if nil != progressBlock {
                var holder = blockHolder()
                holder.uploadProgressBlock = progressBlock
                self.uploadProgressBlocks.setObject(holder, forKey: task.taskIdentifier)
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
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
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
        
        var requestURL = self.baseURL.URLByAppendingPathComponent(path)
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
                var addQMark = range.location == NSNotFound
                for keyVal in params {
                    if addQMark {
                        urlString = urlString.stringByAppendingString("?\(keyVal.key)=\(keyVal.value)")
                        addQMark = false
                    } else {
                        urlString = urlString.stringByAppendingString("&\(keyVal.key)=\(keyVal.value)")
                    }
                }
            }
        }
        
        weak var weakRequest = request
        var completionBlock: URLSessionTaskCompletion = self.taskCompletionBlockForRequest(weakRequest!, successBlock: successBlock!, errorBlock: errorBlock!)
        self.addHeaders(additionalHeaders!, request: request)
        var task = self.sharedURLSession.dataTaskWithRequest(request, completionHandler:completionBlock)
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        self.activeTasks++
        task.resume()
    }
    
    func downloadFromFullFullURL(sourceURLString: NSString, destinationPathString: NSString, additionalHeaders: NSDictionary?, progressBlock: TSNWDownloadProgressBlock, successBlock: TSNWSuccessBlock, errorBlock: TSNWErrorBlock) -> NSURLSessionDownloadTask {
        
        var request = NSMutableURLRequest(URL: NSURL(string: sourceURLString.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)))
        request.HTTPMethod = HTTP_METHOD.POST.toRaw()
        
        weak var weakRequest = request
        weak var weakSelf = self
        
        var completionBlock: URLSessionDownloadTaskCompletion = { (location, error) -> Void in
            if let strongSelf = weakSelf {
                strongSelf.activeTasks = max(strongSelf.activeTasks - 1, 0)
                if (TSNWForeground.activeTasks == 0 && TSNWBackground.activeTasks == 0) {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                }
                
                if nil != error {
                    if nil != errorBlock {
                        errorBlock(resultObject: nil, error: error, request: weakRequest!, response: nil)
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
                        errorBlock(resultObject: nil, error: notFoundError, request: weakRequest!, response: nil)
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
                        errorBlock(resultObject: nil, error: cantDeleteError, request: weakRequest!, response: nil)
                    }
                    return;
                }
                
                // move the file to the programmers destination
                fm.moveItemAtPath(location.path, toPath:destinationPathString, error:&error);
                if (nil != error) {
                    // double son of a bitch
                    var text = NSLocalizedString("Download success, however unable to move downloaded file to the destination path.", comment: "");
                    let cantMoveError = NSError.errorWithDomain(NSURLErrorDomain, code: NSURLErrorCannotRemoveFile, userInfo:NSDictionary(object: text, forKey: NSLocalizedDescriptionKey))
                    if nil != errorBlock {
                        errorBlock(resultObject: nil, error: cantMoveError, request: weakRequest!, response: nil)
                    }
                    return;
                }
                
                // all worked as intended
                if nil != successBlock {
                    successBlock(resultObject: location, request: weakRequest!, response: nil)
                }
            }
        }
        
        self.addHeaders(additionalHeaders!, request: request)
        var downloadTask = sharedURLSession.downloadTaskWithRequest(request)
        if nil != progressBlock {
            var holder = blockHolder()
            holder.downloadProgressBlock = progressBlock
            self.downloadProgressBlocks.setObject(holder, forKey: downloadTask.taskIdentifier)
        }
        var holder = blockHolder()
        holder.downloadCompletionBlock = completionBlock
        self.downloadCompletionBlocks.setObject(holder, forKey: downloadTask.taskIdentifier)
        
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        self.activeTasks++
        downloadTask.resume()
        return downloadTask
    }
}
