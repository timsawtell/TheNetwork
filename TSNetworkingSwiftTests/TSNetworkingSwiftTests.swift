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
        TSNWManager.removeAllSessionHeaders()
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
        TSNWManager.setBaseURLString(kNoAuthNeeded)
        let task = TSNWManager.performDataTaskWithRelativePath(testPath, method: .GET, successBlock: successBlock, errorBlock: errorBlock)
        
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
        TSNWManager.setBaseURLString(kNoAuthNeeded)
        let task = TSNWManager.performDataTaskWithRelativePath(nil, method: .GET, successBlock: successBlock, errorBlock: errorBlock, additionalHeaders: additionalHeaders)
        
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
            TSNWManager.removeAllSessionHeaders()
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertNotNil(error, "error not nil, it was \(error.localizedDescription)")
            XCTFail("in the error block, error was: \(error.localizedDescription)")
            testFinished.fulfill()
        }
        
        TSNWManager.setBaseURLString(kNoAuthNeeded)
        TSNWManager.addSessionHeaders(NSDictionary(object: "application/json", forKey: "Accept"))
        
        let task = TSNWManager.performDataTaskWithRelativePath(nil, method: .GET, successBlock: successBlock, errorBlock: errorBlock)
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
        TSNWManager.setBaseURLString(kNoAuthNeeded)
        
        let task = TSNWManager.performDataTaskWithRelativePath(nil, method: .GET, successBlock: successBlock, errorBlock: errorBlock, parameters: additionalParams)
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
        TSNWManager.setBaseURLString(kAuthNeeded)
        TSNWManager.setBasicAuth("hack", pass: "thegibson")
        
        let task = TSNWManager.performDataTaskWithRelativePath(nil, method: .GET, successBlock: successBlock, errorBlock: errorBlock)
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
        TSNWManager.setBaseURLString(kAuthNeeded)
        TSNWManager.setBasicAuth("hack", pass: "thegibsonWRONG")
        let task = TSNWManager.performDataTaskWithRelativePath(nil, method: .GET, successBlock: successBlock, errorBlock: errorBlock)
        
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
        TSNWManager.setBaseURLString(kJSON)
        
        let task = TSNWManager.performDataTaskWithRelativePath(nil, method: .GET, successBlock: successBlock, errorBlock: errorBlock)
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
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertNotNil(error, "error not nil, it was \(error.localizedDescription)")
            XCTFail("in the error block, error was: \(error.localizedDescription)")
            testFinished.fulfill()
        }
        var additionalParams = NSDictionary(object: "value", forKey: "key")
        TSNWManager.setBaseURLString(kNoAuthNeeded)
        
        let task = TSNWManager.performDataTaskWithRelativePath(nil, method: .POST, successBlock: successBlock, errorBlock: errorBlock, parameters: additionalParams)
        XCTAssertEqual(task.originalRequest.HTTPMethod, HTTP_METHOD.POST.toRaw(), "task wasn't a POST")
        waitForExpectationsWithTimeout(4, handler: nil)
    }

    /*
    * As a POST request using the default JSON body formatter I should have a HTTPMethod of "POST"
    * I should have a request body is JSON
    * I should contain headers in the requests stating the content-type
    */
    func testJSONPostWithPameters() {
        
        var testFinished = expectationWithDescription("test finished")
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
            XCTAssertEqual("cheers man", resultObject as String, "result object was not what kNoAuthNeeded node server returns")
            
            let bodyData = request.HTTPBody
            XCTAssertNotNil(bodyData, "No body data for the POST")
            
            var error: NSError?
            let parsedJSON: AnyObject = NSJSONSerialization.JSONObjectWithData(bodyData, options: .MutableContainers, error: &error)
            
            XCTAssertNotNil(parsedJSON, "Request body was not valid JSON")
            if let realError = error {
                XCTFail("Parse error: \(realError.localizedDescription)")
            }
            if let jsonDict: NSDictionary = parsedJSON as? NSDictionary {
                let found = jsonDict.valueForKey("key") as String
                XCTAssertEqual(found, "value")
            } else {
                XCTFail("Parsed JSON was not a dictionary")
            }
            
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertNotNil(error, "error not nil, it was \(error.localizedDescription)")
            XCTFail("in the error block, error was: \(error.localizedDescription)")
            testFinished.fulfill()
        }
        var additionalParams = NSDictionary(object: "value", forKey: "key")
        TSNWManager.setBaseURLString(kNoAuthNeeded)
        TSNWManager.bodyFormatter = TSNBodyFormatterJSON()
        
        let task = TSNWManager.performDataTaskWithRelativePath(nil, method: .POST, successBlock: successBlock, errorBlock: errorBlock, parameters: additionalParams)
        XCTAssertEqual(task.originalRequest.HTTPMethod, HTTP_METHOD.POST.toRaw(), "task wasn't a POST")
        var value = task.originalRequest.allHTTPHeaderFields.objectForKey("Content-Type") as String
        XCTAssertTrue(value.bridgeToObjectiveC().containsString("application/json"), "the default JSON content type was not set")
        waitForExpectationsWithTimeout(4, handler: nil)
    }
    
    /*
    * As a POST request using the default JSON body formatter I should have a HTTPMethod of "POST"
    * I should have a request body is JSON
    * I should contain headers in the requests stating the content-type
    */
    func testXMLPostWithPameters() {
        
        var testFinished = expectationWithDescription("test finished")
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
            XCTAssertEqual("cheers man", resultObject as String, "result object was not what kNoAuthNeeded node server returns")
            
            let bodyData = request.HTTPBody
            XCTAssertNotNil(bodyData, "No body data for the POST")
            
            var error: NSError?
            let parsedXML: AnyObject = NSPropertyListSerialization.propertyListWithData(bodyData, options: 0, format: nil, error: &error)
            
            XCTAssertNotNil(parsedXML, "Request body was not valid JSON")
            if let realError = error {
                XCTFail("Parse error: \(realError.localizedDescription)")
            }
            if let jsonDict: NSDictionary = parsedXML as? NSDictionary {
                let found = jsonDict.valueForKey("key") as String
                XCTAssertEqual(found, "value")
            } else {
                XCTFail("Parsed XML was not a dictionary")
            }
            
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertNotNil(error, "error not nil, it was \(error.localizedDescription)")
            XCTFail("in the error block, error was: \(error.localizedDescription)")
            testFinished.fulfill()
        }
        var additionalParams = NSDictionary(object: "value", forKey: "key")
        TSNWManager.setBaseURLString(kNoAuthNeeded)
        TSNWManager.bodyFormatter = TSNBodyFormatterPListXML() // change the default body formatter
        let task = TSNWManager.performDataTaskWithRelativePath(nil, method: .POST, successBlock: successBlock, errorBlock: errorBlock, parameters: additionalParams)
        
        XCTAssertEqual(task.originalRequest.HTTPMethod, HTTP_METHOD.POST.toRaw(), "task wasn't a POST")
        var value = task.originalRequest.allHTTPHeaderFields.objectForKey("Content-Type") as String
        XCTAssertTrue(value.bridgeToObjectiveC().containsString("application/x-plist"), "the default x-plist content type was not set")
        waitForExpectationsWithTimeout(4, handler: nil)
    }
    
    /*
    * As a POST request using the default JSON body formatter I should have a HTTPMethod of "POST"
    * I should have a request body is JSON
    * I should contain headers in the requests stating the content-type
    */
    func testCustomPostBody() {
        
        var testFinished = expectationWithDescription("test finished")
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
            XCTAssertEqual("cheers man", resultObject as String, "result object was not what kNoAuthNeeded node server returns")
            
            let bodyData = request.HTTPBody
            XCTAssertNotNil(bodyData, "No body data for the POST")
            var string = NSString(data: bodyData, encoding: NSUTF8StringEncoding)
            XCTAssertNotNil(string, "body string was nil")
            XCTAssertTrue(string.containsString("some crazy"), "didn't contain the string from our custom body formatter")
            testFinished.fulfill()
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
            XCTAssertNotNil(error, "error not nil, it was \(error.localizedDescription)")
            XCTFail("in the error block, error was: \(error.localizedDescription)")
            testFinished.fulfill()
        }
        TSNWManager.setBaseURLString(kNoAuthNeeded)
        TSNWManager.bodyFormatter = TSNBodyFormatterManual(block: {() -> NSData in
            var string = "some crazy\nnew line\nstring with no \npattern\nat all"
            return string.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
        })
        let task = TSNWManager.performDataTaskWithRelativePath(nil, method: .POST, successBlock: successBlock, errorBlock: errorBlock)
        XCTAssertEqual(task.originalRequest.HTTPMethod, HTTP_METHOD.POST.toRaw(), "task wasn't a POST")
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
        
        let task = TSNWManager.downloadFromFullURL(remoteGabe, destinationPathString: destinationPath, successBlock: successBlock, errorBlock: errorBlock, progressBlock: progressBlock)
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
        let destinationPath = destinationDir.objectAtIndex(0).stringByAppendingPathComponent("5mb.zip")
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
        
        let task = TSNWManager.downloadFromFullURL("http://ipv4.download.thinkbroadband.com/5MB.zip", destinationPathString: destinationPath, successBlock: successBlock, errorBlock: errorBlock, progressBlock: progressBlock)
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
        
        let task = TSNWManager.downloadFromFullURL(remoteGabe, destinationPathString: destinationPath, successBlock: successBlock, errorBlock: errorBlock)
        XCTAssertEqual(task.state, NSURLSessionTaskState.Running, "task not started")
        TSNWManager.addDownloadProgressBlock(progressBlock, task: task)
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    /*
    * upload tests
    */

    /*
    * As an upload in background task I should have a state of "Running" after I am created
    * I should be able to upload from a string based source location.
    * I should have a state of "Running" after I am created
    * Unfortunately I cant find a way to simulate minimizing or exiting the app and having the download task finish as expected
    */
    func testuploadSourceURL() {
        
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
        XCTAssertNotNil(sourcePath, "Couldn't find local picture to upload")
        let sourceURL = NSURL.fileURLWithPath(sourcePath)
        
        let task = TSNWManager.uploadSourceURL(sourceURL, destinationFullURLString: kMultipartUpload, successBlock: successBlock, errorBlock: errorBlock, progressBlock: progressBlock)
        XCTAssertEqual(task.state, NSURLSessionTaskState.Running, "task not started")
        
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    /*
    * As an upload in background task that will be cancelled should have a state of "Running" after I am created
    * I should be able to upload from a string based location
    * I should not reach the successBlock
    * I should reach the errorBlock, and the error's code should tell me that the task was cancelled by user
    */
    func testCanceluploadSourceURL() {
        
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
        XCTAssertNotNil(sourcePath, "Couldn't find local picture to upload")
        let sourceURL = NSURL.fileURLWithPath(sourcePath)
        
        let task = TSNWManager.uploadSourceURL(sourceURL, destinationFullURLString: kMultipartUpload, successBlock: successBlock, errorBlock: errorBlock, progressBlock: progressBlock)
        task.cancel()
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    /*
    * As an upload in background task that will have a progress block added to me after I am running I should see that the progress block is executed
    */
    func testAddUploadSourceURLProgressBlock() {
        
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
        XCTAssertNotNil(sourcePath, "Couldn't find local picture to upload")
        
        let sourceURL = NSURL.fileURLWithPath(sourcePath)
        
        let task = TSNWManager.uploadSourceURL(sourceURL, destinationFullURLString: kMultipartUpload, successBlock: successBlock, errorBlock: errorBlock, progressBlock: progressBlock)
        TSNWManager.addUploadProgressBlock(progressBlock, task: task)
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testMultipartFormData() {
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
        
        let params = NSMutableDictionary(object: "value", forKey: "key")
        params.setValue("anotherValue", forKey: "anotherKey")
        
        let fm = NSFileManager()
        let sourcePath = NSBundle.mainBundle().pathForResource("ourLord", ofType: "jpg")
        XCTAssertNotNil(sourcePath, "Couldn't find local picture to upload")
        let data = fm.contentsAtPath(sourcePath)
        XCTAssertNotNil(data, "data was nil")        
        var formDataFile = MultipartFormFile(formKeyName: "image", fileName: "ourlord.jpg", data: data, mimetype: "image/jpeg")
        var formDataFile2 = MultipartFormFile(formKeyName: "image2", fileName: "ourlord2.jpg", data: data, mimetype: "image/jpeg")
        var arrayOfFiles = MultipartFormFile[]()
        arrayOfFiles.append(formDataFile)
        arrayOfFiles.append(formDataFile2)
        
        TSNWManager.setBaseURLString(kMultipartUpload)
        let uploadTask = TSNWManager.multipartFormPost(nil, parameters: params, multipartFormFiles: arrayOfFiles, successBlock: successBlock, errorBlock: errorBlock)
        waitForExpectationsWithTimeout(10, handler: nil)
    }

}