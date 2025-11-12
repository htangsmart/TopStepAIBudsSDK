#import "TSVoiceActivityDetector.h"

@interface TSVoiceActivityDetector ()

@end

@implementation TSVoiceActivityDetector

- (instancetype)init {
    self = [super init];
    if (self) {
        _silenceThreshold = 0.01f;
        _isSpeaking = NO;
    }
    return self;
}

- (void)reset {
    self.isSpeaking = NO;
}

- (BOOL)isSpeaking{
    return _isSpeaking;
}

- (BOOL)speakStateWithBuffer:(AudioBuffer)audioBuffer frameCount:(UInt32)frameCount{
    
    // 验证输入参数
    if (audioBuffer.mData == NULL || frameCount == 0) {
        return NO;
    }
    // 验证数据长度是否足够
    UInt32 expectedBytes = frameCount * sizeof(int16_t);
    if (audioBuffer.mDataByteSize < expectedBytes) {
        // 数据长度不足，使用实际可用的帧数
        frameCount = audioBuffer.mDataByteSize / sizeof(int16_t);
        if (frameCount == 0) {
            return NO;
        }
    }
    float power = [self.class calculateAudioPower:audioBuffer frameCount:frameCount];
//    NSLog(@"----- power = %f",power);
    return power >= self.silenceThreshold;
}

- (BOOL)speakStateWithPCMData:(NSData *)data format:(TSVADPCMFormat)format channels:(UInt32)channels{
    if (data.length == 0 || channels == 0) {
        return NO;
    }
    // 1. 计算音频功率
    float power = [self powerFromPCMData:data format:format channels:channels];

    NSLog(@"----- power = %f",power);
    return power >= self.silenceThreshold;
}

#pragma mark - Power Calculation

/**
 * 计算PCM数据的音频功率
 * @param data PCM数据
 * @param format 音频格式
 * @param channels 声道数
 * @return 音频功率值
 */
- (float)powerFromPCMData:(NSData *)data format:(TSVADPCMFormat)format channels:(UInt32)channels {
    if (data.length == 0 || channels == 0) {
        return 0.0f;
    }

    const NSUInteger length = data.length;
    float power = 0.0f;

    switch (format) {
        case TSVADPCMFormatInt16LE:
        case TSVADPCMFormatInt16BE: {
            // Treat as int16; swap bytes if BE on little-endian arch
            BOOL needSwap = NO;
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
            needSwap = (format == TSVADPCMFormatInt16BE);
#else
            needSwap = (format == TSVADPCMFormatInt16LE);
#endif
            const NSUInteger sampleCount = length / sizeof(int16_t);
            const int16_t *src = (const int16_t *)data.bytes;
            double sum = 0.0;
            for (NSUInteger i = 0; i < sampleCount; i += channels) {
                int16_t s = src[i];
                if (needSwap) {
                    uint16_t u = (uint16_t)s;
                    u = (u >> 8) | (u << 8);
                    s = (int16_t)u;
                }
                float sample = (float)s / 32768.0f;
                sum += fabsf(sample);
            }
            power = (float)(sum / (double)(sampleCount / channels ?: 1));
            break;
        }
        case TSVADPCMFormatFloat32LE:
        case TSVADPCMFormatFloat32BE: {
            BOOL needSwap = NO;
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
            needSwap = (format == TSVADPCMFormatFloat32BE);
#else
            needSwap = (format == TSVADPCMFormatFloat32LE);
#endif
            const NSUInteger sampleCount = length / sizeof(Float32);
            const Float32 *src = (const Float32 *)data.bytes;
            double sum = 0.0;
            for (NSUInteger i = 0; i < sampleCount; i += channels) {
                Float32 f = src[i];
                if (needSwap) {
                    uint32_t u;
                    memcpy(&u, &f, sizeof(u));
                    u = (u >> 24) | ((u >> 8) & 0x0000FF00) | ((u << 8) & 0x00FF0000) | (u << 24);
                    memcpy(&f, &u, sizeof(f));
                }
                float sample = f; // assume normalized -1..1
                sum += fabsf(sample);
            }
            power = (float)(sum / (double)(sampleCount / channels ?: 1));
            break;
        }
        default:
            return 0.0f;
    }
    
    return power;
}


+ (float)calculateAudioPower:(AudioBuffer)audioBuffer frameCount:(UInt32)frameCount {
    if (audioBuffer.mData == NULL || frameCount == 0) {
        return 0.0f;
    }
    
    // 验证数据长度 - 重要：确保有足够的数据
    UInt32 expectedBytes = frameCount * sizeof(int16_t);
    UInt32 actualBytes = MIN(audioBuffer.mDataByteSize, expectedBytes);
    UInt32 actualFrameCount = actualBytes / sizeof(int16_t);
    
    if (actualFrameCount == 0) {
        return 0.0f;
    }
    
    int16_t *samples = (int16_t *)audioBuffer.mData;
    
    float sum = 0.0f;
    for (UInt32 i = 0; i < actualFrameCount; i++) {
        float sample = (float)samples[i] / 32768.0f;
        sum += fabsf(sample);
    }
    float power = sum / (float)actualFrameCount;
    
    return power;
}

@end


