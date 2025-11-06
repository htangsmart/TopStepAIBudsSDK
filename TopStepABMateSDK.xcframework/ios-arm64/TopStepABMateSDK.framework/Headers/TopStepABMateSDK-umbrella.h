#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "TSCppEISWrapper.h"
#import "TSOpusDecoder.h"
#import "TSSCOAudioCaptureManager.h"
#import "TSSCOAudioFileManager.h"
#import "TSVoiceActivityDetector.h"
#import "TopStepAIBudsSDK.h"
#import "TSCrashHandler.h"

FOUNDATION_EXPORT double TopStepABMateSDKVersionNumber;
FOUNDATION_EXPORT const unsigned char TopStepABMateSDKVersionString[];

