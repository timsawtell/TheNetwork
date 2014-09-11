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
        var error: NSError?
        if let jsonData = NSJSONSerialization.dataWithJSONObject(userParameters!, options: NSJSONWritingOptions.PrettyPrinted, error: &error) {
            userRequest.HTTPBody = jsonData
            if userRequest.valueForHTTPHeaderField("Content-Type") == nil && userRequest.valueForHTTPHeaderField("content-type") == nil {
                let encoding = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding))
                userRequest.setValue("application/json; charset=\(encoding)", forHTTPHeaderField: "Content-Type")
            }
            return nil
        } else {
            return error
        }
    }
}

class BodyFormatterPListXML: BodyFormatter {
    func formatData(userParameters: AnyObject?, userRequest: NSMutableURLRequest) -> NSError? {
        var error: NSError?
        if let plistData = NSPropertyListSerialization.dataWithPropertyList(userParameters!, format: NSPropertyListFormat.XMLFormat_v1_0, options:0, error: &error) {
            userRequest.HTTPBody = plistData
            if userRequest.valueForHTTPHeaderField("Content-Type") == nil && userRequest.valueForHTTPHeaderField("content-type") == nil {
                let encoding = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding))
                userRequest.setValue("application/x-plist; charset=\(encoding)", forHTTPHeaderField: "Content-Type")
            }
            return nil
        } else {
            return error
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