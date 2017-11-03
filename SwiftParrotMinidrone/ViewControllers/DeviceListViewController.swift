//
//  DeviceListViewController.swift
//  SwiftParrotMinidrone
//
//  Created by Groovelab on 2017/11/03.
//  Copyright © 2017 Groovelab. All rights reserved.
//

import UIKit

class DeviceListViewController: UIViewController {
    let MINIDRONE_SEGUE = "miniDroneSegue"
    
    @IBOutlet weak var tableView: UITableView!

    let droneDiscoverer = DroneDiscoverer()
    var dataSource: [Any] = []
    var selectedService: ARService?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        droneDiscoverer.delegate = self;
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        registerNotifications()
        droneDiscoverer.startDiscovering()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        unregisterNotifications()
        droneDiscoverer.stopDiscovering()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let arService = selectedService else {
            return
        }

        if segue.identifier == MINIDRONE_SEGUE {
            let miniDroneViewController: MiniDroneViewController = (segue.destination as? MiniDroneViewController)!
            miniDroneViewController.service = arService
        }
    }
    
    func registerNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.enteredBackground),
                                               name: .UIApplicationDidEnterBackground,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.enterForeground),
                                               name: .UIApplicationWillEnterForeground,
                                               object: nil)
    }
    
    func unregisterNotifications() {
        NotificationCenter.default.removeObserver(self,
                                                  name: .UIApplicationDidEnterBackground,
                                                  object: nil)
        NotificationCenter.default.removeObserver(self,
                                                  name: .UIApplicationWillEnterForeground,
                                                  object: nil)
    }
    
    @objc func enterForeground(notification: NSNotification) {
        droneDiscoverer.startDiscovering()
    }

    @objc func enteredBackground(notification: NSNotification) {
        droneDiscoverer.stopDiscovering()
    }
}

extension DeviceListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")

        if let arService = dataSource[indexPath.row] as? ARService {
            let networkType: String!
            switch arService.network_type {
            case ARDISCOVERY_NETWORK_TYPE_NET:
                networkType = "IP (e.g. wifi)"
            case ARDISCOVERY_NETWORK_TYPE_BLE:
                networkType = "BLE"
            case ARDISCOVERY_NETWORK_TYPE_USBMUX:
                networkType = "libmux over USB"
            default:
                networkType = "Unknown"
            }
            
            cell.textLabel?.text = String(format: "%@ on %@ network", arService.name, networkType)
        }

        return cell
    }
}

extension DeviceListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let arService = dataSource[indexPath.row] as? ARService else {
            return
        }

        switch arService.product {
        case ARDISCOVERY_PRODUCT_MINIDRONE,
             ARDISCOVERY_PRODUCT_MINIDRONE_EVO_BRICK,
             ARDISCOVERY_PRODUCT_MINIDRONE_EVO_LIGHT,
             ARDISCOVERY_PRODUCT_MINIDRONE_DELOS3:
            selectedService = arService
            performSegue(withIdentifier: MINIDRONE_SEGUE, sender: self)
        default:
            print("not handled")
            break;
        }
    }
}

extension DeviceListViewController: DroneDiscovererDelegate {
    func droneDiscoverer(_ droneDiscoverer: DroneDiscoverer!, didUpdateDronesList dronesList: [Any]!) {
        dataSource = dronesList
        tableView.reloadData()
    }
}
