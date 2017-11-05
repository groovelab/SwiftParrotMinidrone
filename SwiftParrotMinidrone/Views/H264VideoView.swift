//
//  H264VideoView.swift
//  SwiftParrotMinidrone
//
//  Created by Groovelab on 2017/11/04.
//  Copyright © 2017 Groovelab. All rights reserved.
//

import UIKit
import AVKit

class H264VideoView: UIView {
    private var videoLayer: AVSampleBufferDisplayLayer?
    private var formatDesc: CMVideoFormatDescription?
    private var spsSize = 0
    private var ppsSize = 0
    private var canDisplayVideo = false
    private var lastDecodeHasFailed = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        customInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        customInit()
    }
    
    private func customInit() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.enteredBackground),
                                               name: .UIApplicationDidEnterBackground,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.enterForeground),
                                               name: .UIApplicationWillEnterForeground,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.decodingDidFail),
                                               name: .AVSampleBufferDisplayLayerFailedToDecode,
                                               object: nil)
        canDisplayVideo = true
        
        // create CVSampleBufferDisplayLayer and add it to the view
        videoLayer = AVSampleBufferDisplayLayer()
        if let videoLayer = videoLayer {
            videoLayer.frame = frame
            videoLayer.bounds = bounds
            videoLayer.videoGravity = AVLayerVideoGravity.resizeAspect
            videoLayer.backgroundColor = UIColor.black.cgColor
            layer.addSublayer(videoLayer)
        }
        backgroundColor = UIColor.black
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidEnterBackground, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIApplicationWillEnterForeground, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVSampleBufferDisplayLayerFailedToDecode, object: nil)
    }
    
    override func layoutSubviews() {
        videoLayer?.frame = bounds
    }
    
    func configureDecoder(_ codec: ARCONTROLLER_Stream_Codec_t) -> Bool {
        var success = false

        if codec.type == ARCONTROLLER_STREAM_CODEC_TYPE_H264 {
            lastDecodeHasFailed = false
            if canDisplayVideo {
                let props: [UnsafePointer<UInt8>] = [
                    UnsafePointer<UInt8>(codec.parameters.h264parameters.spsBuffer) + 4,
                    UnsafePointer<UInt8>(codec.parameters.h264parameters.ppsBuffer) + 4
                ]
                let sizes: [Int]  = [
                    Int(codec.parameters.h264parameters.spsSize - 4),
                    Int(codec.parameters.h264parameters.ppsSize - 4)
                ]
                let osstatus = CMVideoFormatDescriptionCreateFromH264ParameterSets(nil, 2, props, sizes, 4, &formatDesc)
                if (osstatus != kCMBlockBufferNoErr) {
                    let error = NSError(domain: NSOSStatusErrorDomain, code: Int(osstatus), userInfo: nil)
                    print("Error creating the format description = ", error.description)
                    cleanFormatDesc()
                } else {
                    success = false
                }
            }
        }
        
        return success
    }
    
    func displayFrame(_ frame: UnsafeMutablePointer<ARCONTROLLER_Frame_t>!) -> Bool {
        var success = !lastDecodeHasFailed
        if success && canDisplayVideo {
            var blockBuffer: CMBlockBuffer?
            //CMSampleTimingInfo timing = kCMTimingInfoInvalid;
            var sampleBuffer: CMSampleBuffer?
            
            // on error, flush the video layer and wait for the next iFrame
            if videoLayer == nil || videoLayer?.status == AVQueuedSampleBufferRenderingStatus.failed {
//                ARSAL_PRINT(ARSAL_PRINT_ERROR, "PilotingViewController", "Video layer status is failed : flush and wait for next iFrame");
                print(ARSAL_PRINT_ERROR, "PilotingViewController", "Video layer status is failed : flush and wait for next iFrame")
                cleanFormatDesc()
                success = false
            }
            
            if success {
                let osstatus  = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, frame.pointee.data, Int(frame.pointee.used),
                                                                   kCFAllocatorNull, nil, 0, Int(frame.pointee.used), 0, &blockBuffer)
                if (osstatus != kCMBlockBufferNoErr) {
                    let error = NSError(domain: NSOSStatusErrorDomain, code: Int(osstatus), userInfo: nil)
                    print("Error creating the block buffer = %@", error.description)
                    success = false
                }
            }
            
            if success,
                let blockBuffer = blockBuffer {
                let sampleSizes: [Int] = [CMBlockBufferGetDataLength(blockBuffer)]
                let osstatus = CMSampleBufferCreate(kCFAllocatorDefault, blockBuffer, true, nil, nil, formatDesc,
                                                    1, 0, nil, 1, sampleSizes, &sampleBuffer)
                if osstatus != noErr {
                    success = false
                    let error = NSError(domain: NSOSStatusErrorDomain, code: Int(osstatus), userInfo:nil)
                    print("Error creating the sample buffer = %@", error.description)
                }
            }
            
            if success,
                let sampleBuffer = sampleBuffer,
                let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true) {
                let dict: CFMutableDictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
                CFDictionarySetValue(dict,
                                     Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                     Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
            }
            
            if success,
                let videoLayer = videoLayer, videoLayer.status != .failed && videoLayer.isReadyForMoreMediaData {
                DispatchQueue.main.async {
                    if self.canDisplayVideo, let sampleBuffer = sampleBuffer {
                        videoLayer.enqueue(sampleBuffer)
                    }
                }
            }

            // free memory
            if let sampleBuffer = sampleBuffer {
                CMSampleBufferInvalidate(sampleBuffer)
            }
        }

        return success
    }

    private func cleanFormatDesc() {
        DispatchQueue.main.async {
            if let _ = self.formatDesc {
                self.videoLayer?.flushAndRemoveImage()
            }
            
            self.formatDesc = nil
        }
    }

    @objc private func enteredBackground(notification: Notification?) {
        canDisplayVideo = false
    }
    
    @objc private func enterForeground(notification: Notification?) {
        canDisplayVideo = false
    }
    
    @objc private func decodingDidFail(notification: Notification?) {
        lastDecodeHasFailed = false
    }
}
