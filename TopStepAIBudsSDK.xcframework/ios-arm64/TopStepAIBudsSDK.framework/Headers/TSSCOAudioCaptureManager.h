#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

/// 音频采集错误域
FOUNDATION_EXPORT NSErrorDomain const TSSCOAudioErrorDomain;

typedef void(^TSSCOPCMBlock)(NSData *pcmData, UInt32 numFrames);
typedef void(^TSSCOErrorBlock)(NSError *error);
typedef void(^TSSCOVoiceActivityBlock)(BOOL isSpeaking);

typedef void(^TSSCOStartBlock)(void);
typedef void(^TSSCOEndBlock)(void);
typedef void(^TSSCODataBlock)(NSData *data);
typedef void(^TSSCOFinishedBlock)(NSString *filePath);

@interface TSSCOAudioCaptureManager : NSObject


/**
 * @brief Whether capturing is running
 * @chinese 是否正在采集
 *
 * @discussion
 * [EN]: Indicates if the audio unit is running and delivering PCM frames.
 * [CN]: 表示音频单元是否处于运行状态并持续回调PCM数据。
 */
@property (nonatomic, assign, readonly, getter=isCapturing) BOOL capturing;

/**
 * @brief Voice activity detection threshold (0.0 - 1.0)
 * @chinese 语音活动检测阈值（0.0 - 1.0）
 *
 * @discussion
 * [EN]: Audio power threshold for detecting voice activity. Values below this threshold are considered silence.
 * [CN]: 检测语音活动的音频能量阈值。低于此阈值的音频被认为是静音。
 *
 * @note
 * [EN]: Default value is 0.02. Lower values make it more sensitive to quiet sounds.
 * [CN]: 默认值为0.02。较低的值使其对安静声音更敏感。
 */
@property (nonatomic, assign) float silenceThreshold;

/**
 * @brief Silence timeout in seconds before considering speech ended
 * @chinese 静音超时时间（秒），超过此时间认为语音结束
 *
 * @discussion
 * [EN]: Time in seconds to wait after detecting silence before considering the user has stopped speaking.
 * [CN]: 检测到静音后等待的秒数，超过此时间认为用户已停止说话。
 *
 * @note
 * [EN]: Default value is 1.0 second. Adjust based on your application needs.
 * [CN]: 默认值为1.0秒。根据应用需求调整。
 */
@property (nonatomic, assign) float silenceTimeout;

/**
 * @brief Whether voice activity detection is enabled
 * @chinese 是否启用语音活动检测
 *
 * @discussion
 * [EN]: When enabled, the manager will detect voice activity and provide callbacks for speech start/end events.
 * [CN]: 启用后，管理器将检测语音活动并提供语音开始/结束事件的回调。
 */
@property (nonatomic, assign) BOOL voiceActivityDetectionEnabled;

/**
 * @brief Voice activity change callback
 * @chinese 语音活动状态变化回调
 *
 * @discussion
 * [EN]: Called when voice activity state changes (speaking started/stopped).
 * [CN]: 当语音活动状态变化时调用（开始说话/停止说话）。
 */
@property (nonatomic, copy, nullable) TSSCOVoiceActivityBlock voiceActivityBlock;


/**
 * @brief Shared singleton instance of SCO audio capture manager
 * @chinese SCO音频采集管理器的共享单例
 *
 * @return
 * EN: A shared singleton instance
 * CN: 单例实例
 */
+ (instancetype)sharedManager;

/**
 * @brief Start capturing audio via Bluetooth SCO/HFP route
 * @chinese 通过蓝牙SCO/HFP音频路由开始采集音频
 *
 * @param preferBluetooth
 * EN: Whether to prefer Bluetooth HFP route when available
 * CN: 是否优先使用蓝牙HFP音频路由
 *
 * @param sampleRate
 * EN: Target sample rate in Hz (typical 8000 or 16000)
 * CN: 目标采样率（常用8k或16k）
 *
 * @param onError
 * EN: Error callback when starting or during capture
 * CN: 启动或采集中发生错误的回调
 *
 * @return
 * EN: YES on success, NO otherwise
 * CN: 成功返回YES，失败返回NO
 */
- (BOOL)startCapturePreferBluetooth:(BOOL)preferBluetooth
                         sampleRate:(double)sampleRate
                              onError:(nullable TSSCOErrorBlock)onError;

/**
 * @brief Stop audio capture and teardown audio unit
 * @chinese 停止音频采集并销毁音频单元
 */
- (void)stopCapture;

/**
 * @brief Configure start/end/data/finished callbacks for voice chat session
 * @chinese 配置语音会话的开始/结束/数据/完成回调
 *
 * @param start 
 * EN: Invoked when speaking starts (VAD detects voice)
 * CN: 当开始说话时回调（VAD检测到语音）
 *
 * @param end 
 * EN: Invoked when speaking ends (after silence timeout)
 * CN: 当结束说话时回调（静音超时后）
 *
 * @param data 
 * EN: Streaming PCM data callback (16-bit mono)
 * CN: 持续返回16位单声道PCM数据
 *
 * @param finished 
 * EN: Invoked when a segment is finalized; provides a temporary file path of the PCM segment
 * CN: 语音片段最终完成时回调，提供该片段的临时PCM文件路径
 */
- (void)setupStartSpeak:(nullable TSSCOStartBlock)start
               endSpeak:(nullable TSSCOEndBlock)end
                   data:(nullable TSSCODataBlock)data
               finished:(nullable TSSCOFinishedBlock)finished;

@end

NS_ASSUME_NONNULL_END 
