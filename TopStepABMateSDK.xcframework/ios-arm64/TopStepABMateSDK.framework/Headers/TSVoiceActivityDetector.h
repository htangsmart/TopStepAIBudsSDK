#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN


/**
 * @brief PCM audio format enumeration
 * @chinese PCM音频格式枚举
 *
 * @discussion
 * [EN]: Supported PCM audio formats for voice activity detection.
 * [CN]: 语音活动检测支持的PCM音频格式。
 */
typedef NS_ENUM(NSUInteger, TSVADPCMFormat) {
    TSVADPCMFormatInt16LE = 0,    // 16-bit signed integer, little-endian
    TSVADPCMFormatInt16BE = 1,    // 16-bit signed integer, big-endian
    TSVADPCMFormatFloat32LE = 2,  // 32-bit float, little-endian
    TSVADPCMFormatFloat32BE = 3,  // 32-bit float, big-endian
};

/**
 * @brief Voice Activity Detector
 * @chinese 语音活动检测器
 *
 * @discussion
 * [EN]: Detects voice activity in audio streams and manages state transitions.
 *       Supports multiple PCM formats and provides real-time state callbacks.
 * [CN]: 检测音频流中的语音活动并管理状态转换。
 *       支持多种PCM格式并提供实时状态回调。
 */
@interface TSVoiceActivityDetector : NSObject

#pragma mark - Configuration Properties

@property (nonatomic,assign) BOOL isSpeaking;


/**
 * @brief Silence detection threshold
 * @chinese 静音检测阈值
 *
 * @discussion
 * [EN]: Audio power threshold for detecting silence. Values below this threshold are considered silence.
 *       Range: 0.0 - 1.0, where 0.0 is absolute silence and 1.0 is maximum amplitude.
 * [CN]: 检测静音的音频功率阈值。低于此阈值的值被认为是静音。
 *       范围：0.0 - 1.0，其中 0.0 是绝对静音，1.0 是最大振幅。
 *
 * @note
 * [EN]: Default value is 0.02. Lower values make detection more sensitive to quiet sounds.
 * [CN]: 默认值为 0.02。较低的值使检测对安静声音更敏感。
 */
@property (nonatomic, assign) float silenceThreshold;

#pragma mark - Lifecycle

/**
 * @brief Initialize the voice activity detector
 * @chinese 初始化语音活动检测器
 *
 * @return
 * EN: A new instance of TSVoiceActivityDetector
 * CN: TSVoiceActivityDetector的新实例
 */
- (instancetype)init;

/**
 * @brief Reset the detector to initial state
 * @chinese 重置检测器到初始状态
 *
 * @discussion
 * [EN]: Resets all internal state to Idle. Call this when starting a new detection session.
 * [CN]: 重置所有内部状态到空闲。在开始新的检测会话时调用此方法。
 */
- (void)reset;

#pragma mark - State Query

/**
 * @brief Check if currently speaking
 * @chinese 检查是否正在说话
 *
 * @return
 * EN: YES if in Speaking or SpeakingStar state, NO otherwise
 * CN: 如果处于"说话中"或"开始说话"状态则返回YES，否则返回NO
 *
 * @discussion
 * [EN]: Convenience method to check if voice activity is currently detected.
 * [CN]: 便捷方法，用于检查当前是否检测到语音活动。
 */
//- (BOOL)isSpeaking;

#pragma mark - Audio Processing

/**
 * @brief Process audio buffer for voice activity detection
 * @chinese 处理音频缓冲区以进行语音活动检测
 *
 * @param audioBuffer
 * EN: Audio buffer containing PCM samples
 * CN: 包含PCM采样的音频缓冲区
 *
 * @param frameCount
 * EN: Number of audio frames in the buffer
 * CN: 缓冲区中的音频帧数
 *
 * @return
 * EN: Current VAD state after processing
 * CN: 处理后的当前VAD状态
 *
 * @discussion
 * [EN]: Processes audio buffer and updates internal state based on detected voice activity.
 *       Assumes 16-bit signed integer mono audio format.
 * [CN]: 处理音频缓冲区并根据检测到的语音活动更新内部状态。
 *       假设为16位有符号整数单声道音频格式。
 */
//- (TSVADState)processAudioBuffer:(AudioBuffer)audioBuffer frameCount:(UInt32)frameCount;

- (BOOL)speakStateWithBuffer:(AudioBuffer)audioBuffer frameCount:(UInt32)frameCount;


/**
 * @brief Process raw PCM data for voice activity detection
 * @chinese 处理原始PCM数据以进行语音活动检测
 *
 * @param data
 * EN: Raw PCM audio data
 * CN: 原始PCM音频数据
 *
 * @param format
 * EN: PCM format of the audio data
 * CN: 音频数据的PCM格式
 *
 * @param channels
 * EN: Number of audio channels
 * CN: 音频声道数
 *
 * @return
 * EN: Current VAD state after processing
 * CN: 处理后的当前VAD状态
 *
 * @discussion
 * [EN]: Processes raw PCM data supporting multiple formats and channel configurations.
 *       More flexible than processAudioBuffer for different audio sources.
 * [CN]: 处理原始PCM数据，支持多种格式和声道配置。
 *       比 processAudioBuffer 更灵活，适用于不同的音频源。
 */
//- (TSVADState)processPCMData:(NSData *)data format:(TSVADPCMFormat)format channels:(UInt32)channels;

- (BOOL)speakStateWithPCMData:(NSData *)data format:(TSVADPCMFormat)format channels:(UInt32)channels;

@end

NS_ASSUME_NONNULL_END
