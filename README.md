TSNetworkingSwift
============

A networking library writen in Swift that's tailored for the most common web services requirements.

Simple, predictable, reliable. (HA! To the extent that the Swift language allows)

## Features

- Background session. Your uploads and downloads are handled by iOS even when you app is minimized. It will even run the completion blocks when your app isn't in the foreground.
- Automatic handling of network loss. Your downloads will pause and resume when you go offline. This even works when your app is minimized.
- The resultObject in the successBlocks is built up slightly depending on the response's content-type. i.e. if the response is JSON, the resultObject with be an NSDictionary or NSArray.
- Easily add per-request headers to your network tasks.
- Easily set the BASIC authentication and add sessions header values that will persist for your app's lifetime.

## Using cocoapods?

Sorry but until Apple allows XCode to build static libraries with Swift code there is no cocoapod. Yet. Stay tuned.

## AppDelegate.m

Be sure to add this to you AppDelegate. It will ensure that your uploads/downloads that finish when the app has been suspended run their completion blocks.

	func application(application: UIApplication!, handleEventsForBackgroundURLSession identifier: String!, completionHandler: (() -> Void)!) {
      	TSNWManager.sessionCompletionHandler = completionHandler
    }

## Initialising:

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: NSDictionary?) -> Bool {
        TSNWManager.setBaseURLString("http://en.wikipedia.org/wiki/Gabe_Newell")
        TSNWManager.setBasicAuth("username", pass: "password") // will add the Authorization header to every request
        var sessionHeaders = NSDictionary(object: "yes, yes it does", forKey: "does your API require superluous header values?")
        TSNWManager.addSessionHeaders(sessionHeaders)
        return true
    }

## Maintaining:

	TSNWManager.removeAllSessionHeaders()

## Warning

The success and error blocks are executed on whatever thread apple decides.
I suggest if you're doing UI changes in these blocks that you dispatch_async and get the main queue.
Warning for new players: never directly reference self inside a block, use this style to avoid retain cycles
    
    weak var weakSelf = self
    let successBlock: TSNWSuccessBlock = { (resultObject, request, response) in
    	if let strongSelf = weakSelf {
            strongSelf.progressBar.progress = 0
        } else {
        	// the weak reference has since been deallocaed, just return and don't try and run any code. 
        	return
        }
    };

## Optionals in the various methods

	func performDataTaskWithRelativePath(relativePath: NSString?,
        method: HTTP_METHOD,
        successBlock: TSNWSuccessBlock? = nil,
        errorBlock: TSNWErrorBlock? = nil,
        parameters: NSDictionary? = nil,
        additionalHeaders: NSDictionary? = nil) ->NSURLSessionDataTask

    i.e.

    let task = TSNWManager.performDataTaskWithRelativePath(testPath, method: .GET) //or 
    let task = TSNWManager.performDataTaskWithRelativePath(testPath, method: .GET, successBlock: someSuccessBlock) // or 
    let task = TSNWManager.performDataTaskWithRelativePath(testPath, method: .GET, successBlock: someSuccessBlock, errorBlock: someErrorBlock) // or
    let task = TSNWManager.performDataTaskWithRelativePath(testPath, method: .GET, successBlock: someSuccessBlock, errorBlock: someErrorBlock, parameters: someDictionary) //or 
    let task = TSNWManager.performDataTaskWithRelativePath(testPath, method: .GET, successBlock: someSuccessBlock, errorBlock: someErrorBlock, parameters: someDictionary, additionalHeaders = someHeadersDictionary) 

## GET

	let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
        NSLog("\(resultObject)") // resultObject is an AnyObject subclass. It is built based on the the response's content-type header value. If it's "application/JSON" for example, `resultObject` will be either an NSArray or an NSDictionary
    }

    let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in 
    	// you still get a parsed resultObject if the request failed (perhaps the API gave you a 401 and a custom JSON based error object)
    	NSLog("\(error)")
    }

    let additionalParams = NSDictionary(object: "value", forKey: "key")

    let task = TSNWManager.performDataTaskWithRelativePath(nil, method: .GET, successBlock: successBlock, errorBlock: errorBlock, parameters: additionalParams)

## POST

#### POST some JSON

	let additionalParams = NSDictionary(object: "value", forKey: "key")
	TSNWManager.bodyFormatter = TSNBodyFormatterJSON() // it's TSNBodyFormatterJSON by default, FYI
    let task = TSNWManager.performDataTaskWithRelativePath(nil, method: .POST, parameters: additionalParams)

#### POST some XML-PLIST

	let additionalParams = NSDictionary(object: "value", forKey: "key")
	TSNWManager.bodyFormatter = TSNBodyFormatterPListXML()
    let task = TSNWManager.performDataTaskWithRelativePath(nil, method: .POST, parameters: additionalParams)

#### POST some custom data

	TSNWManager.bodyFormatter = TSNBodyFormatterManual(block: {() -> NSData in
        var string = "some crazy\nnew line\nstring with no \npattern\nat all"
        return string.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
    })
    let additionalHeaders = NSDictionary(object: "text/WTF", forKey: "Content-Type")
    let task = TSNWManager.performDataTaskWithRelativePath(nil, method: .POST, additionalHeaders: additionalHeaders)

## Download

    let destinationDir: NSArray = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as Array
    let destinationPath = destinationDir.objectAtIndex(0).stringByAppendingPathComponent("5mb.zip")
    
    let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
        NSLog("\(resultObject)") // resultObject will be an NSURL pointing to `destinationPath`, the location that the downloaded file was moved to.
    }
    
    let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) -> Void in
        NSLog("\(error)")
    }
    
    let progressBlock: TSNWDownloadProgressBlock = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
        NSLog("Download written: \(bytesWritten), TotalBytesWritten: \(totalBytesWritten), expectedToWrite: \(totalBytesExpectedToWrite)")
    }
    
    let task = TSNWManager.downloadFromFullURL("http://ipv4.download.thinkbroadband.com/5MB.zip", destinationPathString: destinationPath, successBlock: successBlock, errorBlock: errorBlock, progressBlock: progressBlock)

## Upload

    let successBlock: TSNWSuccessBlock = { (resultObject, request, response) -> Void in
        NSLog("\(resultObject)") // resultObject will be whatever the server responded with when the upload finished.
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

## Multipart Form 

	let fm = NSFileManager()
    let sourcePath = NSBundle.mainBundle().pathForResource("ourLord", ofType: "jpg")
    let data = fm.contentsAtPath(sourcePath)
    var formDataFile = MultipartFormFile(formKeyName: "image", fileName: "ourlord.jpg", data: data, mimetype: "image/jpeg")
    var arrayOfFiles = MultipartFormFile[]()
    arrayOfFiles.append(formDataFile)
    
    let params = NSMutableDictionary(object: "value", forKey: "key")
    params.setValue("anotherValue", forKey: "anotherKey")
    
    let uploadTask = TSNWManager.multipartFormPost(nil, parameters: params, multipartFormFiles: arrayOfFiles)