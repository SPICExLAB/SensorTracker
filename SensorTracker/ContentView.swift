//
//  ContentView.swift
//  SensorTracker
//
//  Created by Vasco Xu on 9/30/24.
//

import SwiftUI
import CoreMotion
import WatchConnectivity
import NearbyInteraction
import CoreBluetooth
import CoreML


struct ContentView: View {
    // device buttons
    @State private var isAirPodsSelected = false
    @State private var isPhoneSelected = false
    @State private var isWatchSelected = false
        
    // helpers
    let nToMeasureFrequency = 100
    
    // labels
    @State private var socketStatusLabel = "N/A"
    @State private var phoneStatusLabel = "N/A"
    @State private var watchStatusLabel = "N/A"
    @State private var headphoneStatusLabel = "N/A"
    
    // networking fields
    @State private var socketIPField = "10.103.255.158"
    @State private var socketPortField = "8001"

    // managers
    @State var phoneMotionManager: CMMotionManager!
    @State var phoneQueue = OperationQueue()
    @State var headphoneMotionManager: CMHeadphoneMotionManager!
    @State var headphoneQueue = OperationQueue()

    // watch manager
    @StateObject var sessionManager = SessionManager(socketClient: nil)
    
    // phone
    @State var phoneCnt = 0
    @State var phonePrevTime: TimeInterval = NSDate().timeIntervalSince1970
    @State var phoneMeasuredFrequency: Double? = 25.0
    
    // watch
    @State var watchCnt = 0
    @State var watchPrevTime: TimeInterval = NSDate().timeIntervalSince1970
    @State var watchMeasuredFrequency: Double? = 25.0
        
    @State private var localSamplingRate: Double = 25.0 {
         didSet {
             // Update SessionManager's sampling rate
             sessionManager.watchSetFrequency = localSamplingRate
             // Send the updated sampling rate to the watch
             sessionManager.sendSamplingRate(localSamplingRate)
         }
     }
    
    init() {
    }
    
    // socket
    @State var socketClient: SocketClient?
    
