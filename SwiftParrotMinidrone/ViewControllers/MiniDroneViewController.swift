//
//  MiniDroneViewController.swift
//  SwiftParrotMinidrone
//
//  Created by Groovelab on 2017/11/03.
//  Copyright © 2017 Groovelab. All rights reserved.
//

import UIKit

class MiniDroneViewController: UIViewController {
    private let CONFIGURE_SEGUE = "configureSegue"
    private let stateSem: DispatchSemaphore = DispatchSemaphore(value: 0)

    private var connectionAlertController: UIAlertController?
    private var downloadAlertController: UIAlertController?
    private var downloadProgressView: UIProgressView?
    private var miniDrone: MiniDrone?
    private var nbMaxDownload = 0
    private var currentDownloadIndex = 0 // from 1 to nbMaxDownload
    private var isConfiguretion = false
    private var mode = Configure.Mode.mode1

    var service: ARService?

//    @IBOutlet weak var videoView: H264VideoView!
//    @IBOutlet weak var videoView: H264VideoView2!
    
    @IBOutlet weak var videoView: H264ImageView!
    
    @IBOutlet weak var batteryLabel: UILabel!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var takeOffLandBt: UIButton!
    @IBOutlet weak var downloadMediasBt: UIButton!

    @IBOutlet weak var yawLabel: UILabel!
    @IBOutlet weak var upButton: UIButton!
    @IBOutlet weak var downButton: UIButton!

