//
//  MiniDrone.m
//  SDKSample
//

#import "MiniDrone.h"
#import "SDCardModule.h"

@interface MiniDrone ()<SDCardModuleDelegate>

@property (nonatomic, assign) ARCONTROLLER_Device_t *deviceController;
@property (nonatomic, assign) ARService *service;
@property (nonatomic, strong) SDCardModule *sdCardModule;
@property (nonatomic, assign) eARCONTROLLER_DEVICE_STATE connectionState;
@property (nonatomic, assign) eARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE flyingState;
@property (nonatomic, strong) NSString *currentRunId;
@property (nonatomic, assign) ARDISCOVERY_Device_t *discoveryDevice;
@end

@implementation MiniDrone

-(id)initWithService:(ARService *)service {
    self = [super init];
    if (self) {
        _service = service;
        _flyingState = ARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_LANDED;
    }
    return self;
}

- (void)dealloc
{
    if (_deviceController) {
        ARCONTROLLER_Device_Delete(&_deviceController);
    }

    // release the sdCardModule before releasing the discovery device
    _sdCardModule = nil;
    if (_discoveryDevice) {
        ARDISCOVERY_Device_Delete (&_discoveryDevice);
    }
}

- (void)connect {
    
    if (!_deviceController) {
        // call createDeviceControllerWithService in background
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // if the product type of the service matches with the supported types
            eARDISCOVERY_PRODUCT product = _service.product;
            eARDISCOVERY_PRODUCT_FAMILY family = ARDISCOVERY_getProductFamily(product);
            if (family == ARDISCOVERY_PRODUCT_FAMILY_MINIDRONE) {
                // create the device controller
                [self createDeviceControllerWithService:_service];
                //[self createSDCardModule];
            }
        });
    } else {
        ARCONTROLLER_Device_Start (_deviceController);
    }
}

- (void)disconnect {
    ARCONTROLLER_Device_Stop (_deviceController);
}

- (eARCONTROLLER_DEVICE_STATE)connectionState {
    return _connectionState;
}

- (eARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE)flyingState {
    return _flyingState;
}

- (void)createDeviceControllerWithService:(ARService*)service {
    // first get a discovery device
    _discoveryDevice = [self createDiscoveryDeviceWithService:service];
    
    if (_discoveryDevice != NULL) {
        eARCONTROLLER_ERROR error = ARCONTROLLER_OK;
        
        // create the device controller
        _deviceController = ARCONTROLLER_Device_New (_discoveryDevice, &error);
        
        // add the state change callback to be informed when the device controller starts, stops...
        if (error == ARCONTROLLER_OK) {
            error = ARCONTROLLER_Device_AddStateChangedCallback(_deviceController, stateChanged, (__bridge void *)(self));
        }
        
        // add the command received callback to be informed when a command has been received from the device
        if (error == ARCONTROLLER_OK) {
            error = ARCONTROLLER_Device_AddCommandReceivedCallback(_deviceController, onCommandReceived, (__bridge void *)(self));
        }

        // add the received frame callback to be informed when a frame should be displayed
        if (error == ARCONTROLLER_OK) {
            error = ARCONTROLLER_Device_SetVideoStreamMP4Compliant(_deviceController, 1);
            if (error == ARCONTROLLER_ERROR_NO_VIDEO)
                error = ARCONTROLLER_OK;
        }

        // add the received frame callback to be informed when a frame should be displayed
        if (error == ARCONTROLLER_OK) {
            error = ARCONTROLLER_Device_SetVideoStreamCallbacks(_deviceController, configDecoderCallback,
                                                                didReceiveFrameCallback, NULL , (__bridge void *)(self));
            if (error == ARCONTROLLER_ERROR_NO_VIDEO)
                error = ARCONTROLLER_OK;
        }
        
        // start the device controller (the callback stateChanged should be called soon)
        if (error == ARCONTROLLER_OK) {
            error = ARCONTROLLER_Device_Start (_deviceController);
        }
        
        // if an error occured, inform the delegate that the state is stopped
        if (error != ARCONTROLLER_OK) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_delegate miniDrone:self connectionDidChange:ARCONTROLLER_DEVICE_STATE_STOPPED];
            });
        }
    } else {
        // if an error occured, inform the delegate that the state is stopped
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate miniDrone:self connectionDidChange:ARCONTROLLER_DEVICE_STATE_STOPPED];
        });
    }
}

- (ARDISCOVERY_Device_t *)createDiscoveryDeviceWithService:(ARService*)service {
    ARDISCOVERY_Device_t *device = NULL;
    eARDISCOVERY_ERROR errorDiscovery = ARDISCOVERY_OK;
    
    device = [service createDevice:&errorDiscovery];
    
    if (errorDiscovery != ARDISCOVERY_OK)
        NSLog(@"Discovery error :%s", ARDISCOVERY_Error_ToString(errorDiscovery));
    
    return device;
}