    var body: some View {
        ZStack{
            Color(Color.black)
                .ignoresSafeArea()
            
            VStack() {
                Spacer()
                
                // networking stack
                VStack {
                    Text("Network")
                        .font(.largeTitle)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                    Divider()
                        .background(.white)
                        .padding([.leading, .trailing])
                    
                    VStack {
                        HStack {
                            // socket text field
                            TextField("Socket...", text: $socketIPField)
                               .padding()
                               .background(Color.white)
                               .foregroundColor(.black)
                               .cornerRadius(5)
                               .padding([.horizontal], 15)
                            
                            // create socket button
                            Button(action: {
                                createSocketConnection()
                            }) {
                                Text("Create Socket")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 15)
                            }
                            .padding([.horizontal], 5)
                            .frame(width: 140)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        
                        HStack {
                            // port field
                            TextField("Port...", text: $socketPortField)
                               .padding()
                               .background(Color.white)
                               .foregroundColor(.black)
                               .cornerRadius(5)
                               .padding([.horizontal], 15)
                            
                            // stop socket button
                            Button(action: {
                                stopSocketConnection()
                            }) {
                                Text("Stop Socket")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 15)
                            }
                            .padding([.horizontal], 15)
                            .frame(width: 140)
                            .background(Color.red)
                            .cornerRadius(10)
                        }
                        
                        // socket status label
                        HStack {
                            Label("Socket Status: ", systemImage: "")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                            Label(self.socketStatusLabel, systemImage: "")
                                .foregroundColor(.white)
                        }.padding()
                        
                        // Test model inference latency
//                        HStack {
//                            Button(action: {
//                                modelPrediction()
//                            }) {
//                                Text("Test Model")
//                                    .font(.headline)
//                                    .foregroundColor(.white)
//                                    .padding(.vertical, 15)
//                            }
//                            .padding([.horizontal], 5)
//                            .frame(width: 140)
//                            .background(Color.blue)
//                            .cornerRadius(10)
//                            Spacer()
//                            VStack {
//                                Label("Inference Latency: ", systemImage: "")
//                                    .fontWeight(.bold)
//                                    .foregroundColor(.white)
//                                Label(self.modelLatency, systemImage: "")
//                                    .fontWeight(.regular)
//                                    .foregroundColor(.white)
//                            }
//
//                        }.padding()
                        
                    }.padding()
                }
                
                VStack(alignment: .leading) {
                    Text("Sampling Rate: \(Int(localSamplingRate)) Hz")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Slider(value: $localSamplingRate, in: 10...100, step: 5)
                        .accentColor(.blue)
                        .padding(.horizontal)
                    
                    // Optionally, display the current sampling rate
                    Text("Current Sampling Rate: \(Int(localSamplingRate)) Hz")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }.padding()
                
                Spacer()
                
                Text("Devices")
                    .font(.largeTitle)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                Divider()
                    .background(.white)
                    .padding([.leading, .trailing])
                
                VStack {
                    HStack(spacing: 40.0) {
                        Spacer()
                        // airpods button
                        Button(action: {
                            self.isAirPodsSelected.toggle()
                        }) {
                            Image(systemName: "airpods.gen3")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(isAirPodsSelected ? .blue : .white)
                        }
                        // phone button
                        Button(action: {
                            self.isPhoneSelected.toggle()
                            togglePhone()
                        }) {
                            Image(systemName: "iphone.gen3")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(isPhoneSelected ? .blue : .white)
                        }
                        // watch button
                        Button(action: {
                            self.isWatchSelected.toggle()
                            toggleWatch()
                        }) {
                            Image(systemName: "applewatch")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(isWatchSelected ? .blue : .white)
                        }
                        Spacer()
                    }
                    VStack {
                        HStack {
                            Label("Phone Status:", systemImage: "")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                            Label(self.phoneStatusLabel, systemImage: "")
                                .foregroundColor(.white)
                        }
                        HStack {
                            Label("Watch Status: ", systemImage: "")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                            Label(sessionManager.watchStatusLabel, systemImage: "")
                                .foregroundColor(.white)
                        }
                        HStack {
                            Label("Headphone Status: ", systemImage: "")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                            Label(self.headphoneStatusLabel, systemImage: "")
                                .foregroundColor(.white)
                        }
                    }.padding()

                }.padding()

                Spacer()
            }
            .onAppear {
                // Load sampling rate from UserDefaults
                let savedRate = UserDefaults.standard.double(forKey: "samplingRate")
                self.localSamplingRate = savedRate > 0 ? savedRate : 25.0
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .ignoresSafeArea()
        }
    }
    
    func initData() -> MLMultiArray {
        let shape: [NSNumber] = [1, 40, 24]
        guard let data = try? MLMultiArray(shape: shape, dataType: .double) else {
            fatalError("Error creating MLMultiArray.")
        }
        let length = data.count
        for i in 0..<length {
            data[i] = 0
        }
        return data
    }
    
    func togglePhone() {
        print("Toggle Phone...")
        if self.isPhoneSelected {
            startPhoneMotion()
        } else {
            stopPhoneMotion()
        }
    }
    
    func toggleWatch() {
        print("Toggle Watch...")
        if self.isWatchSelected {
            pairWatch()
        } else {
            stopWatchMotion()
        }
    }
    
    private func updateSocketStatusLabel(status: Bool) {
        DispatchQueue.main.async {
            if status {
                self.socketStatusLabel = "Ready!"
            } else {
                self.socketStatusLabel = "Not ready..."
            }
        }
    }
    
    func createSocketConnection() {
        let ip = socketIPField as String? ?? "0.0.0.0"
        let port = UInt16(socketPortField as String? ?? "0") ?? 8000
        let deviceIdentifier = "left"
        
        print("try to connect \(ip):\(port) with device id \(deviceIdentifier)")
        socketClient = SocketClient(ip: ip, portInt: port, deviceID: deviceIdentifier) { (status) in
            self.updateSocketStatusLabel(status: status)
        }
        
        // update socket client of sessionManager
        self.sessionManager.socketClient = socketClient
    }
    
