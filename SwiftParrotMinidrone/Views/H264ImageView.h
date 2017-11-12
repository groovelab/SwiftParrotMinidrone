//
//  H264ImageView.h
//  SwiftParrotMinidrone
//
//  Created by Groovelab on 2017/11/12.
//  Copyright © 2017 Groovelab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <libARController/ARController.h>

@interface H264ImageView : UIView

- (BOOL)configureDecoder:(ARCONTROLLER_Stream_Codec_t)codec;
- (BOOL)displayFrame:(ARCONTROLLER_Frame_t *)frame;

@end
