//
//  DeviceListViewController.swift
//  SwiftParrotMinidrone
//
//  Created by Groovelab on 2017/11/03.
//  Copyright © 2017 Groovelab. All rights reserved.
//

import UIKit

class DeviceListViewController: UIViewController {
    private let MINIDRONE_SEGUE = "miniDroneSegue"
    private let MINIDRONE_IMAGE_SEGUE = "miniDroneImageSegue"

    @IBOutlet weak var tableView: UITableView!

    private let droneDiscoverer = DroneDiscoverer()
    private var dataSource: [Any] = []
    private var selectedService: ARService?
    
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
            let viewController: MiniDroneViewController = (segue.destination as? MiniDroneViewController)!
            viewController.service = arService
        } else if segue.identifier == MINIDRONE_IMAGE_SEGUE {
            let viewController: MiniDroneImageViewController = (segue.destination as? MiniDroneImageViewController)!
            viewController.service = arService
        }
    }
    
    private func registerNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.enteredBackground),
                                               name: .UIApplicationDidEnterBackground,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.enterForeground),
                                               name: .UIApplicationWillEnterForeground,
                                               object: nil)
    }
    
    private func unregisterNotifications() {
        NotificationCenter.default.removeObserver(self,
                                                  name: .UIApplicationDidEnterBackground,
                                                  object: nil)
        NotificationCenter.default.removeObserver(self,
                                                  name: .UIApplicationWillEnterForeground,
                                                  object: nil)
    }
    
    @objc private func enterForeground(notification: Notification?) {
        droneDiscoverer.startDiscovering()
    }

    @objc private func enteredBackground(notification: Notification?) {
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
            if arService.network_type == ARDISCOVERY_NETWORK_TYPE_NET {
                let alert = UIAlertController(title:"Confirm", message: "Select type", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Video", style: .default, handler: {
                    (action: UIAlertAction!) in
                    self.performSegue(withIdentifier: self.MINIDRONE_SEGUE, sender: self)
                }))
                alert.addAction(UIAlertAction(title: "Image", style: .default, handler: {
                    (action: UIAlertAction!) in
                    self.performSegue(withIdentifier: self.MINIDRONE_IMAGE_SEGUE, sender: self)
                }))
                self.present(alert, animated: true, completion: nil)
            } else {
                performSegue(withIdentifier: MINIDRONE_SEGUE, sender: self)
            }
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
