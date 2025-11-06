#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "TSVoiceActivityDetector.h"
#import "TSSCOAudioFileManager.h"

NS_ASSUME_NONNULL_BEGIN

/// 音频采集错误域
FOUNDATION_EXPORT NSErrorDomain const TSSCOAudioErrorDomain;


/**
 * @brief Voice Activity Detection (VAD) state enumeration
 * @chinese 语音活动检测（VAD）状态枚举
 *
 * @discussion
 * [EN]: Represents different states in the voice activity detection lifecycle.
 *       State transitions: Idle → RecordingStart → SpeakingStar → Speaking → SpeakingEnd → RecordingEnd
 * [CN]: 表示语音活动检测生命周期中的不同状态。
 *       状态转换：未开始 → 开始收音 → 开始说话 → 说话中 → 结束说话 → 结束收音
 */
typedef NS_ENUM(NSUInteger, TSVADState) {

    TSVADStateSilence = 0,
    
    /**
     * [EN]: Voice activity detected
     * [CN]: 检测到语音活动
     */
    TSVADStateSpeakingStar = 1,
    
    /**
     * [EN]: Continuous voice activity detected (speaking)
     * [CN]: 持续检测到语音活动（说话中）
     */
    TSVADStateSpeaking = 2,
    
    /**
     * [EN]: Voice activity ended (silence detected after speaking)
     * [CN]: 语音活动结束（说话后检测到静音）
     */
    TSVADStateSpeakingEnd = 3,
};

/**
 * @brief VAD state change callback block
 * @chinese VAD状态变化回调块
 *
 * @param state
 * EN: Current VAD state
 * CN: 当前VAD状态
 */
typedef void(^TSVADStateBlock)(TSVADState state);


typedef void(^TSSCOPCMBlock)(NSData *pcmData, UInt32 numFrames);
typedef void(^TSSCOErrorBlock)(NSError *error);
typedef void(^TSSCOSuccessBlock)(void);

typedef void(^TSSCOSpeakStartBlock)(void);
typedef void(^TSSCOSpeakDataBlock)(NSData *data);
typedef void(^TSSCOSpeakEndBlock)(void);

/**
 * @class TSSCOAudioCaptureManager
 * @brief High-level controller for Bluetooth SCO audio capture.
 *
 * @discussion
 * [EN]: Encapsulates the lifecycle of AVAudioSession/AudioUnit configuration,
 *       voice-activity detection (VAD) and PCM persistence for SCO capture.
 * [CN]: 封装蓝牙 SCO 录音的完整流程，负责音频会话与 AudioUnit 配置、语音活动检测
 *       以及 PCM 数据持久化。
 */
@interface TSSCOAudioCaptureManager : NSObject


//@property (nonatomic,assign) BOOL isPreSpeaking;

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
 * @chinese 静音超时时间（秒），检测说话结束
 *
 * @discussion
 * [EN]: Time in seconds to wait after detecting silence before considering the user has stopped speaking.
 *       This triggers the transition from Speaking to SpeakingEnd state.
 * [CN]: 检测到静音后等待的秒数，超过此时间认为用户已停止说话。
 *       这会触发从"说话中"到"结束说话"的状态转换。
 *
 * @note
 * [EN]: Default value is 1.0 second. Adjust based on your application needs.
 * [CN]: 默认值为1.0秒。根据应用需求调整。
 */
@property (nonatomic, assign) float silenceTimeout;

/**
 * @brief Recording stop timeout in seconds for auto-stopping capture
 * @chinese 录音停止超时（秒），自动结束拾音
 *
 * @discussion
 * [EN]: Time in seconds to allow silence before automatically stopping the recording session.
 *       This triggers the transition from SpeakingEnd to RecordingEnd state.
 *       Set to 0 to disable this feature.
 *       Must be used with enableRecordStopTimeout property.
 * [CN]: 允许静音的时长（秒），超过此时间将自动停止整个录音会话。
 *       这会触发从"结束说话"到"结束收音"的状态转换。
 *       设置为0表示禁用此功能。
 *       需要配合 enableRecordStopTimeout 属性使用。
 *
 * @note
 * [EN]: Default value is 0 (disabled). Set a positive value to enable auto-stop.
 *       This value is automatically synchronized with the internal VAD's recordStopTimeout.
 * [CN]: 默认值为0（禁用）。设置正值以启用自动停止功能。
 *       此值会自动同步到内部VAD的recordStopTimeout属性。
 */
