//
//  TSNBodyFormatter.swift
//  TSNetworkingSwift
//
//  Created by Tim Sawtell on 1/07/2014.
//
//

import Foundation

protocol BodyFormatter {
    func formatData(usingParameters: AnyObject?, userRequest: NSMutableURLRequest) -> NSError?
}

class BodyFormatterJSON: BodyFormatter {
    func formatData(userParameters: AnyObject?, userRequest: NSMutableURLRequest) -> NSError? {
        do {
            let jsonData = try NSJSONSerialization.dataWithJSONObject(userParameters!, options: NSJSONWritingOptions.PrettyPrinted)
            userRequest.HTTPBody = jsonData
            if userRequest.valueForHTTPHeaderField("Content-Type") == nil && userRequest.valueForHTTPHeaderField("content-type") == nil {
                let encoding = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding))
                userRequest.setValue("application/json; charset=\(encoding)", forHTTPHeaderField: "Content-Type")
            }
            return nil
        } catch let error {
            return error as NSError
        }
    }
}

class BodyFormatterPListXML: BodyFormatter {
    func formatData(userParameters: AnyObject?, userRequest: NSMutableURLRequest) -> NSError? {
        do {
            let plistData = try NSPropertyListSerialization.dataWithPropertyList(userParameters!, format: NSPropertyListFormat.XMLFormat_v1_0, options:0)
            userRequest.HTTPBody = plistData
            if userRequest.valueForHTTPHeaderField("Content-Type") == nil && userRequest.valueForHTTPHeaderField("content-type") == nil {
                let encoding = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding))
                userRequest.setValue("application/x-plist; charset=\(encoding)", forHTTPHeaderField: "Content-Type")
            }
            return nil
        } catch let error {
            return error as NSError
        }
    }
}

typealias ManualBodyDataBlock = () -> NSData

class BodyFormatterManual: BodyFormatter {
    var manualDataBlock: ManualBodyDataBlock?
    
    init(block: ManualBodyDataBlock) {
        manualDataBlock = block
    }
    
    func formatData(usingParameters: AnyObject?, userRequest: NSMutableURLRequest) -> NSError? {
        if let block = manualDataBlock {
            userRequest.HTTPBody = block()
        }
        return nil
    }
    
}