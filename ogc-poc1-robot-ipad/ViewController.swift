//
//  ViewController.swift
//  ogc-poc1-robot-ipad
//
//  Created by Nobuyuki Matsui on 2018/10/15.
//  Copyright © 2018年 Nobuyuki Matsui. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var host: String {
        return UserDefaults.standard.string(forKey: "host") ?? ""
    }
    var port: Int {
        return UserDefaults.standard.integer(forKey: "port")
    }
    var username: String {
        return UserDefaults.standard.string(forKey: "username") ?? ""
    }
    var password: String {
        return UserDefaults.standard.string(forKey: "password") ?? ""
    }
    var basetopic: String {
        return UserDefaults.standard.string(forKey: "basetopic") ?? ""
    }
    
    @IBOutlet weak var label: UILabel!
    
    func registerSettingsBundle(){
        let appDefaults = [String:AnyObject]()
        UserDefaults.standard.register(defaults: appDefaults)
        UserDefaults.standard.synchronize()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        registerSettingsBundle()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