    func restartSocketConnection() {
        guard let socketClient = socketClient else {
            return
        }
        socketClient.restart() { (status) in
            self.updateSocketStatusLabel(status: status)
        }
        socketClient.send(text: "restarted")
    }
    
    func stopSocketConnection() {
        guard let socketClient = socketClient else {
            return
        }
        socketClient.stop()
    }
    
    func pairWatch() {
        print("watch status")
        print("is watch app installed: ", WCSession.default.isWatchAppInstalled)
        print("is paired: ", WCSession.default.isPaired)
        print("is reachable: ", WCSession.default.isReachable)
        
        if (WCSession.default.isReachable) {
            do {
                try WCSession.default.updateApplicationContext(["samplingRate": localSamplingRate])
                watchStatusLabel = "Connected!"
                
                // send IP address to watch
                sendIPToWatch(ip: socketIPField)
                
                // start watch motion when connected
                startWatchMotion()
            }
            catch {
                print(error)
            }
        } else {
            watchStatusLabel = "Not reachable..."
        }
    }
    
    func sendIPToWatch(ip: String) {
        if (WCSession.default.isReachable) {
            do {
                try WCSession.default.updateApplicationContext(["ipAddress": socketIPField])
            }
            catch {
                print("Error sending IP address: \(error.localizedDescription)")
                print(error)
            }
        } else {
            print("WCSession is not reachable.")
        }
    }
    
    func startWatchMotion() {
        watchCnt = 0
        // self.watchStatusLabel = "\(self.watchCnt) data / \(round(self.watchMeasuredFrequency! * 100) / 100) [Hz]"
        if (WCSession.default.isReachable) {
            do {
                try WCSession.default.updateApplicationContext(["command": "start"])
            }
            catch {
                print(error)
            }
        } else {
            watchStatusLabel = "Not reachable..."
        }
    }
    
    func stopWatchMotion() {
        watchStatusLabel = "Not recording..."
        if (WCSession.default.isReachable) {
            do {
                try WCSession.default.updateApplicationContext(["command": "stop"])
            }
            catch {
                print(error)
            }
        } else {
            watchStatusLabel = "Not reachable..."
        }
    }
    
    func startPhoneMotion() {
        phoneMotionManager = CMMotionManager()
        phoneMotionManager.deviceMotionUpdateInterval = 1.0 / localSamplingRate
        if phoneMotionManager.isDeviceMotionAvailable {
            phoneCnt = 0
            phonePrevTime = NSDate().timeIntervalSince1970
            DispatchQueue.main.async {
                self.phoneStatusLabel = "Started!"
            }
            print("phone motion manager")
            phoneMotionManager.startDeviceMotionUpdates(using: .xTrueNorthZVertical, to: phoneQueue) { (motion, error) in
                if let motion = motion {
                    let currentTime = NSDate().timeIntervalSince1970
                    
                    if let socketClient = self.socketClient {
                        if socketClient.connection.state == .ready {
                            let text = "phone:\(currentTime) \(motion.timestamp) \(motion.userAcceleration.x) \(motion.userAcceleration.y) \(motion.userAcceleration.z) \(motion.attitude.quaternion.x) \(motion.attitude.quaternion.y) \(motion.attitude.quaternion.z) \(motion.attitude.quaternion.w) \(motion.attitude.roll) \(motion.attitude.pitch) \(motion.attitude.yaw) \(motion.rotationRate.x) \(motion.rotationRate.y) \(motion.rotationRate.z)\n"
                            socketClient.send(text: text)
                        }
                    }
                    
                    self.phoneCnt += 1
                    if self.phoneCnt % self.nToMeasureFrequency == 0 {
                        let timeDiff = (currentTime - self.phonePrevTime) as Double
                        self.phonePrevTime = currentTime
                        self.phoneMeasuredFrequency = 1.0 / timeDiff * Double(self.nToMeasureFrequency)
                        DispatchQueue.main.async {
                            self.phoneStatusLabel = "\(self.phoneCnt) data / \(round(self.phoneMeasuredFrequency! * 100) / 100) [Hz]"
                        }
                    }
                } else {
                    print(error as Any)
                }
            }
        }
    }
    
