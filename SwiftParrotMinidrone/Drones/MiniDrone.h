//
//  MiniDrone.h
//  SDKSample
//

#import <Foundation/Foundation.h>
#import <libARController/ARController.h>
#import <libARDiscovery/ARDISCOVERY_BonjourDiscovery.h>

@class MiniDrone;

@protocol MiniDroneDelegate <NSObject>
@required
/**
 * Called when the connection to the drone did change
 * Called on the main thread
 * @param miniDrone the drone concerned
 * @param state the state of the connection
 */
- (void)miniDrone:(MiniDrone*)miniDrone connectionDidChange:(eARCONTROLLER_DEVICE_STATE)state;

/**
 * Called when the piloting state did change
 * Called on the main thread
 * @param miniDrone the drone concerned
 * @param batteryPercent the piloting state of the drone
 */
- (void)miniDrone:(MiniDrone*)miniDrone flyingStateDidChange:(eARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE)state;

@optional
/**
 * Called when the battery charge did change
 * Called on the main thread
 * @param MiniDrone the drone concerned
 * @param batteryPercent the battery remaining (in percent)
 */
- (void)miniDrone:(MiniDrone*)miniDrone batteryDidChange:(int)batteryPercentage;

/**
 * Called when the video decoder should be configured
 * Called on separate thread
 * @param miniDrone the drone concerned
 * @param codec the codec information about the stream
 * @return true if configuration went well, false otherwise
 */
- (BOOL)miniDrone:(MiniDrone*)miniDrone configureDecoder:(ARCONTROLLER_Stream_Codec_t)codec;

/**
 * Called when a frame has been received
 * Called on separate thread
 * @param miniDrone the drone concerned
 * @param frame the frame received
 */
- (BOOL)miniDrone:(MiniDrone*)miniDrone didReceiveFrame:(ARCONTROLLER_Frame_t*)frame;

/**
 * Called before medias will be downloaded
 * Called on the main thread
 * @param miniDrone the drone concerned
 * @param nbMedias the number of medias that will be downloaded
 */
- (void)miniDrone:(MiniDrone*)miniDrone didFoundMatchingMedias:(NSUInteger)nbMedias;

/**
 * Called each time the progress of a download changes
 * Called on the main thread
 * @param miniDrone the drone concerned
 * @param mediaName the name of the media
 * @param progress the progress of its download (from 0 to 100)
 */
- (void)miniDrone:(MiniDrone*)miniDrone media:(NSString*)mediaName downloadDidProgress:(int)progress;

/**
 * Called when a media download has ended
 * Called on the main thread
 * @param miniDrone the drone concerned
 * @param mediaName the name of the media
 */
- (void)miniDrone:(MiniDrone*)miniDrone mediaDownloadDidFinish:(NSString*)mediaName;

/**
 * Called when speed changed
 * Called on the main thread
 * @param MiniDrone the drone concerned
 * @param x speed of x axis
 * @param y speed of x axis
 * @param z speed of x axis
 */
- (void)miniDrone:(MiniDrone*)miniDrone speedChanged:(float)x y:(float)y z:(float)z;

/**
 * Called when altitude changed
 * Called on the main thread
 * @param MiniDrone the drone concerned
 * @param altitude
 */
- (void)miniDrone:(MiniDrone*)miniDrone altitude:(float)altitude;

/**
 * Called when quaternion changed
 * Called on the main thread
 * @param MiniDrone the drone concerned
 * @param w quaternion of w
 * @param x quaternion of x
 * @param y quaternion of y
 * @param z quaternion of z
 */
- (void)miniDrone:(MiniDrone*)miniDrone quaternionChanged:(float)w x:(float)x y:(float)y z:(float)z;

@end

@interface MiniDrone : NSObject

@property (nonatomic, weak) id<MiniDroneDelegate>delegate;

- (id)initWithService:(ARService*)service;
- (void)connect;
- (void)disconnect;
- (eARCONTROLLER_DEVICE_STATE)connectionState;
- (eARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE)flyingState;

- (void)emergency;
- (void)takeOff;
- (void)land;
- (void)takePicture;
- (void)setPitch:(int8_t)pitch;
- (void)setRoll:(int8_t)roll;
- (void)setYaw:(int8_t)yaw;
- (void)setGaz:(int8_t)gaz;
- (void)setFlag:(uint8_t)flag;
- (void)downloadMedias;
- (void)cancelDownloadMedias;
@end