- (void)createSDCardModule {
    if (_discoveryDevice) {
        _sdCardModule = [[SDCardModule alloc] initWithDiscoveryDevice:_discoveryDevice];
        _sdCardModule.delegate = self;
    }
}

#pragma mark commands
- (void)emergency {
    if (_deviceController && (_connectionState == ARCONTROLLER_DEVICE_STATE_RUNNING)) {
        _deviceController->miniDrone->sendPilotingEmergency(_deviceController->miniDrone);
    }
}

- (void)takeOff {
    if (_deviceController && (_connectionState == ARCONTROLLER_DEVICE_STATE_RUNNING)) {
        _deviceController->miniDrone->sendPilotingTakeOff(_deviceController->miniDrone);
    }
}

- (void)land {
    if (_deviceController && (_connectionState == ARCONTROLLER_DEVICE_STATE_RUNNING)) {
        _deviceController->miniDrone->sendPilotingLanding(_deviceController->miniDrone);
    }
}

- (void)takePicture {
    if (_deviceController && (_connectionState == ARCONTROLLER_DEVICE_STATE_RUNNING)) {
        // RollingSpider (not evo) are still using old deprecated command
        if (_service.product == ARDISCOVERY_PRODUCT_MINIDRONE) {
            _deviceController->miniDrone->sendMediaRecordPicture(_deviceController->miniDrone, 0);
        } else {
            _deviceController->miniDrone->sendMediaRecordPictureV2(_deviceController->miniDrone);
        }
    }
}

- (void)setPitch:(int8_t)pitch {
    if (_deviceController && (_connectionState == ARCONTROLLER_DEVICE_STATE_RUNNING)) {
        _deviceController->miniDrone->setPilotingPCMDPitch(_deviceController->miniDrone, pitch);
    }
}

- (void)setRoll:(int8_t)roll {
    if (_deviceController && (_connectionState == ARCONTROLLER_DEVICE_STATE_RUNNING)) {
        _deviceController->miniDrone->setPilotingPCMDRoll(_deviceController->miniDrone, roll);
    }
}

- (void)setYaw:(int8_t)yaw {
    if (_deviceController && (_connectionState == ARCONTROLLER_DEVICE_STATE_RUNNING)) {
        _deviceController->miniDrone->setPilotingPCMDYaw(_deviceController->miniDrone, yaw);
    }
}

- (void)setGaz:(int8_t)gaz {
    if (_deviceController && (_connectionState == ARCONTROLLER_DEVICE_STATE_RUNNING)) {
        _deviceController->miniDrone->setPilotingPCMDGaz(_deviceController->miniDrone, gaz);
    }
}

- (void)setFlag:(uint8_t)flag {
    if (_deviceController && (_connectionState == ARCONTROLLER_DEVICE_STATE_RUNNING)) {
        _deviceController->miniDrone->setPilotingPCMDFlag(_deviceController->miniDrone, flag);
    }
}

-(void)downloadMedias {
    if (!_sdCardModule) {
        [self createSDCardModule];
    }
    if (_currentRunId && ![_currentRunId isEqualToString:@""]) {
        [_sdCardModule getFlightMedias:_currentRunId];
    } else {
        [_sdCardModule getTodaysFlightMedias];
    }
    
}

- (void)cancelDownloadMedias {
    [_sdCardModule cancelGetMedias];
}

#pragma mark Device controller callbacks
// called when the state of the device controller has changed
static void stateChanged (eARCONTROLLER_DEVICE_STATE newState, eARCONTROLLER_ERROR error, void *customData) {
    MiniDrone *miniDrone = (__bridge MiniDrone*)customData;
    if (miniDrone != nil) {
        switch (newState) {
            case ARCONTROLLER_DEVICE_STATE_RUNNING:
                ARCONTROLLER_Device_StartVideoStream(miniDrone.deviceController);
                break;
            case ARCONTROLLER_DEVICE_STATE_STOPPED:
                break;
            default:
                break;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            miniDrone.connectionState = newState;
            [miniDrone.delegate miniDrone:miniDrone connectionDidChange:newState];
        });
    }
}

