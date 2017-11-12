//
//  H264ImageView.m
//  SwiftParrotMinidrone
//
//  Created by Groovelab on 2017/11/12.
//  Copyright © 2017 Groovelab. All rights reserved.
//

#import "H264ImageView.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>

@interface H264ImageView ()

@property (nonatomic, retain) UIImageView *imageView;
@property (nonatomic, assign) VTDecompressionSessionRef decompressionSession;
@property (nonatomic, assign) CMVideoFormatDescriptionRef formatDesc;
@property (nonatomic, assign) int spsSize;
@property (nonatomic, assign) int ppsSize;
@property (nonatomic, assign) BOOL canDisplayVideo;
@property (nonatomic, assign) BOOL lastDecodeHasFailed;

@end

@implementation H264ImageView

- (id) init {
    self = [super init];
    if (self) {
        [self customInit];
    }
    return self;
}

- (id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self customInit];
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self customInit];
    }
    return self;
}

- (void) customInit {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(enteredBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(enterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(decodingDidFail:)
                                                 name:AVSampleBufferDisplayLayerFailedToDecodeNotification object:nil];
    
    _canDisplayVideo = YES;
    
    // create UIImageView and add it to the view
    _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
    _imageView.bounds = self.bounds;
    _imageView.backgroundColor = [UIColor blackColor];
    //    _imageView.opaque = NO;
    [self addSubview:_imageView];
}

-(void) dealloc {
    if (NULL != _formatDesc) {
        CFRelease(_formatDesc);
        _formatDesc = NULL;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name: UIApplicationDidEnterBackgroundNotification object: nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name: UIApplicationWillEnterForegroundNotification object: nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name: AVSampleBufferDisplayLayerFailedToDecodeNotification object: nil];
}

- (void) layoutSubviews {
    _imageView.frame = self.bounds;
}

- (BOOL) configureDecoder:(ARCONTROLLER_Stream_Codec_t)codec {
    OSStatus osstatus;
    NSError *error = nil;
    BOOL success = NO;
    
    if (codec.type == ARCONTROLLER_STREAM_CODEC_TYPE_H264) {
        _lastDecodeHasFailed = NO;
        if (_canDisplayVideo) {
            
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
    }
    
    return success;
}

- (BOOL) createDecompSession {
    _decompressionSession = NULL;
    VTDecompressionOutputCallbackRecord callBackRecord;
    callBackRecord.decompressionOutputCallback = decompressionSessionDecodeFrameCallback;
    callBackRecord.decompressionOutputRefCon = (__bridge void *)self;
    
    //  TODO:
    NSDictionary *destinationImageBufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],
                                                      (id)kCVPixelBufferOpenGLESCompatibilityKey, nil];
    
    OSStatus status =  VTDecompressionSessionCreate(NULL, _formatDesc, NULL,
                                                    NULL, // (__bridge CFDictionaryRef)(destinationImageBufferAttributes)
                                                    &callBackRecord, &_decompressionSession);
    NSLog(@"Video Decompression Session Create: \t %@", (status == noErr) ? @"successful!" : @"failed...");
    if(status != noErr) {
        NSLog(@"\t\t VTD ERROR type: %d", (int)status);
        return NO;
    } else {
        return YES;
    }
}

void decompressionSessionDecodeFrameCallback(void *decompressionOutputRefCon,
                                             void *sourceFrameRefCon,
                                             OSStatus status,
                                             VTDecodeInfoFlags infoFlags,
                                             CVImageBufferRef imageBuffer,
                                             CMTime presentationTimeStamp,
                                             CMTime presentationDuration) {
    H264ImageView *streamManager = (__bridge H264ImageView *)decompressionOutputRefCon;
    
    if (status != noErr) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"Decompressed error: %@", error);
    } else {
        NSLog(@"Decompressed sucessfully");
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (streamManager.canDisplayVideo) {

        CIImage *ciimage = [CIImage imageWithCVImageBuffer:imageBuffer];
        UIImage *image = [UIImage imageWithCIImage:ciimage];
        NSLog(@"UIImage : %@", image);
        
        streamManager.imageView.image = image;
            }
            
        });
    }
}

- (BOOL) displayFrame:(ARCONTROLLER_Frame_t *)frame {
    BOOL success = !_lastDecodeHasFailed;
    
    if (success && _canDisplayVideo) {
        CMBlockBufferRef blockBufferRef = NULL;
        //CMSampleTimingInfo timing = kCMTimingInfoInvalid;
        CMSampleBufferRef sampleBufferRef = NULL;
        
        OSStatus osstatus;
        NSError *error = nil;
        
        // on error, flush the video layer and wait for the next iFrame
//        if (!_videoLayer || [_videoLayer status] == AVQueuedSampleBufferRenderingStatusFailed) {
//            ARSAL_PRINT(ARSAL_PRINT_ERROR, "PilotingViewController", "Video layer status is failed : flush and wait for next iFrame");
//            [self cleanFormatDesc];
//            success = NO;
//        }
        
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
        
        if (success
//            &&
//            [_videoLayer status] != AVQueuedSampleBufferRenderingStatusFailed &&
//            _videoLayer.isReadyForMoreMediaData
            ){
//            dispatch_sync(dispatch_get_main_queue(), ^{
                if (_canDisplayVideo) {
                    NSLog(@"render");
                    VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression;
                    VTDecodeInfoFlags flagOut;
                    NSDate* currentTime = [NSDate date];
                    VTDecompressionSessionDecodeFrame(_decompressionSession, sampleBufferRef, flags,
                                                      (void*)CFBridgingRetain(currentTime), &flagOut);
                }
//            });
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


- (void) cleanFormatDesc {
    dispatch_sync(dispatch_get_main_queue(), ^{
        if (NULL != _formatDesc) {
            _imageView.image = nil;
//            [_videoLayer flushAndRemoveImage];
            CFRelease(_formatDesc);
            _formatDesc = NULL;
        }
    });
}

#pragma mark - notifications
- (void) enteredBackground:(NSNotification*)notification {
    _canDisplayVideo = NO;
}

- (void) enterForeground:(NSNotification*)notification {
    _canDisplayVideo = YES;
}

- (void) decodingDidFail:(NSNotification*)notification {
    _lastDecodeHasFailed = YES;
}

@end
