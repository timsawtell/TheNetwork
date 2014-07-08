TheNetwork
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

## AppDelegate

Be sure to add this to you AppDelegate. It will ensure that your uploads/downloads that finish when the app has been suspended run their completion blocks.

	func application(application: UIApplication!, handleEventsForBackgroundURLSession identifier: String!, completionHandler: (() -> Void)!) {
      	Network.sessionCompletionHandler = completionHandler
    }

## Initialising:

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: NSDictionary?) -> Bool {
        Network.setBaseURLString("http://en.wikipedia.org/wiki/Gabe_Newell")
        Network.setBasicAuth(user:"username", pass: "password") // will add the Authorization header to every request
        var sessionHeaders = NSDictionary(object: "yes, yes it does", forKey: "does your API require superluous header values?")
        Network.addSessionHeaders(sessionHeaders)
        return true
    }

## Maintaining:

	Network.removeAllSessionHeaders()

## Warning

Any progressBlock is run on the main thread. Feel free to do direct UI manipulation in any progress blocks.

The successBlock and errorBlocks are executed on whatever thread apple decides. I suggest if you're doing UI changes in these blocks that you dispatch_async and get the main queue.

Warning for new players: never directly reference self inside a block, use this style to avoid retain cycles
    
    weak var weakSelf = self
    let successBlock: SuccessBlock = { (resultObject, request, response) in
    	if let strongSelf = weakSelf {
    		dispatch_async(dispatch_get_main_queue(), {
                strongSelf.progressBar.progress = 0 // UI changes, need to be run on main thread if called inside a success or error block
            })
        } else {
        	// the weak reference has since been deallocaed, just return and don't try and run any code. 
        	return
        }
    }

    let progressBlock: UploadProgressBlock = { (bytesSent, totalBytesSent, totalBytesExpectedToSend) in
    	var progress = (Float(totalBytesWritten) / Float(totalBytesExpectedToWrite))
        strongSelf.progressBar.progress = progress // UI changes in a progressBlock, no need to attempt to run on main thread, TheNetwork is already executing this on the main thread
    }

## Optionals in the various methods

	func performDataTask(#relativePath: NSString?,
        method: HTTP_METHOD,
        successBlock: SuccessBlock? = nil,
        errorBlock: ErrorBlock? = nil,
        parameters: NSDictionary? = nil,
        additionalHeaders: NSDictionary? = nil) ->NSURLSessionDataTask

    i.e.

    let task = Network.performDataTask(relativePath: testPath, method: .GET) //or 
    let task = Network.performDataTask(relativePath: testPath, method: .GET, successBlock: someSuccessBlock) // or 
    let task = Network.performDataTask(relativePath: testPath, method: .GET, successBlock: someSuccessBlock, errorBlock: someErrorBlock) // or
    let task = Network.performDataTask(relativePath: testPath, method: .GET, successBlock: someSuccessBlock, errorBlock: someErrorBlock, parameters: someDictionary) //or 
    let task = Network.performDataTask(relativePath: testPath, method: .GET, successBlock: someSuccessBlock, errorBlock: someErrorBlock, parameters: someDictionary, additionalHeaders = someHeadersDictionary) 

## GET

	let successBlock: SuccessBlock = { (resultObject, request, response) -> Void in
        NSLog("\(resultObject)") // resultObject is an AnyObject subclass. It is built based on the the response's content-type header value. If it's "application/JSON" for example, `resultObject` will be either an NSArray or an NSDictionary
    }

    let errorBlock: ErrorBlock = { (resultObject, error, request, response) -> Void in 
    	// you still get a parsed resultObject if the request failed (perhaps the API gave you a 401 and a custom JSON based error object)
    	NSLog("\(error)")
    }

    let additionalParams = NSDictionary(object: "value", forKey: "key")

    let task = Network.performDataTask(relativePath: nil, method: .GET, successBlock: successBlock, errorBlock: errorBlock, parameters: additionalParams)

## POST

