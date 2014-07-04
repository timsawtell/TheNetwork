//
//  DemoViewController.swift
//  TSNetworkingSwift
//
//  Created by Tim Sawtell on 23/06/2014.
//
//

import Foundation
import UIKit

class DemoViewController: UIViewController {
    @IBOutlet var button: UIButton
    @IBOutlet var progressBar: UIProgressView
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    @IBAction func downloadPressed(sender: AnyObject) {
        let button = sender as UIButton
        button.userInteractionEnabled = false;
        button.setTitle("downloading ...", forState: .Normal)
        
        weak var weakSelf = self
        let successBlock: TSNWSuccessBlock = { (resultObject, request, response) in
            if let url = resultObject as? NSURL {
                NSLog("Finished downloading to \(url.path)")
            } else {
                NSLog("Unexpected result, the resultObject was not an NSURL")
            }
            button.userInteractionEnabled = true
            button.setTitle("Download", forState: .Normal)
            if let strongSelf = weakSelf {
                strongSelf.progressBar.progress = 0
            }
        }
        
        let errorBlock: TSNWErrorBlock = { (resultObject, error, request, response) in
            NSLog("Uh oh things didn't work out: \(error.localizedDescription)")
            button.userInteractionEnabled = true
            button.setTitle("Download", forState: .Normal)
            if let strongSelf = weakSelf {
                strongSelf.progressBar.progress = 0
            }
        }
        
        let progressBlock: TSNWDownloadProgressBlock = { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) in
            let hBytesWritten = NSByteCountFormatter.stringFromByteCount(bytesWritten, countStyle: .File)
            let hTotalWritten = NSByteCountFormatter.stringFromByteCount(totalBytesWritten, countStyle: .File)
            let hTotalToWrite = NSByteCountFormatter.stringFromByteCount(totalBytesExpectedToWrite, countStyle: .File)
            NSLog("Download written: \(hBytesWritten), TotalBytesWritten: \(hTotalWritten), expectedToWrite: \(hTotalToWrite)")
            var progress = (Float(totalBytesWritten) / Float(totalBytesExpectedToWrite))
            if let strongSelf = weakSelf {
                strongSelf.progressBar.progress = Float(progress)
            }
        }
        
        let destinationDir: NSArray = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as Array
        let destinationPath = destinationDir.objectAtIndex(0).stringByAppendingPathComponent("ourLord.jpeg")
        let dlFile = "http://ipv4.download.thinkbroadband.com/10MB.zip"
        
        TSNWManager.downloadFromFullURL(dlFile, destinationPathString: destinationPath, additionalHeaders: nil, progressBlock: progressBlock, successBlock: successBlock, errorBlock: errorBlock)
    }
    
}
