//
//  AppDelegate.swift
//  Jarvis
//
//  Created by Aarush Agarwal on 3/23/25.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    // Four-character codes in UInt32 form:
    // 'MyAP' (My App Suite) and 'SndM' (sendMessage command)
    let myAppSuiteEventClass: UInt32 = 0x4D794150 // 'M' 'y' 'A' 'P'
    let sendMessageEventID: UInt32 = 0x536E644D   // 'S' 'n' 'd' 'M'
    let messageParamKeyword: AEKeyword = 0x4D657373 // 'M' 'e' 's' 's' for parameter "messageText"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register the Apple event handler for the sendMessage command
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleSendMessageEvent(event:replyEvent:)),
            forEventClass: OSType(myAppSuiteEventClass),
            andEventID: OSType(sendMessageEventID)
        )
    }

    @objc func handleSendMessageEvent(event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        // Extract the "messageText" parameter from the event using its four-letter code
        guard let messageDescriptor = event.paramDescriptor(forKeyword: messageParamKeyword),
              let messageText = messageDescriptor.stringValue else {
            print("No message provided in AppleScript command.")
            return
        }
        print("Received AppleScript command to send message: \(messageText)")
        // Here you can forward this message to your app’s view model or perform any other action.
        //
        // For example, if your ChatViewModel had a method to handle incoming AppleScript messages,
        // you could post a notification or call that method.
    }
}
