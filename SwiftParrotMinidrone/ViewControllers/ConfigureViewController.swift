//
//  ConfigureViewController.swift
//  SwiftParrotMinidrone
//
//  Created by ST14580 on 2017/11/06.
//  Copyright © 2017年 ST14580. All rights reserved.
//

import UIKit

class ConfigureViewController: UIViewController {

    @IBOutlet weak var modeSegmentedControl: UISegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        modeSegmentedControl.selectedSegmentIndex = Configure.mode.rawValue
    }

    @IBAction func modeValueChanged(_ sender: UISegmentedControl) {
        if let mode = Configure.Mode(rawValue: modeSegmentedControl.selectedSegmentIndex) {
            Configure.mode = mode
        }
    }
}
