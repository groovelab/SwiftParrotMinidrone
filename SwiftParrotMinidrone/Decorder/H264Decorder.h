//
//  H264Decorder.h
//  SwiftParrotMinidrone
//
//  Created by Groovelab on 2017/11/12.
//  Copyright © 2017 Groovelab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <libARController/ARController.h>

@class H264Decorder;

@protocol H264DecorderDelegate <NSObject>

- (void)h264Decorder:(H264Decorder*)decorder didDecorde:(CIImage*)ciImage;

@end

@interface H264Decorder : NSObject

@property (nonatomic, weak) id<H264DecorderDelegate>delegate;

- (BOOL)configureDecoder:(ARCONTROLLER_Stream_Codec_t)codec;
- (BOOL)didReceive:(ARCONTROLLER_Frame_t *)frame;

@end

