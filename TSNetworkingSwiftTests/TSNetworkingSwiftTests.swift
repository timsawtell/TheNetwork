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
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    
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
        TSNWForeground.performDataTaskWithRelativePath(testPath, method: HTTP_METHOD.GET, parameters: nil, additionalHeaders: nil, successBlock: successBlock, errorBlock: errorBlock)
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
        TSNWForeground.performDataTaskWithRelativePath(nil, method: HTTP_METHOD.GET, parameters: nil, additionalHeaders: additionalHeaders, successBlock: successBlock, errorBlock: errorBlock)
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
        TSNWForeground.performDataTaskWithRelativePath(nil, method: HTTP_METHOD.GET, parameters: additionalParams, additionalHeaders: nil, successBlock: successBlock, errorBlock: errorBlock)
        waitForExpectationsWithTimeout(4, handler: nil)
    }
}