    @IBOutlet weak var rollLabel: UILabel!
    @IBOutlet weak var forwardButton: UIButton!
    @IBOutlet weak var backButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        miniDrone = MiniDrone(service: service)
        miniDrone?.delegate = self
        miniDrone?.connect()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        mode = Configure.mode
        switch mode {
        case .mode1:
            yawLabel.text = "yaw"
            upButton.setTitle("up", for: .normal)
            downButton.setTitle("down", for: .normal)
            rollLabel.text = "roll"
            forwardButton.setTitle("forward", for: .normal)
            backButton.setTitle("back", for: .normal)
        case .mode2:
            yawLabel.text = "roll"
            upButton.setTitle("forward", for: .normal)
            downButton.setTitle("back", for: .normal)
            rollLabel.text = "yaw"
            forwardButton.setTitle("up", for: .normal)
            backButton.setTitle("down", for: .normal)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if miniDrone?.connectionState() != ARCONTROLLER_DEVICE_STATE_RUNNING {
            connectionAlertController = UIAlertController(title: service?.name ?? "", message: "Connecting ...", preferredStyle: .alert)
            if let alertController = connectionAlertController {
                alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { _ in
                    alertController.dismiss(animated: true, completion: nil)
                    self.navigationController?.popViewController(animated: true)
                }))
                present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if isConfiguretion {
            isConfiguretion = false
            return
        }

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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == CONFIGURE_SEGUE {
            isConfiguretion = true
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
        switch mode {
        case .mode1:
            miniDrone?.setGaz(50)
        case .mode2:
            miniDrone?.setFlag(1)
            miniDrone?.setPitch(50)
        }
    }
    
    @IBAction func gazDownTouchDown(_ sender: UIButton) {
        switch mode {
        case .mode1:
            miniDrone?.setGaz(-50)
        case .mode2:
            miniDrone?.setFlag(1)
            miniDrone?.setPitch(-50)
        }

    }

    @IBAction func gazUpTouchUp(_ sender: UIButton) {
        switch mode {
        case .mode1:
            miniDrone?.setGaz(0)
        case .mode2:
            miniDrone?.setFlag(0)
            miniDrone?.setPitch(0)
        }
    }

    @IBAction func gazDownTouchUp(_ sender: UIButton) {
        switch mode {
        case .mode1:
            miniDrone?.setGaz(0)
        case .mode2:
            miniDrone?.setFlag(0)
            miniDrone?.setPitch(0)
        }
    }

    @IBAction func yawLeftTouchDown(_ sender: UIButton) {
        switch mode {
        case .mode1:
            miniDrone?.setYaw(-50)
        case .mode2:
            miniDrone?.setFlag(1)
            miniDrone?.setRoll(-50)
        }
    }
    
    @IBAction func yawRightTouchDown(_ sender: UIButton) {
        switch mode {
        case .mode1:
            miniDrone?.setYaw(50)
        case .mode2:
            miniDrone?.setFlag(1)
            miniDrone?.setRoll(50)
        }
    }

    @IBAction func yawLeftTouchUp(_ sender: UIButton) {
        switch mode {
        case .mode1:
            miniDrone?.setYaw(0)
        case .mode2:
            miniDrone?.setFlag(0)
            miniDrone?.setRoll(0)
        }
    }

    @IBAction func yawRightTouchUp(_ sender: UIButton) {
        switch mode {
        case .mode1:
            miniDrone?.setYaw(0)
        case .mode2:
            miniDrone?.setFlag(0)
            miniDrone?.setRoll(0)
        }
    }
    
    @IBAction func rollLeftTouchDown(_ sender: UIButton) {
        switch mode {
        case .mode1:
            miniDrone?.setFlag(1)
            miniDrone?.setRoll(-50)
        case .mode2:
            miniDrone?.setYaw(-50)
        }
    }

    @IBAction func rollRightTouchDown(_ sender: UIButton) {
        switch mode {
        case .mode1:
            miniDrone?.setFlag(1)
            miniDrone?.setRoll(50)
        case .mode2:
            miniDrone?.setYaw(50)
        }
    }
    
    @IBAction func rollLeftTouchUp(_ sender: UIButton) {
        switch mode {
        case .mode1:
            miniDrone?.setFlag(0)
            miniDrone?.setRoll(0)
        case .mode2:
            miniDrone?.setYaw(0)
        }
    }

    @IBAction func rollRightTouchUp(_ sender: UIButton) {
        switch mode {
        case .mode1:
            miniDrone?.setFlag(0)
            miniDrone?.setRoll(0)
        case .mode2:
            miniDrone?.setYaw(0)
        }
    }

    @IBAction func pitchForwardTouchDown(_ sender: UIButton) {
        switch mode {
        case .mode1:
            miniDrone?.setFlag(1)
            miniDrone?.setPitch(50)
        case .mode2:
            miniDrone?.setGaz(50)
        }
    }

    @IBAction func pitchBackTouchDown(_ sender: UIButton) {
        switch mode {
        case .mode1:
            miniDrone?.setFlag(1)
            miniDrone?.setPitch(-50)
        case .mode2:
            miniDrone?.setGaz(-50)
        }
    }

    @IBAction func pitchForwardTouchUp(_ sender: UIButton) {
        switch mode {
        case .mode1:
            miniDrone?.setFlag(0)
            miniDrone?.setPitch(0)
        case .mode2:
            miniDrone?.setGaz(0)
        }
    }

    @IBAction func pitchBackTouchUp(_ sender: UIButton) {
        switch mode {
        case .mode1:
            miniDrone?.setFlag(0)
            miniDrone?.setPitch(0)
        case .mode2:
            miniDrone?.setGaz(0)
        }
    }
    
    @IBAction func configureClicked(_ sender: UIButton) {
        performSegue(withIdentifier: CONFIGURE_SEGUE, sender: self)
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
            if let alertController = connectionAlertController {
                alertController.dismiss(animated: true, completion: {
                    self.navigationController?.popViewController(animated: true)
                })
            } else {
                navigationController?.popViewController(animated: true)
            }
        default:
            break
        }
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

    func miniDrone(_ miniDrone: MiniDrone!, batteryDidChange batteryPercentage: Int32) {
        batteryLabel.text = String(format: "%d%%", batteryPercentage)
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
    
    func miniDrone(_ miniDrone: MiniDrone!, speedChanged speedX: Float, y speedY: Float, z speedZ: Float) {
        //  speedX is front direction
        //  speedY is side direction
        //  speedX is vertical direction (rising is negative value)
        print("speed : ", speedX , speedY, speedZ)
        speedLabel.text = String(format: "x:%@%.1fm/s y:%@%.1fm/s z:%@%.1fm/s",
                                 speedX < 0 ? "" : "+", (speedX * 10).rounded(.toNearestOrAwayFromZero) / 10,
                                 speedY < 0 ? "" : "+", (speedY * 10).rounded(.toNearestOrAwayFromZero) / 10,
                                 speedZ < 0 ? "" : "+", (speedZ * 10).rounded(.toNearestOrAwayFromZero) / 10)
    }
    
    func miniDrone(_ miniDrone: MiniDrone!, altitude alt: Float) {
        print("altitude : ", alt)
    }
    
    func miniDrone(_ miniDrone: MiniDrone!, quaternionChanged qW: Float, x qX: Float, y qY: Float, z qZ: Float) {
        print("quaternion : ", qW , qX, qY, qZ)
    }
}
