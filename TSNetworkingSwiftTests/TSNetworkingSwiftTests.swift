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
    
    func testGet() {
        
        var testFinished = expectationWithDescription("test finished")
        let testPath = "something"
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
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
    
    func testGetAdditionalHeaders() {
        
        var testFinished = expectationWithDescription("test finished")
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
            var requestHeaders = request.allHTTPHeaderFields
            XCTAssertTrue(requestHeaders.valueForKey("Accept").isEqualToString("application/json"), "Accept header missing")
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
        TSNWForeground.addSessionHeaders(NSDictionary(object: "application/json", forKey: "Accept"))
        var task: NSURLSessionDataTask = TSNWForeground.performDataTaskWithRelativePath(nil, method: .GET, parameters: nil, additionalHeaders: additionalHeaders, successBlock: successBlock, errorBlock: errorBlock)
        XCTAssertEqual(task.originalRequest.HTTPMethod, HTTP_METHOD.GET.toRaw(), "task wasn't a GET")
        waitForExpectationsWithTimeout(4, handler: nil)
    }
    
    func testGetWithParameters() {
        
        var testFinished = expectationWithDescription("test finished")
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
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
    * POST tests
    */
    
    func testPostWithPameters() {
        
        var testFinished = expectationWithDescription("test finished")
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
            var body = NSString(data: request.HTTPBody, encoding: NSUTF8StringEncoding)
            XCTAssertNotNil(body, "body had no content for the POST")
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
        XCTAssertEqual(task.originalRequest.HTTPMethod, HTTP_METHOD.POST.toRaw(), "task wasn't a GET")
        XCTAssertEqual(task.originalRequest.allHTTPHeaderFields.objectForKey("Content-Type") as String, "application/json", "the content type was not set")
        waitForExpectationsWithTimeout(4, handler: nil)
    }
    
    /*
    * Download tests
    */
    
    func testDownloadFile() {
        
        var testFinished = expectationWithDescription("test finished")
        let destinationDir: NSArray = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as Array
        let destinationPath = destinationDir.objectAtIndex(0).stringByAppendingPathComponent("ourLord.jpeg")

        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
            XCTAssertNotNil(resultObject, "nil result obj")
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
        
        var task: NSURLSessionDownloadTask = TSNWBackground.downloadFromFullFullURL("http://images.dailytech.com/nimage/gabe_newell.jpeg", destinationPathString: destinationPath, additionalHeaders: nil, progressBlock: progressBlock, successBlock: successBlock, errorBlock: errorBlock)
        XCTAssertNotNil(task, "The download task was nil")
        XCTAssertEqual(task.state, NSURLSessionTaskState.Running, "download not started")
        waitForExpectationsWithTimeout(10, handler: nil)
    }
}