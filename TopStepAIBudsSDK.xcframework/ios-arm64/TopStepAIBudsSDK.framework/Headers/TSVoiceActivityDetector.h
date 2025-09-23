#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^TSVADStateBlock)(BOOL isSpeaking);

typedef NS_ENUM(NSUInteger, TSVADPCMFormat) {
    TSVADPCMFormatInt16LE = 0,
    TSVADPCMFormatInt16BE = 1,
    TSVADPCMFormatFloat32LE = 2,
    TSVADPCMFormatFloat32BE = 3,
};

@interface TSVoiceActivityDetector : NSObject

@property (nonatomic, assign) float silenceThreshold;   // 0.0 - 1.0, default 0.02
@property (nonatomic, assign) float silenceTimeout;     // seconds, default 1.0
@property (nonatomic, assign, readonly) BOOL isSpeaking;

@property (nonatomic, copy, nullable) TSVADStateBlock onStateChanged;

- (instancetype)init;

- (void)reset;

- (BOOL)processAudioBuffer:(AudioBuffer)audioBuffer frameCount:(UInt32)frameCount;

// 直接处理原始PCM数据（支持多种格式与声道）
- (BOOL)processPCMData:(NSData *)data format:(TSVADPCMFormat)format channels:(UInt32)channels;

@end

NS_ASSUME_NONNULL_END