#### POST some JSON

	let additionalParams = NSDictionary(object: "value", forKey: "key")
	Network.bodyFormatter = BodyFormatterJSON() // it's BodyFormatterJSON by default, FYI
    let task = Network.performDataTask(relativePath: nil, method: .POST, parameters: additionalParams)

#### POST some XML-PLIST

	let additionalParams = NSDictionary(object: "value", forKey: "key")
	Network.bodyFormatter = BodyFormatterPListXML()
    let task = Network.performDataTask(relativePath: nil, method: .POST, parameters: additionalParams)

#### POST some custom data

	Network.bodyFormatter = BodyFormatterManual(block: {() -> NSData in
        var string = "some crazy\nnew line\nstring with no \npattern\nat all"
        return string.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
    })
    let additionalHeaders = NSDictionary(object: "text/WTF", forKey: "Content-Type")
    let task = Network.performDataTask(relativePath: nil, method: .POST, additionalHeaders: additionalHeaders)

## Download


Note: the progressBlock is explicitly executed on the main thread. You don't need to dispatch_async to get the main queue in the progressBlock


    let destinationDir: NSArray = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as Array
    let destinationPath = destinationDir.objectAtIndex(0).stringByAppendingPathComponent("5mb.zip")
    
    let successBlock: SuccessBlock = { (resultObject, request, response) -> Void in
        NSLog("\(resultObject)") // resultObject will be an NSURL pointing to `destinationPath`, the location that the downloaded file was moved to.
    }
    
    let errorBlock: ErrorBlock = { (resultObject, error, request, response) -> Void in
        NSLog("\(error)")
    }
    
    let progressBlock: DownloadProgressBlock = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) -> Void in
        NSLog("Download written: \(bytesWritten), TotalBytesWritten: \(totalBytesWritten), expectedToWrite: \(totalBytesExpectedToWrite)")
    }
    
    let task = Network.download(fullSourceURL: "http://ipv4.download.thinkbroadband.com/5MB.zip", destinationPathString: destinationPath, successBlock: successBlock, errorBlock: errorBlock, progressBlock: progressBlock)

## Upload


Note: the progressBlock is explicitly executed on the main thread. You don't need to dispatch_async to get the main queue in the progressBlock


    let successBlock: SuccessBlock = { (resultObject, request, response) -> Void in
        NSLog("\(resultObject)") // resultObject will be whatever the server responded with when the upload finished.
    }
    
    let errorBlock: ErrorBlock = { (resultObject, error, request, response) -> Void in
        XCTAssertNotNil(error, "error not nil, it was \(error.localizedDescription)")
        XCTFail("in the error block, error was: \(error.localizedDescription)")
        testFinished.fulfill()
    }
    
    let progressBlock: UploadProgressBlock = { (bytesSent, totalBytesSent, totalBytesExpectedToSend) in
        NSLog("bytes sent: \(bytesSent), TotalBytesSent: \(totalBytesSent), expectedToSend: \(totalBytesExpectedToSend)")
    }
    
    let fm = NSFileManager()
    let sourcePath = NSBundle.mainBundle().pathForResource("ourLord", ofType: "jpg")
    XCTAssertNotNil(sourcePath, "Couldn't find local picture to upload")
    let sourceURL = NSURL.fileURLWithPath(sourcePath)
    
    let task = Network.upload(sourceURL: sourceURL, destinationFullURLString: kMultipartUpload, successBlock: successBlock, errorBlock: errorBlock, progressBlock: progressBlock)

## Multipart Form 

	let fm = NSFileManager()
    let sourcePath = NSBundle.mainBundle().pathForResource("ourLord", ofType: "jpg")
    let data = fm.contentsAtPath(sourcePath)
    var formDataFile = MultipartFormFile(formKeyName: "image", fileName: "ourlord.jpg", data: data, mimetype: "image/jpeg")
    let arrayOfFiles = [formDataFile]
    
    let params = ["key": "value", "anotherkey": "anothervalue"]
    
    let uploadTask = Network.multipartFormPost(relativePath: nil, parameters: params, multipartFormFiles: arrayOfFiles)