    func stopPhoneMotion() {
        self.phoneStatusLabel = "Not Recording..."
        phoneMotionManager.stopDeviceMotionUpdates()
    }
    
    
    func sendSamplingRateToWatch() {
        guard WCSession.default.isReachable else {
            print("Watch is not reachable")
            sessionManager.watchStatusLabel = "Watch not reachable"
            return
        }
        
        let context: [String: Any] = ["samplingRate": localSamplingRate]
        
        do {
            try WCSession.default.updateApplicationContext(context)
            print("Sent sampling rate: \(localSamplingRate) Hz")
        } catch {
            print("Error sending sampling rate: \(error.localizedDescription)")
        }
    }
}

class SessionManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var watchData: CMDeviceMotion?
    @Published var watchStatusLabel: String = "Not connected"
    @Published var watchCnt: Int = 0
    @Published var connectionError: String?

    let nToMeasureFrequency = 100
    var watchPrevTime: TimeInterval = NSDate().timeIntervalSince1970
    var watchSetFrequency: Double? = 25.0
    var watchMeasuredFrequency: Double? = 25.0
    var socketClient: SocketClient?
    
    init(socketClient: SocketClient?) {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        self.socketClient = socketClient
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let e = error {
            print("Completed activation with error: \(e.localizedDescription)")
        } else {
            print("Completed activation!")
        }
    }
    
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any] = [:]) {
        if let motionData = message["motionData"] as? String {
            //self.watchData = motionData
            if let socketClient = self.socketClient {
                if socketClient.connection.state == .ready {
                    let text = "watch:" + motionData
                    socketClient.send(text: text)
                }
            }
            watchCnt += 1
            if watchCnt % nToMeasureFrequency == 0 {
                let currentTime = NSDate().timeIntervalSince1970
                let timeDiff = (currentTime - self.watchPrevTime) as Double
                watchPrevTime = currentTime
                watchMeasuredFrequency = 1.0 / timeDiff * Double(nToMeasureFrequency)
                DispatchQueue.main.async {
                    self.watchStatusLabel = "\(self.watchCnt) data / \(round(self.watchMeasuredFrequency! * 100) / 100) [Hz]"
                }
            }
        }
    }
    
    // Handle incoming application contexts
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            if let frequency = applicationContext["samplingRate"] as? Double {
                self.watchSetFrequency = frequency
                // Update the sampling rate in your MotionManager or relevant component
                // For example:
                // MotionManager.shared.setSamplingRate(value: frequency)
                print("Received Sampling Rate: \(frequency) Hz")
            }
            
            // Handle other keys if necessary
        }
    }
    
    // Handle incoming messages
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if let request = message["requestSamplingRate"] as? Bool, request == true {
            replyHandler(["samplingRate": self.watchSetFrequency ?? 25.0])
        }
        
        // Handle other messages
    }
    
    // Add a method to send sampling rate to the Watch
    func sendSamplingRate(_ rate: Double) {
        guard WCSession.default.isReachable else {
            print("Watch is not reachable")
            DispatchQueue.main.async {
                self.connectionError = "Watch is not reachable"
            }
            return
        }
        
        let context: [String: Any] = ["samplingRate": rate]
        
        do {
            try WCSession.default.updateApplicationContext(context)
            print("Sent sampling rate: \(rate) Hz")
            UserDefaults.standard.set(rate, forKey: "samplingRate")
        } catch {
            print("Error sending sampling rate: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.connectionError = "Failed to send sampling rate"
            }
        }
    }
}

#Preview {
    ContentView()
}