// called when a command has been received from the drone
static void onCommandReceived (eARCONTROLLER_DICTIONARY_KEY commandKey, ARCONTROLLER_DICTIONARY_ELEMENT_t *elementDictionary, void *customData) {
    MiniDrone *miniDrone = (__bridge MiniDrone*)customData;
    
    // if the command received is a battery state changed
    if ((commandKey == ARCONTROLLER_DICTIONARY_KEY_COMMON_COMMONSTATE_BATTERYSTATECHANGED) &&
        (elementDictionary != NULL) &&
        [miniDrone.delegate respondsToSelector:@selector(miniDrone:batteryDidChange:)]) {

        ARCONTROLLER_DICTIONARY_ARG_t *arg = NULL;
        ARCONTROLLER_DICTIONARY_ELEMENT_t *element = NULL;
        
        HASH_FIND_STR (elementDictionary, ARCONTROLLER_DICTIONARY_SINGLE_KEY, element);
        if (element != NULL) {
            HASH_FIND_STR (element->arguments, ARCONTROLLER_DICTIONARY_KEY_COMMON_COMMONSTATE_BATTERYSTATECHANGED_PERCENT, arg);
            if (arg != NULL) {
                uint8_t battery = arg->value.U8;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [miniDrone.delegate miniDrone:miniDrone batteryDidChange:battery];
                });
            }
        }
    }
    // if the command received is a flying state changed
    else if ((commandKey == ARCONTROLLER_DICTIONARY_KEY_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED) &&
        (elementDictionary != NULL)) {
        ARCONTROLLER_DICTIONARY_ARG_t *arg = NULL;
        ARCONTROLLER_DICTIONARY_ELEMENT_t *element = NULL;
        
        HASH_FIND_STR (elementDictionary, ARCONTROLLER_DICTIONARY_SINGLE_KEY, element);
        if (element != NULL) {
            HASH_FIND_STR (element->arguments, ARCONTROLLER_DICTIONARY_KEY_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE, arg);
            if (arg != NULL) {
                miniDrone.flyingState = arg->value.I32;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [miniDrone.delegate miniDrone:miniDrone flyingStateDidChange:miniDrone.flyingState];
                });
            }
        }
    }
    // if the command received is a run id changed
    else if ((commandKey == ARCONTROLLER_DICTIONARY_KEY_COMMON_RUNSTATE_RUNIDCHANGED) &&
             (elementDictionary != NULL)) {
        ARCONTROLLER_DICTIONARY_ARG_t *arg = NULL;
        ARCONTROLLER_DICTIONARY_ELEMENT_t *element = NULL;
        
        HASH_FIND_STR (elementDictionary, ARCONTROLLER_DICTIONARY_SINGLE_KEY, element);
        if (element != NULL) {
            HASH_FIND_STR (element->arguments, ARCONTROLLER_DICTIONARY_KEY_COMMON_RUNSTATE_RUNIDCHANGED_RUNID, arg);
            if (arg != NULL) {
                char * runId = arg->value.String;
                if (runId != NULL) {
                    miniDrone.currentRunId = [NSString stringWithUTF8String:runId];
                }
            }
        }
    }

    //  additional drone state information
    // if the command received is speed changed
    else if ((commandKey == ARCONTROLLER_DICTIONARY_KEY_MINIDRONE_NAVIGATIONDATASTATE_DRONESPEED) &&
             (elementDictionary != NULL) &&
             [miniDrone.delegate respondsToSelector:@selector(miniDrone:speedChanged:y:z:)]) {

        ARCONTROLLER_DICTIONARY_ARG_t *arg = NULL;
        ARCONTROLLER_DICTIONARY_ELEMENT_t *element = NULL;
        
        HASH_FIND_STR (elementDictionary, ARCONTROLLER_DICTIONARY_SINGLE_KEY, element);
        if (element != NULL) {
            HASH_FIND_STR (element->arguments, ARCONTROLLER_DICTIONARY_KEY_MINIDRONE_NAVIGATIONDATASTATE_DRONESPEED_SPEED_X, arg);
            float speed_x = arg == NULL ? FLT_MAX : arg->value.Float;
            
            HASH_FIND_STR (element->arguments, ARCONTROLLER_DICTIONARY_KEY_MINIDRONE_NAVIGATIONDATASTATE_DRONESPEED_SPEED_Y, arg);
            float speed_y = arg == NULL ? FLT_MAX : arg->value.Float;
            
            HASH_FIND_STR (element->arguments, ARCONTROLLER_DICTIONARY_KEY_MINIDRONE_NAVIGATIONDATASTATE_DRONESPEED_SPEED_Z, arg);
            float speed_z = arg == NULL ? FLT_MAX : arg->value.Float;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [miniDrone.delegate miniDrone:miniDrone speedChanged:speed_x y:speed_y z:speed_z];
            });
        }
    }
    // if the command received is altitude changed
    else if ((commandKey == ARCONTROLLER_DICTIONARY_KEY_MINIDRONE_NAVIGATIONDATASTATE_DRONEALTITUDE) &&
             (elementDictionary != NULL) &&
             [miniDrone.delegate respondsToSelector:@selector(miniDrone:altitude:)]) {

        //  need to be with FPV camera
        ARCONTROLLER_DICTIONARY_ARG_t *arg = NULL;
        ARCONTROLLER_DICTIONARY_ELEMENT_t *element = NULL;

        HASH_FIND_STR (elementDictionary, ARCONTROLLER_DICTIONARY_SINGLE_KEY, element);
        if (element != NULL) {
            HASH_FIND_STR (element->arguments, ARCONTROLLER_DICTIONARY_KEY_MINIDRONE_NAVIGATIONDATASTATE_DRONEALTITUDE_ALTITUDE, arg);
            if (arg != NULL) {
                float altitude = arg->value.Float;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [miniDrone.delegate miniDrone:miniDrone altitude:altitude];
                });
            }
        }
    }
    // if the command received is quaternion changed
    else if ((commandKey == ARCONTROLLER_DICTIONARY_KEY_MINIDRONE_NAVIGATIONDATASTATE_DRONEQUATERNION) &&
             (elementDictionary != NULL) &&
             [miniDrone.delegate respondsToSelector:@selector(miniDrone:quaternionChanged:x:y:z:)]) {

        //  need to be with FPV camera
        ARCONTROLLER_DICTIONARY_ARG_t *arg = NULL;
        ARCONTROLLER_DICTIONARY_ELEMENT_t *element = NULL;

        HASH_FIND_STR (elementDictionary, ARCONTROLLER_DICTIONARY_SINGLE_KEY, element);
        if (element != NULL) {
            HASH_FIND_STR (element->arguments, ARCONTROLLER_DICTIONARY_KEY_MINIDRONE_NAVIGATIONDATASTATE_DRONEQUATERNION_Q_W, arg);
            float q_w = arg == NULL ? FLT_MAX : arg->value.Float;
            
            HASH_FIND_STR (element->arguments, ARCONTROLLER_DICTIONARY_KEY_MINIDRONE_NAVIGATIONDATASTATE_DRONEQUATERNION_Q_X, arg);
            float q_x = arg == NULL ? FLT_MAX : arg->value.Float;
            
            HASH_FIND_STR (element->arguments, ARCONTROLLER_DICTIONARY_KEY_MINIDRONE_NAVIGATIONDATASTATE_DRONEQUATERNION_Q_Y, arg);
            float q_y = arg == NULL ? FLT_MAX : arg->value.Float;
            
            HASH_FIND_STR (element->arguments, ARCONTROLLER_DICTIONARY_KEY_MINIDRONE_NAVIGATIONDATASTATE_DRONEQUATERNION_Q_Z, arg);
            float q_z = arg == NULL ? FLT_MAX : arg->value.Float;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [miniDrone.delegate miniDrone:miniDrone quaternionChanged:q_w x:q_x y:q_y z:q_z];
            });
        }
    }
}

