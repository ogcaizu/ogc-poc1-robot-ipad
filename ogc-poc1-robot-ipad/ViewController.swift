//
//  ViewController.swift
//  ogc-poc1-robot-ipad
//
//  Created by Nobuyuki Matsui on 2018/10/15.
//  Copyright © 2018年 Nobuyuki Matsui. All rights reserved.
//

import UIKit
import CocoaMQTT
import AVFoundation

class Messages {
    static let connectionError = "接続失敗"
    static var waiting: String {
        return "誘導ロボット\n\(UserDefaults.standard.string(forKey: "location") ?? "1F")"
    }
    static let guiding = "ご案内中"
    static let suspending = "目的地に\n到着しました"
    static let returning = "帰還中"
}

enum Command: String {
    case state
}

enum State: String {
    case Waiting
    case Guiding
    case Suspending
    case Returning
}

class ViewController: UIViewController {
    var mqtt: CocoaMQTT?
    let talker = AVSpeechSynthesizer()
    
    let re = try! Regex("([\\w_-]+)@([\\w-_]+)\\|([\\w-_]+)")

    var host: String {
        return UserDefaults.standard.string(forKey: "host") ?? ""
    }
    var port: UInt16 {
        return UInt16(UserDefaults.standard.integer(forKey: "port"))
    }
    var enableSSL: Bool {
        return UserDefaults.standard.bool(forKey: "enableSSL")
    }
    var username: String {
        return UserDefaults.standard.string(forKey: "username") ?? ""
    }
    var password: String {
        return UserDefaults.standard.string(forKey: "password") ?? ""
    }
    var cmdTopic: String {
        return "\(UserDefaults.standard.string(forKey: "basetopic") ?? "")/cmd"
    }
    var cmdExeTopic: String {
        return "\(UserDefaults.standard.string(forKey: "basetopic") ?? "")/cmdexe"
    }
    var guidingTalk: String {
        return UserDefaults.standard.string(forKey: "guiding") ?? "目的地までご案内いたします。私に付いてきてください。"
    }
    var suspendingTalk: String {
        return UserDefaults.standard.string(forKey: "suspending") ?? "目的地に到着しました。押しボタンを押して、おはいりください。"
    }
    
    @IBOutlet weak var label: UILabel!
    
    func registerSettingsBundle() {
        let appDefaults = [String:AnyObject]()
        UserDefaults.standard.register(defaults: appDefaults)
        UserDefaults.standard.synchronize()
    }
    
    func setupMQTT() {
        print("setup MQTT, host=\(host), port=\(port), enableSSL=\(enableSSL), username=\(username), password=\(password)")
        let clientID = "CocoaMQTT-ogc-poc1-robot-ipad-" + String(ProcessInfo().processIdentifier)
        mqtt = CocoaMQTT(clientID: clientID, host: host, port: port)
        mqtt!.username = username
        mqtt!.password = password
        mqtt!.keepAlive = 60
        if enableSSL {
            mqtt!.enableSSL = true
            mqtt!.allowUntrustCACertificate = true
        } else {
            mqtt!.enableSSL = false
        }
        mqtt!.delegate = self
        let connected = mqtt!.connect()
        if !connected {
            label.text = Messages.connectionError
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainView = self
        registerSettingsBundle()
        setupMQTT()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension ViewController: CocoaMQTTDelegate {
    func execPayload(_ payload: String) -> (String, Bool) {
        var result = "invalid message format, message=\(payload)"
        var publishable = false
        if let match = re.firstMatch(payload) {
            if let deviceID = match.groups[0], let cmd = match.groups[1], let state = match.groups[2] {
                if let c = Command(rawValue: cmd) {
                    switch c {
                    case .state:
                        if let s = State(rawValue: state) {
                            switch s {
                            case .Waiting:
                                label.text = Messages.waiting
                                result = "executed Waiting"
                            case .Guiding:
                                label.text = Messages.guiding
                                let utterance = AVSpeechUtterance(string:guidingTalk)
                                talker.speak(utterance)
                                result = "executed Guiding"
                            case .Suspending:
                                label.text = Messages.suspending
                                let utterance = AVSpeechUtterance(string:suspendingTalk)
                                talker.speak(utterance)
                                result = "executed Suspending"
                            case .Returning:
                                label.text = Messages.returning
                                result = "executed Returning"
                            }
                        } else {
                            result = "unknown state, state=\(state), message=\(payload)"
                        }
                    }
                } else {
                    result = "unknown cmd, cmd=\(cmd), message=\(payload)"
                }
                publishable = true
                result = "\(deviceID)@\(cmd)|\(result)"
            }
        }
        return (result, publishable)
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        print("mqtt didReceive trust\(trust)")
        completionHandler(true)
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        print("mqtt didConnectAck ack=\(ack.rawValue)")
        if ack == .accept {
            label.text = Messages.waiting
            mqtt.subscribe(cmdTopic, qos: CocoaMQTTQOS.qos0)
        } else {
            label.text = Messages.connectionError
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16 ) {
        print("mqtt didReceiveMessage message=\(message.string ?? "empty message") id=\(id)")
        if let payload = message.string {
            let (result, publishable) = execPayload(payload)
            print("execPayload result=\(result)")
            if publishable {
                mqtt.publish(cmdExeTopic, withString: result, qos: CocoaMQTTQOS.qos0)
            }
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        print("mqtt didPublishMessage message=\(message.string!) id=\(id)")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        print("mqtt didPublishAck id=\(id)")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopic topic: String) {
        print("mqtt didSubscribeTopic topic=\(topic)")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopic topic: String) {
        print("mqtt didUnsubscribeTopic topic=\(topic)")
    }
    
    func mqttDidPing(_ mqtt: CocoaMQTT) {
        print("mqttDidPing")
    }
    
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        print("mqttDidReceivePong")
    }
    
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        print("mqttDidDisconnect withError err=\(String(describing: err))")
        if err != nil {
            label.text = Messages.connectionError
        }
    }
}
