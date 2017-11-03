//
//  MiniDroneViewController.swift
//  SwiftParrotMinidrone
//
//  Created by Groovelab on 2017/11/03.
//  Copyright © 2017 Groovelab. All rights reserved.
//

import UIKit

class MiniDroneViewController: UIViewController {

    let stateSem: DispatchSemaphore = DispatchSemaphore(value: 0)

    var connectionAlertController: UIAlertController?
    var downloadAlertController: UIAlertController?
    var downloadProgressView: UIProgressView?
    var miniDrone: MiniDrone?
    var service: ARService?
    var nbMaxDownload = 0
    var currentDownloadIndex = 0 // from 1 to nbMaxDownload

    @IBOutlet weak var videoView: H264VideoView!
    @IBOutlet weak var batteryLabel: UILabel!
    @IBOutlet weak var takeOffLandBt: UIButton!
    @IBOutlet weak var downloadMediasBt: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        miniDrone = MiniDrone(service: service)
        miniDrone?.delegate = self
        miniDrone?.connect()
        
        connectionAlertController = UIAlertController(title: service?.name ?? "", message: "Connecting ...", preferredStyle: .alert)
        connectionAlertController?.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            self.connectionAlertController?.dismiss(animated: true, completion: nil)
        }))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if miniDrone?.connectionState() != ARCONTROLLER_DEVICE_STATE_RUNNING, let connectionAlertController = connectionAlertController {
            present(connectionAlertController, animated: true, completion: nil)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        connectionAlertController?.dismiss(animated: true, completion: nil)
        connectionAlertController = UIAlertController(title: service?.name ?? "", message: "Disconnecting ...", preferredStyle: .alert)
        if let connectionAlertController = connectionAlertController {
            present(connectionAlertController, animated: true, completion: nil)
        }

        // in background, disconnect from the drone
        DispatchQueue.global(qos: .default).async {
            self.miniDrone?.disconnect()

            // wait for the disconnection to appear
            let _ = self.stateSem.wait(timeout: .distantFuture)
            self.miniDrone = nil
            
            // dismiss the alert view in main thread
            DispatchQueue.main.async {
                self.connectionAlertController?.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    @IBAction func emergencyClicked(_ sender: UIButton) {
        miniDrone?.emergency()
    }
    
    @IBAction func takeOffLandClicked(_ sender: UIButton) {
        if let miniDrone = miniDrone {
            switch miniDrone.flyingState() {
            case ARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_LANDED:
                miniDrone.takeOff()
            case ARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_FLYING,
                 ARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_HOVERING:
                miniDrone.land()
            default:
                break
            }
        }
    }
    
    @IBAction func takePictureClicked(_ sender: UIButton) {
        miniDrone?.takePicture()
    }
    
    @IBAction func downloadMediasClicked(_ sender: UIButton) {
        downloadAlertController?.dismiss(animated: true, completion: nil)
        
        downloadAlertController = UIAlertController(title: "Download",
                                                    message: "Fetching medias",
                                                    preferredStyle: .alert)
        if let downloadAlertController = downloadAlertController {
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { action in
                self.miniDrone?.cancelDownloadMedias()
            }
            downloadAlertController.addAction(cancelAction)
            
            let customVC = UIViewController()
            let spinner = UIActivityIndicatorView(activityIndicatorStyle: .gray)
            spinner.startAnimating()
            customVC.view.addSubview(spinner)
            customVC.view.addConstraint(NSLayoutConstraint(item: spinner,
                                                           attribute: .centerX,
                                                           relatedBy: .equal,
                                                           toItem: customVC.view,
                                                           attribute: .centerX,
                                                           multiplier: 1,
                                                           constant: 0))
            customVC.view.addConstraint(NSLayoutConstraint(item: spinner,
                                                           attribute: .bottom,
                                                           relatedBy: .equal,
                                                           toItem: customVC.bottomLayoutGuide,
                                                           attribute: .top,
                                                           multiplier: 1,
                                                           constant: -20))
            
            downloadAlertController.setValue(customVC, forKey: "contentViewController")
            present(downloadAlertController, animated: true, completion: nil)
            
            miniDrone?.downloadMedias()
        }
    }
    
    @IBAction func gazUpTouchDown(_ sender: UIButton) {
        miniDrone?.setGaz(50)
    }
    
    @IBAction func gazDownTouchDown(_ sender: UIButton) {
        miniDrone?.setGaz(UInt8(-50))
    }

    @IBAction func gazUpTouchUp(_ sender: UIButton) {
        miniDrone?.setGaz(0)
    }

    @IBAction func gazDownTouchUp(_ sender: UIButton) {
        miniDrone?.setGaz(0)
    }

    @IBAction func yawLeftTouchDown(_ sender: UIButton) {
        miniDrone?.setYaw(UInt8(-50))
    }
    
    @IBAction func yawRightTouchDown(_ sender: UIButton) {
        miniDrone?.setYaw(50)
    }

    @IBAction func yawLeftTouchUp(_ sender: UIButton) {
        miniDrone?.setYaw(0)
    }

    @IBAction func yawRightTouchUp(_ sender: UIButton) {
        miniDrone?.setYaw(0)
    }
    
    @IBAction func rollLeftTouchDown(_ sender: UIButton) {
        miniDrone?.setFlag(1)
        miniDrone?.setRoll(UInt8(-50))
    }

    @IBAction func rollRightTouchDown(_ sender: UIButton) {
        miniDrone?.setFlag(1)
        miniDrone?.setRoll(50)
    }
    
    @IBAction func rollLeftTouchUp(_ sender: UIButton) {
        miniDrone?.setFlag(0)
        miniDrone?.setRoll(0)
    }

    @IBAction func rollRightTouchUp(_ sender: UIButton) {
        miniDrone?.setFlag(0)
        miniDrone?.setRoll(0)
    }

    @IBAction func pitchForwardTouchDown(_ sender: UIButton) {
        miniDrone?.setFlag(1)
        miniDrone?.setRoll(50)
    }

    @IBAction func pitchBackTouchDown(_ sender: UIButton) {
        miniDrone?.setFlag(1)
        miniDrone?.setRoll(UInt8(-50))
    }

    @IBAction func pitchForwardTouchUp(_ sender: UIButton) {
        miniDrone?.setFlag(0)
        miniDrone?.setPitch(0)
    }

    @IBAction func pitchBackTouchUp(_ sender: UIButton) {
        miniDrone?.setFlag(0)
        miniDrone?.setPitch(0)
    }
}

extension MiniDroneViewController: MiniDroneDelegate {
    func miniDrone(_ miniDrone: MiniDrone!, connectionDidChange state: eARCONTROLLER_DEVICE_STATE) {
        switch state {
        case ARCONTROLLER_DEVICE_STATE_RUNNING:
            connectionAlertController?.dismiss(animated: true, completion: nil)
        case ARCONTROLLER_DEVICE_STATE_STOPPED:
            stateSem.signal()
            
            // Go back
            navigationController?.popViewController(animated: true)
        default:
            break
        }
    }

    func miniDrone(_ miniDrone: MiniDrone!, batteryDidChange batteryPercentage: Int32) {
        batteryLabel.text = String(format: "%d%%", batteryPercentage)
    }
    
    func miniDrone(_ miniDrone: MiniDrone!, flyingStateDidChange state: eARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE) {
        switch state {
        case ARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_LANDED:
            takeOffLandBt.setTitle("Take off", for: .normal)
            takeOffLandBt.isEnabled = true
            downloadMediasBt.isEnabled = true
        case ARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_FLYING,
             ARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_HOVERING:
            takeOffLandBt.setTitle("Land", for: .normal)
            takeOffLandBt.isEnabled = true
            downloadMediasBt.isEnabled = false
        default:
            takeOffLandBt.isEnabled = false
            downloadMediasBt.isEnabled = false
        }
    }
    
    func miniDrone(_ miniDrone: MiniDrone!, configureDecoder codec: ARCONTROLLER_Stream_Codec_t) -> Bool {
        return videoView.configureDecoder(codec)
    }
    
    func miniDrone(_ miniDrone: MiniDrone!, didReceive frame: UnsafeMutablePointer<ARCONTROLLER_Frame_t>!) -> Bool {
        return videoView.displayFrame(frame)
    }

    func miniDrone(_ miniDrone: MiniDrone!, didFoundMatchingMedias nbMedias: UInt) {
        nbMaxDownload = Int(nbMedias)
        currentDownloadIndex = 1
        
        if nbMedias > 0 {
            downloadAlertController?.message = "Downloading medias"
            
            let customVC = UIViewController()
            downloadProgressView = UIProgressView(progressViewStyle: .default)
            if let downloadProgressView = downloadProgressView {
                downloadProgressView.progress = 0
                customVC.view.addSubview(downloadProgressView)
                customVC.view.addConstraint(NSLayoutConstraint(item: downloadProgressView,
                                                               attribute: .centerX,
                                                               relatedBy: .equal,
                                                               toItem: customVC.view,
                                                               attribute: .centerX,
                                                               multiplier: 1,
                                                               constant: 0))
                customVC.view.addConstraint(NSLayoutConstraint(item: downloadProgressView,
                                                               attribute: .bottom,
                                                               relatedBy: .equal,
                                                               toItem: customVC.bottomLayoutGuide,
                                                               attribute: .top,
                                                               multiplier: 1,
                                                               constant: -20))
                
                downloadAlertController?.setValue(customVC, forKey: "contentViewController")
            }
        } else {
            downloadAlertController?.dismiss(animated: true, completion: {
                self.downloadProgressView = nil
                self.downloadAlertController = nil
            })
        }
    }
    
    func miniDrone(_ miniDrone: MiniDrone!, media mediaName: String!, downloadDidProgress progress: Int32) {
        let completedProgress = Float(currentDownloadIndex - 1) / Float(nbMaxDownload)
        let currentProgress = Float(progress) / 100 / Float(nbMaxDownload)
        downloadProgressView?.progress = completedProgress + currentProgress
    }

    func miniDrone(_ miniDrone: MiniDrone!, mediaDownloadDidFinish mediaName: String!) {
        currentDownloadIndex += 1
        
        if currentDownloadIndex > nbMaxDownload {
            downloadAlertController?.dismiss(animated: true, completion: {
                self.downloadProgressView = nil
                self.downloadAlertController = nil
            })
        }
    }
}
