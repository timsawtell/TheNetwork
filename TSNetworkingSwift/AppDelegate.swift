//
//  AppDelegate.swift
//  TSNetworkingSwift
//
//  Created by Tim Sawtell on 11/06/2014.
//
//

import UIKit

let kNoAuthNeeded = "http://localhost:8081";
let kAuthNeeded = "http://localhost:8080";
let kJSON = "http://localhost:8083";
let kMultipartUpload = "http://localhost:8082/upload";

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
                            
    var window: UIWindow?


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: NSDictionary?) -> Bool {
        /*
        let successBlock: TSNWSuccessBlock = { (resultObject: AnyObject?, request: NSURLRequest, response: NSURLResponse?) -> Void in
            var shouldBeURL = "\(kNoAuthNeeded)?key=value"
            NSLog("the query string wasn't set correctly, it was \(request.URL.absoluteString)")
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject: AnyObject?, error: NSError, request: NSURLRequest?, response: NSURLResponse?) -> Void in
            NSLog("error not nil, it was \(error.localizedDescription)")
            NSLog("in the error block, error was: \(error.localizedDescription)")
        }
        var additionalParams = NSDictionary(object: "value", forKey: "key")
        TSNWForeground.setBaseURLString(kAuthNeeded)
        TSNWForeground.setBasicAuth("hack", pass: "thegibson")
        TSNWForeground.performDataTaskWithRelativePath(nil, method: HTTP_METHOD.GET, parameters: additionalParams, additionalHeaders: nil, successBlock: successBlock, errorBlock: errorBlock)
        */
        return true
    }
    
    func application(application: UIApplication!, handleEventsForBackgroundURLSession identifier: String!, completionHandler: (() -> Void)!) {
        TSNWBackground.sessionCompletionHandler = completionHandler
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

