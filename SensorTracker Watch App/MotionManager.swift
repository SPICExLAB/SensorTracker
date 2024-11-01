//
//  MotionManager.swift
//  MobilePoser Watch App
//
//

import CoreMotion
import UIKit
import WatchKit
import WatchConnectivity


class MotionManager {
    
    var motionManager: CMMotionManager!
    var queue: OperationQueue!
    var sampleInterval: Double = 25.0
    // var socketClient: SocketClient?
    
    init() {
        // self.socketClient = socketClient
        motionManager = CMMotionManager()
        queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.name = "MotionManagerQueue"
    }
    
    func setSamplingRate(value: Double) {
        sampleInterval = 1.0 / value
    }
  
    func startRecording() {
        if !(motionManager.isDeviceMotionAvailable) {
            print("Device motion is unavailable.")
            return
        }
    
        print("Start updates.")
        motionManager.deviceMotionUpdateInterval = sampleInterval
        motionManager.startDeviceMotionUpdates(using: .xTrueNorthZVertical, to: queue) { (data, error) in
            
            guard error == nil else {
                return
            }
            
            if let data = data {
                let motionText = "\(NSDate().timeIntervalSince1970) \(data.timestamp) \(data.userAcceleration.x) \(data.userAcceleration.y) \(data.userAcceleration.z) \(data.attitude.quaternion.x) \(data.attitude.quaternion.y) \(data.attitude.quaternion.z) \(data.attitude.quaternion.w) \(data.rotationRate.x) \(data.rotationRate.y) \(data.rotationRate.z)\n"

                if (WCSession.default.isReachable) {
                    WCSession.default.sendMessage(["motionData": motionText], replyHandler: nil)
                    // print("Motion data transferred.")
                } else {
                    print("WCSession is not activated.")
                }
                
                // self.socketClient?.send(text: motionText)
                
                
            }
        }
    }
    
    func stopRecording() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.stopDeviceMotionUpdates()
            print("End updates")
        }
    }
}