static eARCONTROLLER_ERROR configDecoderCallback (ARCONTROLLER_Stream_Codec_t codec, void *customData) {
    MiniDrone *miniDrone = (__bridge MiniDrone*)customData;
    return [miniDrone.delegate respondsToSelector:@selector(miniDrone:configureDecoder:)] ?
    ([miniDrone.delegate miniDrone:miniDrone configureDecoder:codec] ? ARCONTROLLER_OK : ARCONTROLLER_ERROR) :
    ARCONTROLLER_OK;
}

static eARCONTROLLER_ERROR didReceiveFrameCallback (ARCONTROLLER_Frame_t *frame, void *customData) {
    MiniDrone *miniDrone = (__bridge MiniDrone*)customData;
    return [miniDrone.delegate respondsToSelector:@selector(miniDrone:didReceiveFrame:)] ?
    ([miniDrone.delegate miniDrone:miniDrone didReceiveFrame:frame] ? ARCONTROLLER_OK : ARCONTROLLER_ERROR) :
    ARCONTROLLER_OK;
}

#pragma mark SDCardModuleDelegate
- (void)sdcardModule:(SDCardModule*)module didFoundMatchingMedias:(NSUInteger)nbMedias {
    if ([_delegate respondsToSelector:@selector(miniDrone:didFoundMatchingMedias:)]) {
        [_delegate miniDrone:self didFoundMatchingMedias:nbMedias];
    }
}

- (void)sdcardModule:(SDCardModule*)module media:(NSString*)mediaName downloadDidProgress:(int)progress {
    if ([_delegate respondsToSelector:@selector(miniDrone:downloadDidProgress:)]) {
        [_delegate miniDrone:self media:mediaName downloadDidProgress:progress];
    }
}

- (void)sdcardModule:(SDCardModule*)module mediaDownloadDidFinish:(NSString*)mediaName {
    if ([_delegate respondsToSelector:@selector(miniDrone:mediaDownloadDidFinish:)]) {
        [_delegate miniDrone:self mediaDownloadDidFinish:mediaName];
    }
}
@end
