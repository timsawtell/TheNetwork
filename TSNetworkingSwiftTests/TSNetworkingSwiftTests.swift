//
//  TSNetworkingSwiftTests.swift
//  TSNetworkingSwiftTests
//
//  Created by Tim Sawtell on 11/06/2014.
//
//

import XCTest

let kNoAuthNeeded = "http://localhost:8081";
let kAuthNeeded = "http://localhost:8080";
let kJSON = "http://localhost:8083";
let kMultipartUpload = "http://localhost:8082/upload";
let remoteGabe = "http://images.dailytech.com/nimage/gabe_newell.jpeg"

class TSNetworkingSwiftTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        TSNWForeground.removeAllSessionHeaders()
        TSNWBackground.removeAllSessionHeaders()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    /*
    * GET tests
    */

    /*
    * As a GET REQUEST I should has a HTTPMethod of "GET"
    * If I add a path it should be appended to the base URL 
    * The resultObject should be what TSNetworkingSwiftTests/noauth.node.js returns
    */
    func testGet() {
        
        var testFinished = expectationWithDescription("test finished")
        let testPath = "something"
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertEqual("cheers man", resultObject as String, "result object was not what kNoAuthNeeded node server returns")
            XCTAssertTrue(request.URL.lastPathComponent == testPath, "path wasn't appended")
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertNotNil(error, "error not nil, it was \(error.localizedDescription)")
            XCTFail("in the error block, error was: \(error.localizedDescription)")
            testFinished.fulfill()
        }
        TSNWForeground.setBaseURLString(kNoAuthNeeded)
        var task: NSURLSessionDataTask = TSNWForeground.performDataTaskWithRelativePath(testPath, method: .GET, parameters: nil, additionalHeaders: nil, successBlock: successBlock, errorBlock: errorBlock)
        XCTAssertEqual(task.originalRequest.HTTPMethod, HTTP_METHOD.GET.toRaw(), "task wasn't a GET")
        waitForExpectationsWithTimeout(4, handler: nil)
    }
    
    /*
    * As a GET REQUEST with additional headers I should have a HTTPMethod of "GET"
    * I should have those headers in the request's header fields
    * The resultObject should be what TSNetworkingSwiftTests/noauth.node.js returns
    */
    func testGetAdditionalHeaders() {
        
        var testFinished = expectationWithDescription("test finished")
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
            XCTAssertEqual("cheers man", resultObject as String, "result object was not what kNoAuthNeeded node server returns")
            var requestHeaders = request.allHTTPHeaderFields
            XCTAssertTrue(requestHeaders.valueForKey("Content-Type").isEqualToString("application/json"), "Content-Type header missing")
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertNotNil(error, "error not nil, it was \(error.localizedDescription)")
            XCTFail("in the error block, error was: \(error.localizedDescription)")
            testFinished.fulfill()
        }
        
        var additionalHeaders = NSDictionary(object: "application/json", forKey: "Content-Type")
        TSNWForeground.setBaseURLString(kNoAuthNeeded)
        var task: NSURLSessionDataTask = TSNWForeground.performDataTaskWithRelativePath(nil, method: .GET, parameters: nil, additionalHeaders: additionalHeaders, successBlock: successBlock, errorBlock: errorBlock)
        XCTAssertEqual(task.originalRequest.HTTPMethod, HTTP_METHOD.GET.toRaw(), "task wasn't a GET")
        waitForExpectationsWithTimeout(4, handler: nil)
    }
    
    /*
    * As a GET REQUEST with session headers I should have a HTTPMethod of "GET"
    * I should have those headers in the requests header fields
    * The resultObject should be what TSNetworkingSwiftTests/noauth.node.js returns
    */
    func testAddSessionHeaders() {
        
        var testFinished = expectationWithDescription("test finished")
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
            XCTAssertEqual("cheers man", resultObject as String, "result object was not what kNoAuthNeeded node server returns")
            var requestHeaders = request.allHTTPHeaderFields
            XCTAssertTrue(requestHeaders.valueForKey("Accept").isEqualToString("application/json"), "Accept header missing")
            TSNWForeground.removeAllSessionHeaders()
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertNotNil(error, "error not nil, it was \(error.localizedDescription)")
            XCTFail("in the error block, error was: \(error.localizedDescription)")
            testFinished.fulfill()
        }
        
        TSNWForeground.setBaseURLString(kNoAuthNeeded)
        TSNWForeground.addSessionHeaders(NSDictionary(object: "application/json", forKey: "Accept"))
        var task: NSURLSessionDataTask = TSNWForeground.performDataTaskWithRelativePath(nil, method: .GET, parameters: nil, additionalHeaders: nil, successBlock: successBlock, errorBlock: errorBlock)
        XCTAssertEqual(task.originalRequest.HTTPMethod, HTTP_METHOD.GET.toRaw(), "task wasn't a GET")
        waitForExpectationsWithTimeout(4, handler: nil)
    }
    
    /*
    * As a GET REQUEST with parameters headers I should have a HTTPMethod of "GET"
    * The request's URL must include these parameters
    * The resultObject should be what TSNetworkingSwiftTests/noauth.node.js returns
    */
    func testGetWithParameters() {
        
        var testFinished = expectationWithDescription("test finished")
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
            XCTAssertEqual("cheers man", resultObject as String, "result object was not what kNoAuthNeeded node server returns")
            var shouldBeURL = "\(kNoAuthNeeded)?key=value"
            XCTAssertEqual(request.URL.absoluteString, shouldBeURL, "the query string wasn't set correctly, it was \(request.URL.absoluteString)")
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertNotNil(error, "error not nil, it was \(error.localizedDescription)")
            XCTFail("in the error block, error was: \(error.localizedDescription)")
            testFinished.fulfill()
        }
        var additionalParams = NSDictionary(object: "value", forKey: "key")
        TSNWForeground.setBaseURLString(kNoAuthNeeded)
        var task: NSURLSessionDataTask = TSNWForeground.performDataTaskWithRelativePath(nil, method: .GET, parameters: additionalParams, additionalHeaders: nil, successBlock: successBlock, errorBlock: errorBlock)
        XCTAssertEqual(task.originalRequest.HTTPMethod, HTTP_METHOD.GET.toRaw(), "task wasn't a GET")
        waitForExpectationsWithTimeout(4, handler: nil)
    }
    
    /*
    * As a GET REQUEST with BASIC AUTH set I should have a HTTPMethod of "GET"
    * The request should reach the successblock
    */
    func testGetWithUsernameAndPassword() {
        
        var testFinished = expectationWithDescription("test finished")
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertNotNil(error, "error not nil, it was \(error.localizedDescription)")
            XCTFail("in the error block, error was: \(error.localizedDescription)")
            testFinished.fulfill()
        }
        TSNWForeground.setBaseURLString(kAuthNeeded)
        TSNWForeground.setBasicAuth("hack", pass: "thegibson")
        var task: NSURLSessionDataTask = TSNWForeground.performDataTaskWithRelativePath(nil, method: .GET, parameters: nil, additionalHeaders: nil, successBlock: successBlock, errorBlock: errorBlock)
        XCTAssertEqual(task.originalRequest.HTTPMethod, HTTP_METHOD.GET.toRaw(), "task wasn't a GET")
        waitForExpectationsWithTimeout(4, handler: nil)
    }
    
    /*
    * As a GET REQUEST with BASIC AUTH set I should have a HTTPMethod of "GET"
    * The request should reach the errorBlock with a 401 response
    */
    func testGetWithWrongUsernameAndPassword() {
        
        var testFinished = expectationWithDescription("test finished")
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTFail("in the success block, the request should have a 401 response but doesn't")
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertEqual(error.code, 401, "The error case was \(error.code) instead of 401")
            testFinished.fulfill()
        }
        TSNWForeground.setBaseURLString(kAuthNeeded)
        TSNWForeground.setBasicAuth("hack", pass: "thegibsonWRONG")
        var task: NSURLSessionDataTask = TSNWForeground.performDataTaskWithRelativePath(nil, method: .GET, parameters: nil, additionalHeaders: nil, successBlock: successBlock, errorBlock: errorBlock)
        XCTAssertEqual(task.originalRequest.HTTPMethod, HTTP_METHOD.GET.toRaw(), "task wasn't a GET")
        waitForExpectationsWithTimeout(4, handler: nil)
    }
    
    /*
    * As a GET REQUEST with hitting a JSON based API I should have a HTTPMethod of "GET"
    * I should receive a dictionary as the response which contains the parsed JSON from the server
    */
    func testGetJSON() {
        
        var testFinished = expectationWithDescription("test finished")
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
            XCTAssertTrue(resultObject?.isKindOfClass(NSDictionary.self), "result was not a dictionary")
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertNotNil(error, "error not nil, it was \(error.localizedDescription)")
            XCTFail("in the error block, error was: \(error.localizedDescription)")
            testFinished.fulfill()
        }
        TSNWForeground.setBaseURLString(kJSON)
        var task: NSURLSessionDataTask = TSNWForeground.performDataTaskWithRelativePath(nil, method: .GET, parameters: nil, additionalHeaders: nil, successBlock: successBlock, errorBlock: errorBlock)
        XCTAssertEqual(task.originalRequest.HTTPMethod, HTTP_METHOD.GET.toRaw(), "task wasn't a GET")
        waitForExpectationsWithTimeout(4, handler: nil)
    }
    
    /*
    * POST tests
    */
    
    /*
    * As a POST request I should have a HTTPMethod of "POST"
    * I should have a request body that contains the additionalParameters added to the task
    * I should have the additionalHeaders that were added to the task
    */
    func testPostWithPameters() {
        
        var testFinished = expectationWithDescription("test finished")
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
            XCTAssertEqual("cheers man", resultObject as String, "result object was not what kNoAuthNeeded node server returns")
            var body = NSString(data: request.HTTPBody, encoding: NSUTF8StringEncoding)
            XCTAssertNotNil(body, "body had no content for the POST")
            var requestHeaders = request.allHTTPHeaderFields
            XCTAssertTrue(requestHeaders.valueForKey("Content-Type").isEqualToString("application/json"), "Content-Type header missing")
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertNotNil(error, "error not nil, it was \(error.localizedDescription)")
            XCTFail("in the error block, error was: \(error.localizedDescription)")
            testFinished.fulfill()
        }
        var additionalHeaders = NSDictionary(object: "application/json", forKey: "Content-Type")
        var additionalParams = NSDictionary(object: "value", forKey: "key")
        TSNWForeground.setBaseURLString(kNoAuthNeeded)
        var task: NSURLSessionDataTask = TSNWForeground.performDataTaskWithRelativePath(nil, method: .POST, parameters: additionalParams, additionalHeaders: additionalHeaders, successBlock: successBlock, errorBlock: errorBlock)
        XCTAssertEqual(task.originalRequest.HTTPMethod, HTTP_METHOD.POST.toRaw(), "task wasn't a POST")
        XCTAssertEqual(task.originalRequest.allHTTPHeaderFields.objectForKey("Content-Type") as String, "application/json", "the content type was not set")
        waitForExpectationsWithTimeout(4, handler: nil)
    }
    
    /*
    * Download tests
    */
    
    /*
    * As a download task I should have a state of "Running" after I am created
    * I should have a resultObject that is an NSURL
    * The file at NSURL should exist on disk
    * The file at NSURL should be able to be deleted
    */
    func testDownloadFile() {
        
        var testFinished = expectationWithDescription("test finished")
        let destinationDir: NSArray = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as Array
        let destinationPath = destinationDir.objectAtIndex(0).stringByAppendingPathComponent("ourLord.jpeg")
        NSLog("destination path: \(destinationPath)")
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
            XCTAssertTrue(resultObject?.isKindOfClass(NSURL.self), "download resultObject was not an NSURL")
            let fm = NSFileManager()
            XCTAssertTrue(fm.fileExistsAtPath(destinationPath), "file doesnt exist at download path")
            //better delete it
            var error: NSError?
            fm.removeItemAtPath(destinationPath, error: &error)
            XCTAssertNil(error, "Error deleting file: \(error)")
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertNotNil(error, "error not nil, it was \(error.localizedDescription)")
            XCTFail("in the error block, error was: \(error.localizedDescription)")
            testFinished.fulfill()
        }
        
        let progressBlock: TSNWDownloadProgressBlock = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
            NSLog("Download written: \(bytesWritten), TotalBytesWritten: \(totalBytesWritten), expectedToWrite: \(totalBytesExpectedToWrite)")
        }
        
        var task: NSURLSessionDownloadTask = TSNWBackground.downloadFromFullURL(remoteGabe, destinationPathString: destinationPath, additionalHeaders: nil, progressBlock: progressBlock, successBlock: successBlock, errorBlock: errorBlock)
        XCTAssertNotNil(task, "The download task was nil")
        XCTAssertEqual(task.state, NSURLSessionTaskState.Running, "download not started")
        waitForExpectationsWithTimeout(20, handler: nil)
    }
    
    /*
    * As a download task that will be cancelled should have a state of "Running" after I am created
    * I should not reach the successBlock
    * I should reach the errorBlock, and the error's code should tell me that the task was cancelled by user
    */
    func testCancelDownload() {
        
        var testFinished = expectationWithDescription("test finished")
        let destinationDir: NSArray = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as Array
        let destinationPath = destinationDir.objectAtIndex(0).stringByAppendingPathComponent("1mb.mp4")
        let fm = NSFileManager()
        
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTFail("The download should have failed because it was cancelled")
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertEqual(error.code, NSURLErrorCancelled, "task was not cancelled, it was \(error.localizedDescription)")
            var error: NSError?
            fm.removeItemAtPath(destinationPath, error: &error)
            testFinished.fulfill()
        }
        
        let progressBlock: TSNWDownloadProgressBlock = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
            NSLog("Download written: \(bytesWritten), TotalBytesWritten: \(totalBytesWritten), expectedToWrite: \(totalBytesExpectedToWrite)")
        }
        
        var task: NSURLSessionDownloadTask = TSNWBackground.downloadFromFullURL("http://ipv4.download.thinkbroadband.com/5MB.zip", destinationPathString: destinationPath, additionalHeaders: nil, progressBlock: progressBlock, successBlock: successBlock, errorBlock: errorBlock)
        XCTAssertNotNil(task, "The download task was nil")
        XCTAssertEqual(task.state, NSURLSessionTaskState.Running, "download not started")
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (Int64)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), {
            task.cancel()
        });
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    /*
    * As a download task that will have a progress block added to me after I am running I should see that the progress block is executed
    */
    func testAddDownloadProgressBlock() {
        
        var testFinished = expectationWithDescription("test finished")
        var progressReached = expectationWithDescription("progress block was called")
        let destinationDir: NSArray = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as Array
        let destinationPath = destinationDir.objectAtIndex(0).stringByAppendingPathComponent("1mb.mp4")
        let fm = NSFileManager()
        
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
            XCTAssertTrue(fm.fileExistsAtPath(destinationPath), "file doesnt exist at download path")
            //better delete it
            var error: NSError?
            fm.removeItemAtPath(destinationPath, error: &error)
            XCTAssertNil(error, "Error deleting file: \(error)")
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertNotNil(error, "error not nil, it was \(error.localizedDescription)")
            XCTFail("in the error block, error was: \(error.localizedDescription)")
            testFinished.fulfill()
        }
        var fulfilled = false
        let progressBlock: TSNWDownloadProgressBlock = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
            NSLog("Download written: \(bytesWritten), TotalBytesWritten: \(totalBytesWritten), expectedToWrite: \(totalBytesExpectedToWrite)")
            if !fulfilled {
                progressReached.fulfill() // API violation to call this more than once apparently
                fulfilled = true
            }
        }
        
        var task: NSURLSessionDownloadTask = TSNWBackground.downloadFromFullURL(remoteGabe, destinationPathString: destinationPath, additionalHeaders: nil, progressBlock: nil, successBlock: successBlock, errorBlock: errorBlock)
        XCTAssertEqual(task.state, NSURLSessionTaskState.Running, "task not started")
        TSNWBackground.addDownloadProgressBlock(progressBlock, task: task)
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    /*
    * upload tests
    */
    
    /*
    * As an upload in foreground task I should have a state of "Running" after I am created
    * I should be able to upload NSData
    */
    func testUploadInForeground() {
        
        var testFinished = expectationWithDescription("test finished")
        
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertNotNil(error, "error not nil, it was \(error.localizedDescription)")
            XCTFail("in the error block, error was: \(error.localizedDescription)")
            testFinished.fulfill()
        }
        
        let progressBlock: TSNWUploadProgressBlock = { (bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            NSLog("bytes sent: \(bytesSent), TotalBytesSent: \(totalBytesSent), expectedToSend: \(totalBytesExpectedToSend)")
        }
        
        let fm = NSFileManager()
        let sourcePath = NSBundle.mainBundle().pathForResource("ourLord", ofType: "jpg")
        XCTAssertNotNil(sourcePath, "Couldn't find local picture of our lord")
        let data = fm.contentsAtPath(sourcePath)
        
        let task = TSNWForeground.uploadInForeground(data, destinationFullURLString: kMultipartUpload, additionalHeaders: nil, progressBlock: progressBlock, successBlock: successBlock, errorBlock: errorBlock)
        XCTAssertEqual(task.state, NSURLSessionTaskState.Running, "task not started")
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    /*
    * As an upload in background task I should have a state of "Running" after I am created
    * I should be able to upload from a string based source location.
    * I should have a state of "Running" after I am created
    * Unfortunately I cant find a way to simulate minimizing or exiting the app and having the download task finish as expected
    */
    func testUploadInBackground() {
        
        var testFinished = expectationWithDescription("test finished")
        
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertNotNil(error, "error not nil, it was \(error.localizedDescription)")
            XCTFail("in the error block, error was: \(error.localizedDescription)")
            testFinished.fulfill()
        }
        
        let progressBlock: TSNWUploadProgressBlock = { (bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            NSLog("bytes sent: \(bytesSent), TotalBytesSent: \(totalBytesSent), expectedToSend: \(totalBytesExpectedToSend)")
        }
        
        let fm = NSFileManager()
        let sourcePath = NSBundle.mainBundle().pathForResource("ourLord", ofType: "jpg")
        XCTAssertNotNil(sourcePath, "Couldn't find local picture of our lord")
        let data = fm.contentsAtPath(sourcePath)
        
        if let task = TSNWForeground.uploadInBackground(sourcePath, destinationFullURLString: kMultipartUpload, additionalHeaders: nil, progressBlock: progressBlock, successBlock: successBlock, errorBlock: errorBlock) {
            XCTAssertEqual(task.state, NSURLSessionTaskState.Running, "task not started")
        } else {
            XCTFail("error creating task, perhaps the source path was invalid")
        }
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    /*
    * As an upload in foreground task that will be cancelled should have a state of "Running" after I am created
    * I should be able to upload NSData
    * I should not reach the successBlock
    * I should reach the errorBlock, and the error's code should tell me that the task was cancelled by user
    */
    func testCancelUploadInForeground() {
        
        var testFinished = expectationWithDescription("test finished")
        let destinationDir: NSArray = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as Array
        let destinationPath = destinationDir.objectAtIndex(0).stringByAppendingPathComponent("1mb.mp4")
        let fm = NSFileManager()
        
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTFail("The download should have failed because it was cancelled")
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertEqual(error.code, NSURLErrorCancelled, "task was not cancelled, it was \(error.localizedDescription)")
            var error: NSError?
            fm.removeItemAtPath(destinationPath, error: &error)
            testFinished.fulfill()
        }
        
        let progressBlock: TSNWUploadProgressBlock = { (bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            NSLog("bytes sent: \(bytesSent), TotalBytesSent: \(totalBytesSent), expectedToSend: \(totalBytesExpectedToSend)")
        }
        
        let sourcePath = NSBundle.mainBundle().pathForResource("ourLord", ofType: "jpg")
        XCTAssertNotNil(sourcePath, "Couldn't find local picture of our lord")
        let data = fm.contentsAtPath(sourcePath)
        
        let uploadTask = TSNWForeground.uploadInForeground(data, destinationFullURLString: kMultipartUpload, additionalHeaders: nil, progressBlock: progressBlock, successBlock: successBlock, errorBlock: errorBlock)
        
        uploadTask.cancel()
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    /*
    * As an upload in background task that will be cancelled should have a state of "Running" after I am created
    * I should be able to upload from a string based location
    * I should not reach the successBlock
    * I should reach the errorBlock, and the error's code should tell me that the task was cancelled by user
    */
    func testCancelUploadInBackground() {
        
        var testFinished = expectationWithDescription("test finished")
        let destinationDir: NSArray = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as Array
        let destinationPath = destinationDir.objectAtIndex(0).stringByAppendingPathComponent("1mb.mp4")
        let fm = NSFileManager()
        
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTFail("The download should have failed because it was cancelled")
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertEqual(error.code, NSURLErrorCancelled, "task was not cancelled, it was \(error.localizedDescription)")
            var error: NSError?
            fm.removeItemAtPath(destinationPath, error: &error)
            testFinished.fulfill()
        }
        
        let progressBlock: TSNWUploadProgressBlock = { (bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            NSLog("bytes sent: \(bytesSent), TotalBytesSent: \(totalBytesSent), expectedToSend: \(totalBytesExpectedToSend)")
        }
        
        let sourcePath = NSBundle.mainBundle().pathForResource("ourLord", ofType: "jpg")
        XCTAssertNotNil(sourcePath, "Couldn't find local picture of our lord")
        let data = fm.contentsAtPath(sourcePath)
        
        if let uploadTask = TSNWForeground.uploadInBackground(sourcePath, destinationFullURLString: kMultipartUpload, additionalHeaders: nil, progressBlock: progressBlock, successBlock: successBlock, errorBlock: errorBlock) {
            uploadTask.cancel()
        }
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    /*
    * As an upload in background task that will have a progress block added to me after I am running I should see that the progress block is executed
    */
    func testAddUploadInBackgroundProgressBlock() {
        
        var testFinished = expectationWithDescription("test finished")
        var progressReached = expectationWithDescription("progress block was called")
        
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertNotNil(error, "error not nil, it was \(error.localizedDescription)")
            XCTFail("in the error block, error was: \(error.localizedDescription)")
            testFinished.fulfill()
        }
        
        var fulfilled = false
        let progressBlock: TSNWUploadProgressBlock = { (bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            NSLog("bytes sent: \(bytesSent), TotalBytesSent: \(totalBytesSent), expectedToSend: \(totalBytesExpectedToSend)")
            if !fulfilled {
                progressReached.fulfill() // API violation to call this more than once apparently
                fulfilled = true
            }
        }
        
        let fm = NSFileManager()
        let sourcePath = NSBundle.mainBundle().pathForResource("ourLord", ofType: "jpg")
        XCTAssertNotNil(sourcePath, "Couldn't find local picture of our lord")
        let data = fm.contentsAtPath(sourcePath)
        
        if let uploadTask = TSNWForeground.uploadInBackground(sourcePath, destinationFullURLString: kMultipartUpload, additionalHeaders: nil, progressBlock: progressBlock, successBlock: successBlock, errorBlock: errorBlock) {
            TSNWForeground.addUploadProgressBlock(progressBlock, task: uploadTask)
        }
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    /*
    * As an upload in foreground task that will have a progress block added to me after I am running I should see that the progress block is executed
    */
    func testAddUploadInForegroundProgressBlock() {
        
        var testFinished = expectationWithDescription("test finished")
        var progressReached = expectationWithDescription("progress block was called")
        
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertNotNil(error, "error not nil, it was \(error.localizedDescription)")
            XCTFail("in the error block, error was: \(error.localizedDescription)")
            testFinished.fulfill()
        }
        
        var fulfilled = false
        let progressBlock: TSNWUploadProgressBlock = { (bytesSent, totalBytesSent, totalBytesExpectedToSend) in
            NSLog("bytes sent: \(bytesSent), TotalBytesSent: \(totalBytesSent), expectedToSend: \(totalBytesExpectedToSend)")
            if !fulfilled {
                progressReached.fulfill() // API violation to call this more than once apparently
                fulfilled = true
            }
        }
        
        let fm = NSFileManager()
        let sourcePath = NSBundle.mainBundle().pathForResource("ourLord", ofType: "jpg")
        XCTAssertNotNil(sourcePath, "Couldn't find local picture of our lord")
        let data = fm.contentsAtPath(sourcePath)
        
        let uploadTask = TSNWForeground.uploadInForeground(data, destinationFullURLString: kMultipartUpload, additionalHeaders: nil, progressBlock: progressBlock, successBlock: successBlock, errorBlock: errorBlock)
        TSNWBackground.addUploadProgressBlock(progressBlock, task: uploadTask)
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }

}