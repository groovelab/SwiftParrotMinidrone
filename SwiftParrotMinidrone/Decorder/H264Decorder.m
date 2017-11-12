//
//  H264Decorder.m
//  SwiftParrotMinidrone
//
//  Created by Groovelab on 2017/11/12.
//  Copyright © 2017 Groovelab. All rights reserved.
//

#import "H264Decorder.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>

@interface H264Decorder ()

@property (nonatomic, assign) VTDecompressionSessionRef decompressionSession;
@property (nonatomic, assign) CMVideoFormatDescriptionRef formatDesc;
@property (nonatomic, assign) BOOL lastDecodeHasFailed;

@end

@implementation H264Decorder

- (id)init {
    self = [super init];
    if (self) {
        [self customInit];
    }
    return self;
}

- (void)customInit {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(decodingDidFail:)
                                                 name:AVSampleBufferDisplayLayerFailedToDecodeNotification object:nil];
}

- (void)dealloc {
    if (NULL != _decompressionSession) {
        VTDecompressionSessionInvalidate(_decompressionSession);
        CFRelease(_decompressionSession);
    }

    if (NULL != _formatDesc) {
        CFRelease(_formatDesc);
        _formatDesc = NULL;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name: AVSampleBufferDisplayLayerFailedToDecodeNotification object: nil];
}

- (BOOL)configureDecoder:(ARCONTROLLER_Stream_Codec_t)codec {
    OSStatus osstatus;
    NSError *error = nil;
    BOOL success = NO;
    
    if (codec.type == ARCONTROLLER_STREAM_CODEC_TYPE_H264) {
        _lastDecodeHasFailed = NO;
        uint8_t* props[] = {
            codec.parameters.h264parameters.spsBuffer+4,
            codec.parameters.h264parameters.ppsBuffer+4
        };
        
        size_t sizes[] = {
            codec.parameters.h264parameters.spsSize-4,
            codec.parameters.h264parameters.ppsSize-4
        };
        
        if (NULL != _formatDesc) {
            CFRelease(_formatDesc);
            _formatDesc = NULL;
        }
        
        osstatus = CMVideoFormatDescriptionCreateFromH264ParameterSets(NULL, 2, (const uint8_t *const*)props,
                                                                       sizes, 4, &_formatDesc);
        if (osstatus != kCMBlockBufferNoErr) {
            error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                        code:osstatus
                                    userInfo:nil];
            NSLog(@"Error creating the format description = %@", [error description]);
            [self cleanFormatDesc];
        } else {
            success = [self createDecompSession];
        }
    }
    
    return success;
}

- (BOOL)createDecompSession {
    _decompressionSession = NULL;
    VTDecompressionOutputCallbackRecord callBackRecord;
    callBackRecord.decompressionOutputCallback = H264DecorderDecompressionSessionDecodeFrameCallback;
    callBackRecord.decompressionOutputRefCon = (__bridge void *)self;

//    NSDictionary *destinationImageBufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],
//                                                      (id)kCVPixelBufferOpenGLESCompatibilityKey, nil];
    
    
    OSStatus status =  VTDecompressionSessionCreate(NULL, _formatDesc, NULL,
                                                    NULL,
//                                                    (__bridge CFDictionaryRef)(destinationImageBufferAttributes),
                                                    &callBackRecord, &_decompressionSession);
    
    NSLog(@"Video Decompression Session Create: \t %@", (status == noErr) ? @"successful!" : @"failed...");
    if(status != noErr) {
        NSLog(@"\t\t VTD ERROR type: %d", (int)status);
        return NO;
    } else {
        return YES;
    }
}

void H264DecorderDecompressionSessionDecodeFrameCallback(void *decompressionOutputRefCon,
                                                         void *sourceFrameRefCon,
                                                         OSStatus status,
                                                         VTDecodeInfoFlags infoFlags,
                                                         CVImageBufferRef imageBuffer,
                                                         CMTime presentationTimeStamp,
                                                         CMTime presentationDuration) {
    
    H264Decorder *streamManager = (__bridge H264Decorder *)decompressionOutputRefCon;

    if (status != noErr) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"Decompressed error: %@", error);
    } else {
        CIImage *ciimage = [CIImage imageWithCVPixelBuffer:imageBuffer];
        CIContext *context = [CIContext contextWithOptions:nil];
        CGImageRef cgimage = [context createCGImage:ciimage
                                           fromRect:CGRectMake(0, 0,
                                                               CVPixelBufferGetWidth(imageBuffer),
                                                               CVPixelBufferGetHeight(imageBuffer))];
        [streamManager.delegate h264Decorder:streamManager didDecorde:[UIImage imageWithCGImage:cgimage]];
        CGImageRelease(cgimage);
    }
}

- (BOOL)didReceive:(ARCONTROLLER_Frame_t *)frame {
    BOOL success = !_lastDecodeHasFailed;
    
    if (success) {
        CMBlockBufferRef blockBufferRef = NULL;
        //CMSampleTimingInfo timing = kCMTimingInfoInvalid;
        CMSampleBufferRef sampleBufferRef = NULL;
        
        OSStatus osstatus;
        NSError *error = nil;
        
        if (success) {
            osstatus  = CMBlockBufferCreateWithMemoryBlock(CFAllocatorGetDefault(), frame->data, frame->used,
                                                           kCFAllocatorNull, NULL, 0, frame->used, 0, &blockBufferRef);
            if (osstatus != kCMBlockBufferNoErr) {
                error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                            code:osstatus
                                        userInfo:nil];
                NSLog(@"Error creating the block buffer = %@", [error description]);
                success = NO;
            }
        }
        
        if (success) {
            const size_t sampleSize = frame->used;
            osstatus = CMSampleBufferCreate(kCFAllocatorDefault, blockBufferRef, true, NULL, NULL,
                                            _formatDesc, 1, 0, NULL, 1, &sampleSize, &sampleBufferRef);
            if (osstatus != noErr) {
                success = NO;
                error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                            code:osstatus
                                        userInfo:nil];
                NSLog(@"Error creating the sample buffer = %@", [error description]);
            }
        }
        
        if (success) {
            // add the attachment which says that sample should be displayed immediately
            CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBufferRef, YES);
            CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
            CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
        }
        
        if (success) {
            VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression;
            VTDecodeInfoFlags flagOut;
            VTDecompressionSessionDecodeFrame(_decompressionSession, sampleBufferRef, flags,
                                              nil,
                                              &flagOut);
        }
        
        // free memory
        if (NULL != sampleBufferRef) {
            CMSampleBufferInvalidate(sampleBufferRef);
            CFRelease(sampleBufferRef);
            sampleBufferRef = NULL;
        }
        
        if (NULL != blockBufferRef) {
            CFRelease(blockBufferRef);
            blockBufferRef = NULL;
        }
    }
    
    return success;
}

- (void)cleanFormatDesc {
    dispatch_sync(dispatch_get_main_queue(), ^{
        if (NULL != _formatDesc) {
            CFRelease(_formatDesc);
            _formatDesc = NULL;
        }
    });
}

#pragma mark - notifications
- (void)decodingDidFail:(NSNotification*)notification {
    _lastDecodeHasFailed = YES;
}

@end