@property (nonatomic, assign) float recordStopTimeout;

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
 * @brief Reusable voice activity detector instance.
 * @chinese 可复用的语音活动检测器实例。
 */
@property (nonatomic, strong) TSVoiceActivityDetector *vad;

/**
 * @brief Audio file manager used to persist captured PCM data.
 * @chinese 用于持久化录制 PCM 数据的音频文件管理器。
 */
@property (nonatomic, strong, readonly) TSSCOAudioFileManager *fileManager;

/**
 * @brief Indicates whether the VAD currently considers the user speaking.
 * @chinese 当前语音活动检测是否认为用户正在说话。
 */
@property (nonatomic, assign) BOOL isSpeaking;

/**
 * @brief Timestamp of the most recent detected voice activity.
 * @chinese 最近一次检测到语音的时间戳。
 */
@property (nonatomic, strong) NSDate *lastVoiceDate;

/**
 * @brief Current VAD state, derived from the internal detector.
 * @chinese 当前的语音活动检测状态，由内部检测器维护。
 */
@property (nonatomic, assign) TSVADState vadState;

/**
 * @brief Start SCO capture with optional Bluetooth preference.
 * @chinese 启动 SCO 采集，可指定是否优先使用蓝牙。
 *
 * @param preferBluetooth
 *        [EN] When YES, attempts to route audio through Bluetooth HFP.
 *        [CN] 设为 YES 时优先将音频路由到蓝牙 HFP。
 * @param sampleRate
 *        [EN] Desired sample rate; when <= 0 the default 16 kHz is used.
 *        [CN] 期望的采样率，传入 <= 0 时使用默认 16 kHz。
 * @param success
 *        [EN] Callback invoked on successful start.
 *        [CN] 采集成功启动时的回调。
 * @param failed
 *        [EN] Callback invoked when start fails (provides NSError).
 *        [CN] 启动失败时的回调，返回 NSError。
 */
- (void)startCapturePreferBluetooth:(BOOL)preferBluetooth
                         sampleRate:(double)sampleRate
                            success:(nullable TSSCOSuccessBlock)success
                             failed:(nullable TSSCOErrorBlock)failed;

/**
 * @brief Stop SCO capture and release underlying audio resources.
 * @chinese 停止 SCO 采集并释放底层音频资源。
 */
- (void)stopCapture;

/**
 * @brief Evaluate voice activity for a PCM buffer.
 * @chinese 对 PCM 数据执行语音活动检测。
 *
 * @param pcmData
 *        [EN] PCM buffer captured from the audio unit.
 *        [CN] 从 AudioUnit 捕获的 PCM 数据。
 * @param frameCount
 *        [EN] Number of PCM frames contained in the buffer.
 *        [CN] 数据中包含的 PCM 帧数。
 * @return
 *        [EN] YES when speech is detected, otherwise NO.
 *        [CN] 检测到语音活动返回 YES，否则返回 NO。
 */
- (BOOL)speakStateWithPCMData:(NSData *)pcmData frameCount:(UInt32)frameCount;


/**
 * @brief Register callbacks for speech lifecycle notifications.
 * @chinese 注册语音生命周期相关的回调。
 *
 * @param speakStart
 *        [EN] Invoked when the detector considers the user has started speaking.
 *        [CN] 用户开始说话时触发的回调。
 * @param data
 *        [EN] Invoked for each PCM buffer delivered to upper layers.
 *        [CN] 每次提供 PCM 数据时触发的回调。
 * @param speakEnd
 *        [EN] Invoked when speaking is considered finished.
 *        [CN] 判定用户结束说话时触发的回调。
 */
- (void)setupSpeakStart:(TSSCOSpeakStartBlock)speakStart
                    data:(TSSCOSpeakDataBlock)data
                speakEnd:(TSSCOSpeakEndBlock)speakEnd;

@end

NS_ASSUME_NONNULL_END
