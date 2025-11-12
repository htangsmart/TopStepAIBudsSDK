#import "TSSCOAudioCaptureManager.h"
#import "TSVoiceActivityDetector.h"
#import "TSSCOAudioFileManager.h"

NSErrorDomain const TSSCOAudioErrorDomain = @"com.aibuds.scoaudio";

// 在静态回调之前做方法前向声明，确保编译器可见
@class TSSCOAudioCaptureManager;

@interface TSSCOAudioCaptureManager (CallbackAccessors)

- (TSSCOSpeakStartBlock)onSpeakStartBlock;
- (TSSCOSpeakDataBlock)onDataBlock;
- (TSSCOSpeakEndBlock)onSpeakEndBlock;

- (AudioComponentInstance)getAudioCaptureInstance;
// 保留方法声明以兼容静态回调，内部改为委托给 VAD
- (BOOL)speakStateWithBuffer:(AudioBuffer)audioBuffer frameCount:(UInt32)frameCount;

////// 文件管理器访问方法，供静态回调使用
- (TSSCOAudioFileManager *)getFileManager;

// 音频数据打印方法，供静态回调使用
- (void)logPCMData:(NSData *)pcmData frames:(UInt32)frames;

@end

#pragma mark - C static input callback
static OSStatus TSSCOInputCallback(void *inRefCon,
                                   AudioUnitRenderActionFlags *ioActionFlags,
                                   const AudioTimeStamp *inTimeStamp,
                                   UInt32 inBusNumber,
                                   UInt32 inNumberFrames,
                                   AudioBufferList *ioData) {
    @autoreleasepool {
        
//        NSLog(@"[SCO] 🔊 TSSCOInputCallback 被调用 - inNumberFrames: %u", inNumberFrames);
        
        TSSCOAudioCaptureManager *manager = (__bridge TSSCOAudioCaptureManager *)inRefCon;
        if (!manager) {
            NSLog(@"[SCO] ❌ TSSCOInputCallback - manager 为 nil");
            return -1;
        }
        
        // ✅ 关键修复：提前检查 isCapturing 状态，避免访问已关闭的资源
        if (!manager.isCapturing) {
            // NSLog(@"[SCO] ⚠️ TSSCOInputCallback - 已停止采集，忽略回调");
            return noErr;
        }
        
        // 修复：正确创建 AudioBufferList
        AudioBufferList buffers;
        buffers.mNumberBuffers = 1;
        buffers.mBuffers[0].mNumberChannels = 1;
        buffers.mBuffers[0].mDataByteSize = inNumberFrames * 2; // 16-bit = 2 bytes per frame
        buffers.mBuffers[0].mData = malloc(inNumberFrames * 2); // 分配内存
        
        // 获取音频 PCM 数据
        OSStatus status = AudioUnitRender([manager getAudioCaptureInstance],
                                          ioActionFlags,
                                          inTimeStamp,
                                          inBusNumber,
                                          inNumberFrames,
                                          &buffers);
        
        if (status == noErr) {
//            NSLog(@"[SCO] ✅ AudioUnitRender 成功 - mDataByteSize: %u", buffers.mBuffers[0].mDataByteSize);
            // 检查数据有效性
            if (buffers.mBuffers[0].mData && buffers.mBuffers[0].mDataByteSize > 0) {
//                NSLog(@"[SCO] ✅ 收到有效音频数据 - frames: %u", inNumberFrames);
                // 修复：使用实际帧数计算数据长度，而不是预设的 mDataByteSize
                UInt32 actualDataLength = inNumberFrames * sizeof(int16_t); // 16-bit = 2 bytes
                
                // 创建 NSData 并立即拷贝数据，避免内存被提前释放
                NSData *originalData = [NSData dataWithBytes:buffers.mBuffers[0].mData
                                                      length:actualDataLength];
                
                // 为所有回调创建独立的数据副本，确保数据一致性
                NSData *pcmData = [originalData copy];
                
                
                // 打印 PCM 数据详情（使用独立副本）
                [manager logPCMData:pcmData frames:inNumberFrames];
                
                // ✅ 修复：所有数据都保存到SDK音频文件（直接在回调线程保存，避免异步导致的竞态）
                // 不需要在主线程，文件写入是线程安全的
                [[manager getFileManager] savePCMDataToSDKFile:pcmData];
                
                NSDate *now = [NSDate date];
                // 根据voiceActivityDetectionEnabled状态分两个执行路径
                if (manager.voiceActivityDetectionEnabled) {
                    // 路径1：启用语音活动检测
                    // 为语音活动检测创建独立的数据副本，确保数据一致性
                    BOOL isSpeaking = [manager speakStateWithPCMData:pcmData frameCount:inNumberFrames];
                    if (isSpeaking) {
                        manager.lastVoiceDate = now;
                        if (manager.vadState == TSVADStateSilence||
                            manager.vadState ==  TSVADStateSpeakingEnd) {// 开始说话
                            // 创建临时音频文件 (Document/SDKTempAudio)
                            [[manager getFileManager] createTempAudioFile];
                            // 通知回调
                            TSSCOSpeakStartBlock startBlock = [manager onSpeakStartBlock];
                            if (startBlock) {startBlock();}
                            
                            // 开始说话时也需要保存数据和触发回调
                            [[manager getFileManager] savePCMDataToTempFile:pcmData];
                            TSSCOSpeakDataBlock dataBlock = [manager onDataBlock];
                            if (dataBlock) { dataBlock(pcmData);}
                            
                            NSLog(@"[SCO Audio] speaking start");
                            manager.vadState = TSVADStateSpeakingStar;

                        }else{// 说话中
                            if (manager.vadState != TSVADStateSpeaking) {
                                // 打印一次就行
                                NSLog(@"[SCO Audio] speaking");
                            }
                            // 保存数据到临时文件（只保存说话时的数据）
                            [[manager getFileManager] savePCMDataToTempFile:pcmData];
                            // 然后触发数据回调
                            TSSCOSpeakDataBlock dataBlock = [manager onDataBlock];
                            if (dataBlock) { dataBlock(pcmData);}
                            manager.vadState = TSVADStateSpeaking;
                        }
                    }else{
                        // silenceTimeout时间范围内都算是speaking
                        if (manager.vadState == TSVADStateSpeaking) {
                            NSTimeInterval silenceDuration = [now timeIntervalSinceDate:manager.lastVoiceDate];
                            if (silenceDuration > manager.silenceTimeout) {
                                // 结束对话
                                // 静音超过超时时间，进入结束说话状态
                                TSSCOSpeakEndBlock endBlock = [manager onSpeakEndBlock];
                                if (endBlock) { endBlock();}
                                // 关闭临时音频文件
                                [[manager getFileManager] closeTempAudioFile];
                                
                                NSLog(@"[SCO Audio] speaking end");
                                manager.vadState = TSVADStateSpeakingEnd;
                            }else{
                                
                                // 仍然认为在speaking中
                                // 保存数据到临时文件（只保存说话时的数据）
                                [[manager getFileManager] savePCMDataToTempFile:pcmData];
                                // 然后触发数据回调
                                TSSCOSpeakDataBlock dataBlock = [manager onDataBlock];
                                if (dataBlock) { dataBlock(pcmData);}                                
                                manager.vadState = TSVADStateSpeaking;
                            }
                        }else{
                            // 静音中
//                            NSLog(@"[SCO Audio] speaking silence");
                            manager.vadState = TSVADStateSilence;
                        }
                    }
                    
                } else {
                    // 路径2：未启用语音活动检测，直接调用onDataBlock
                    dispatch_async(dispatch_get_main_queue(), ^{
                        TSSCOSpeakDataBlock dataBlock = [manager onDataBlock];
                        if (dataBlock) {
                            dataBlock(pcmData);
                        }
                    });
                }
            } else {
                NSLog(@"[SCO] ⚠️ 音频数据无效 - mData: %p, mDataByteSize: %u", buffers.mBuffers[0].mData, buffers.mBuffers[0].mDataByteSize);
            }
        } else {
            NSLog(@"[SCO] ❌ AudioUnitRender返回错误: status=%d", (int)status);
        }
        
        // 清理内存
        if (buffers.mBuffers[0].mData) {
            free(buffers.mBuffers[0].mData);
        }
        
        return status;
    }
}

@interface TSSCOAudioCaptureManager ()
@property (nonatomic, assign) AudioComponentInstance audioCaptureInstance; // 音频采集实例
@property (nonatomic, assign) AudioStreamBasicDescription audioFormat; // 音频采集参数
@property (nonatomic, strong) AVAudioSession *audioSession;
@property (nonatomic, assign) double preferredSampleRate;
@property (nonatomic, assign) BOOL preferBluetooth;
@property (nonatomic, strong) dispatch_queue_t captureQueue;
@property (nonatomic, copy) TSSCOErrorBlock onError;
@property (nonatomic, assign) BOOL isError;

// 重新声明 capturing 为 readwrite，覆盖 .h 文件中的 readonly
@property (nonatomic, assign, readwrite, getter=isCapturing) BOOL capturing;


// 回调相关属性
@property (nonatomic, copy) TSSCOSpeakStartBlock onSpeakStartBlock;
@property (nonatomic, copy) TSSCOSpeakDataBlock onDataBlock;
@property (nonatomic, copy) TSSCOSpeakEndBlock onSpeakEndBlock;




// 文件管理器（重新声明为 readwrite，覆盖头文件中的 readonly）
@property (nonatomic, strong, readwrite) TSSCOAudioFileManager *fileManager;

@end

@implementation TSSCOAudioCaptureManager


- (instancetype)init {
    self = [super init];
    if (self) {
        _captureQueue = dispatch_queue_create("com.aibuds.scoaudio.capture", DISPATCH_QUEUE_SERIAL);
        // 使用属性访问器而不是直接访问实例变量
        self.capturing = NO;
        // 修复：使用与 AudioRecorder 一致的采样率
        _preferredSampleRate = 16000.0; // 16kHz，与 AudioRecorder 一致
        _preferBluetooth = YES;
        _audioSession = [AVAudioSession sharedInstance];
        _isError = NO;
        
        // 初始化静音检测相关属性
        _silenceThreshold = 0.01; // 默认静音阈值，从耳机获取时可能需要调整
        _silenceTimeout = 2.0; // 默认静音超时2秒
        _recordStopTimeout = 0.0; // 默认禁用自动停止功能
        _voiceActivityDetectionEnabled = YES; // 默认启用语音活动检测
        _isSpeaking = NO;
        _lastVoiceDate = nil;

        _vadState = TSVADStateSilence;
        // 文件管理器采用延迟初始化，在首次访问时才创建
        _fileManager = [[TSSCOAudioFileManager alloc] init];
        
        // 初始化 VAD，并与公开属性联动
        
        _vad = [[TSVoiceActivityDetector alloc] init];
        _vad.silenceThreshold = _silenceThreshold;
    }
    return self;
}

#pragma mark - Property syncing to VAD

- (void)setSilenceThreshold:(float)silenceThreshold {
    _silenceThreshold = silenceThreshold;
    self.vad.silenceThreshold = silenceThreshold;
}

- (void)setSilenceTimeout:(float)silenceTimeout {
    _silenceTimeout = silenceTimeout;
}

- (void)setRecordStopTimeout:(float)recordStopTimeout {
    _recordStopTimeout = recordStopTimeout;
}


- (void)dealloc {
    // 关闭文件句柄
    [_fileManager closeAllFiles];
    
    // 清理音频采集实例
    if (_audioCaptureInstance) {
        AudioOutputUnitStop(_audioCaptureInstance);
        AudioComponentInstanceDispose(_audioCaptureInstance);
        _audioCaptureInstance = nil;
    }
}

#pragma mark - Public API

- (void)startCapturePreferBluetooth:(BOOL)preferBluetooth
                         sampleRate:(double)sampleRate
                            success:(nullable TSSCOSuccessBlock)success
                            failed:(nullable TSSCOErrorBlock)failed {
    NSLog(@"startCapturePreferBluetooth");
    if (self.isError) {
        if (failed) {
            NSError *error = [NSError errorWithDomain:TSSCOAudioErrorDomain
                                                          code:-1
                                             userInfo:@{NSLocalizedDescriptionKey:@"Microphone permissiondenied"}];
            failed(error);
        }
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    
    
    dispatch_sync(self.captureQueue, ^{
        if (weakSelf.capturing) { return; }
        
        weakSelf.onError = failed;
        weakSelf.preferBluetooth = preferBluetooth;
        weakSelf.preferredSampleRate = (sampleRate > 0 ? sampleRate : 16000.0);
        
        NSError *error = nil;
        if (![weakSelf requestMicrophonePermissionSync:&error]) {
            if (weakSelf.onError) {
                weakSelf.onError(error ?: [NSError errorWithDomain:TSSCOAudioErrorDomain
                                                              code:-1
                                                          userInfo:@{NSLocalizedDescriptionKey:@"Microphone permission denied"}]);
            }
            return;
        }
        
        NSLog(@"startCapturePreferBluetooth");
        // 修复：启动前检查并清理音频会话状态，避免状态污染
        [weakSelf ensureCleanAudioSessionState];
        
        if (![weakSelf configureAudioSession:&error]) {
            if (weakSelf.onError) {
                weakSelf.onError(error ?: [NSError errorWithDomain:TSSCOAudioErrorDomain
                                                              code:-2
                                                          userInfo:@{NSLocalizedDescriptionKey:@"Failed to configure AVAudioSession"}]);
            }
            return;
        }
        
        // 修复：每次启动都重新创建音频采集实例，确保状态干净
        if (weakSelf.audioCaptureInstance) {
            // 如果存在旧实例，先清理
            AudioOutputUnitStop(weakSelf.audioCaptureInstance);
            AudioUnitUninitialize(weakSelf.audioCaptureInstance);
            AudioComponentInstanceDispose(weakSelf.audioCaptureInstance);
            weakSelf.audioCaptureInstance = nil;
        }
        
        // 创建新的音频采集实例
        [weakSelf setupAudioCaptureInstance:&error];
        if (error) {
            if (weakSelf.onError) {
                weakSelf.onError(error);
            }
            return;
        }
        
        // 开始采集
        NSLog(@"[SCO] 🎤 准备启动音频采集...");
        OSStatus startStatus = AudioOutputUnitStart(weakSelf.audioCaptureInstance);
        if (startStatus != noErr) {
            NSLog(@"[SCO] ❌ 音频采集启动失败: %d", (int)startStatus);
            if (weakSelf.onError) {
                weakSelf.onError([NSError errorWithDomain:TSSCOAudioErrorDomain
                                                     code:startStatus
                                                 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"AudioUnit start failed: %d", (int)startStatus]}]);
            }
            return;
        }
        NSLog(@"[SCO] ✅ 音频采集启动成功！等待 TSSCOInputCallback 回调...");
        weakSelf.capturing = YES;
        // 启动前重置 VAD 状态
        [weakSelf.vad reset];
        NSLog(@"[SCO] VAD 状态已重置");

        // 创建SDK音频文件 (Document/SDKAudio)
        [self.fileManager createSDKAudioFile];
        
        if (success) {
            success();
        }
    });
}

- (void)stopCapture {
    
    if (self.isError) {return;}
    
    // ✅ 关键修复：立即设置 capturing = NO，阻止新的回调继续执行
    self.capturing = NO;
    NSLog(@"[SCO] 🛑 stopCapture - 已设置 capturing = NO");
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.captureQueue, ^{
        if (weakSelf.audioCaptureInstance) {
            // 停止采集
            OSStatus stopStatus = AudioOutputUnitStop(weakSelf.audioCaptureInstance);
            
            // 修复：完全清理音频单元资源
            OSStatus uninitStatus = AudioUnitUninitialize(weakSelf.audioCaptureInstance);
            OSStatus disposeStatus = AudioComponentInstanceDispose(weakSelf.audioCaptureInstance);
            
            weakSelf.audioCaptureInstance = nil;
            
            // 记录清理状态
            NSLog(@"[SCO] Audio unit cleanup - Stop: %d, Uninit: %d, Dispose: %d",
                  (int)stopStatus, (int)uninitStatus, (int)disposeStatus);
            
            if (stopStatus != noErr) {
                [weakSelf callBackError:[NSError errorWithDomain:TSSCOAudioErrorDomain
                                                            code:stopStatus
                                                        userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"AudioUnit stop failed: %d", (int)stopStatus]}]];
            }
        }
        
        // 重置音频会话状态，避免状态污染
        [weakSelf resetAudioSessionState];
        
        // ✅ 延迟关闭文件，等待可能还在执行的音频回调完成
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSLog(@"[SCO] 🔒 延迟关闭音频文件");
            [weakSelf.fileManager closeAllFiles];
        });
        
        // weakSelf.capturing = NO;  // 已在外面设置
        weakSelf.onError = nil;
    });
}

#pragma mark - Private helpers

// 添加公共访问方法，供静态C函数调用
- (AudioComponentInstance)getAudioCaptureInstance {
    return _audioCaptureInstance;
}


//// 添加文件管理器访问方法，供静态C函数调用
- (TSSCOAudioFileManager *)getFileManager {
    return self.fileManager;
}

// fileManager 的懒加载（延迟初始化）
- (TSSCOAudioFileManager *)fileManager {
    if (!_fileManager) {
        _fileManager = [[TSSCOAudioFileManager alloc] init];
        NSLog(@"[SCO] 延迟创建文件管理器实例");
    }
    return _fileManager;
}

/**
 * 打印PCM音频数据详情
 * @param pcmData PCM数据
 * @param frames 帧数
 */
- (void)logPCMData:(NSData *)pcmData frames:(UInt32)frames {
    if (!pcmData || pcmData.length == 0) {
        NSLog(@"[SCO] PCM数据为空");
        return;
    }
    // 基础信息
//    NSUInteger dataLength = pcmData.length;
    
    // 格式化输出
//    NSLog(@"[SCO] ═══════════════════════════════════════════════════");
//    NSLog(@"[SCO] PCM数据详情:");
//    NSLog(@"[SCO] ├─ 数据长度: %lu bytes", (unsigned long)dataLength);
//    NSLog(@"[SCO] └─ 数据预览: %@...", [self hexStringFromData:pcmData maxLength:pcmData.length]);
//    NSLog(@"[SCO] ═══════════════════════════════════════════════════");
}

/**
 * 将数据转换为十六进制字符串预览（每4字节一组，用空格分隔）
 * @param data 数据
 * @param maxLength 最大长度
 * @return 十六进制字符串（格式：9954ee41 d03ed932 0e2e4835...）
 */
- (NSString *)hexStringFromData:(NSData *)data maxLength:(NSUInteger)maxLength {
    if (!data || data.length == 0) {
        return @"<empty>";
    }
    
    NSUInteger length = MIN(data.length, maxLength);
    const unsigned char *bytes = data.bytes;
    NSMutableString *hexString = [NSMutableString string];
    
    // 按4字节分组处理
    for (NSUInteger i = 0; i < length; i += 4) {
        // 添加空格分隔（除了第一组）
        if (i > 0) {
            [hexString appendString:@" "];
        }
        
        // 处理当前4字节组（可能不足4字节）
        NSUInteger groupEnd = MIN(i + 4, length);
        for (NSUInteger j = i; j < groupEnd; j++) {
            [hexString appendFormat:@"%02x", bytes[j]];
        }
    }
    
    if (data.length > maxLength) {
        [hexString appendString:@"..."];
    }
    
    return hexString;
}

/**
 * 重置音频会话状态，避免状态污染
 * 在stopCapture时调用，确保下次启动时状态干净
 */
- (void)resetAudioSessionState {
    // 重置音频会话到默认状态，避免状态污染
    NSError *error = nil;
    
    // 1. 停用音频会话
    BOOL deactivateResult = [self.audioSession setActive:NO error:&error];
    
    // 2. 重置音频会话类别到默认状态
    BOOL categoryResult = [self.audioSession setCategory:AVAudioSessionCategoryPlayback error:&error];
    
    // 3. 清除首选输入设置
    [self.audioSession setPreferredInput:nil error:nil];
    
    NSLog(@"[SCO] 音频会话状态已重置 - Deactivate: %@, Category: %@",
          deactivateResult ? @"成功" : @"失败",
          categoryResult ? @"成功" : @"失败");
}

/**
 * 启动前状态检查，确保音频会话处于干净状态
 * 避免状态污染影响音频采集
 */
- (void)ensureCleanAudioSessionState {
    // 确保音频会话处于干净状态，避免状态污染
    
    // 1. 检查当前音频会话状态
    NSLog(@"[SCO] 当前音频会话状态检查:");
    NSLog(@"[SCO] - Category: %@", self.audioSession.category);
    NSLog(@"[SCO] - Mode: %@", self.audioSession.mode);
    NSLog(@"[SCO] - Active: %@", self.audioSession.isOtherAudioPlaying ? @"其他音频播放中" : @"正常");
    NSLog(@"[SCO] - Current input: %@", self.audioSession.currentRoute.inputs);
    NSLog(@"[SCO] - Preferred input: %@", self.audioSession.preferredInput);
    
    // 2. 如果音频会话处于异常状态，先重置
    if ([self.audioSession.category isEqualToString:AVAudioSessionCategoryPlayAndRecord]) {
        NSLog(@"[SCO] 检测到音频会话可能处于污染状态，先重置");
        [self resetAudioSessionState];
        
        // 等待一小段时间让重置生效
        usleep(50000); // 50ms
    }
}

#pragma mark - Voice Activity Detection

- (BOOL)speakStateWithBuffer:(AudioBuffer)audioBuffer frameCount:(UInt32)frameCount {
    // 委托给独立 VAD 处理
    return [self.vad speakStateWithBuffer:audioBuffer frameCount:frameCount];
}

/**
 * 使用NSData进行语音活动检测，确保数据一致性
 * @param pcmData PCM数据
 * @param frameCount 帧数
 * @return 当前语音活动状态
 */
- (BOOL)speakStateWithPCMData:(NSData *)pcmData frameCount:(UInt32)frameCount {
    if (!pcmData || pcmData.length == 0) {
        return NO;
    }
    
    // 将NSData转换为AudioBuffer格式
    AudioBuffer audioBuffer;
    audioBuffer.mNumberChannels = 1;
    audioBuffer.mDataByteSize = (UInt32)pcmData.length;
    audioBuffer.mData = (void *)pcmData.bytes;
    
    // 委托给独立 VAD 处理
    return [self.vad speakStateWithBuffer:audioBuffer frameCount:frameCount];
}


- (void)setupAudioCaptureInstance:(NSError **)error {
    // 1、设置音频组件描述
    AudioComponentDescription acd = {
        .componentType = kAudioUnitType_Output,
        .componentSubType = kAudioUnitSubType_RemoteIO,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0,
    };
    
    // 2、查找符合指定描述的音频组件
    AudioComponent component = AudioComponentFindNext(NULL, &acd);
    if (!component) {
        *error = [NSError errorWithDomain:TSSCOAudioErrorDomain code:-50 userInfo:@{NSLocalizedDescriptionKey:@"Audio component not found"}];
        return;
    }
    
    // 3、创建音频组件实例
    OSStatus status = AudioComponentInstanceNew(component, &_audioCaptureInstance);
    if (status != noErr) {
        *error = [NSError errorWithDomain:TSSCOAudioErrorDomain code:status userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Failed to create audio component instance: %d", (int)status]}];
        return;
    }
    
    // 4、设置实例的属性：启用输入总线（bus 1）
    UInt32 enableIO = 1;
    status = AudioUnitSetProperty(_audioCaptureInstance,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  1,
                                  &enableIO,
                                  sizeof(enableIO));
    if (status != noErr) {
        *error = [NSError errorWithDomain:TSSCOAudioErrorDomain code:status userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Failed to enable input IO: %d", (int)status]}];
        return;
    }
    
    // 5、设置实例的属性：音频参数
    AudioStreamBasicDescription asbd = {0};
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    asbd.mChannelsPerFrame = 1; // 单声道
    asbd.mFramesPerPacket = 1;
    asbd.mBitsPerChannel = 16; // 16位
    asbd.mSampleRate = self.preferredSampleRate; // 使用设置的采样率
    
    asbd.mBytesPerFrame = asbd.mChannelsPerFrame * asbd.mBitsPerChannel / 8;
    asbd.mBytesPerPacket = asbd.mFramesPerPacket * asbd.mBytesPerFrame;
    
    self.audioFormat = asbd;
    
    // 设置输出格式（从输入总线获取数据）
    status = AudioUnitSetProperty(_audioCaptureInstance,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  1,
                                  &asbd,
                                  sizeof(asbd));
    if (status != noErr) {
        *error = [NSError errorWithDomain:TSSCOAudioErrorDomain code:status userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Failed to set stream format: %d", (int)status]}];
        return;
    }
    
    // 6、设置实例的属性：数据回调函数
    AURenderCallbackStruct cb;
    cb.inputProcRefCon = (__bridge void *)self;
    cb.inputProc = TSSCOInputCallback;
    status = AudioUnitSetProperty(_audioCaptureInstance,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Global,
                                  0,
                                  &cb,
                                  sizeof(cb));
    if (status != noErr) {
        *error = [NSError errorWithDomain:TSSCOAudioErrorDomain code:status userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Failed to set input callback: %d", (int)status]}];
        return;
    }
    
    // 7、初始化实例
    status = AudioUnitInitialize(_audioCaptureInstance);
    if (status != noErr) {
        *error = [NSError errorWithDomain:TSSCOAudioErrorDomain code:status userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Failed to initialize audio unit: %d", (int)status]}];
        return;
    }
    
    // 添加调试信息
    NSLog(@"[SCO] Audio unit configured:");
    NSLog(@"[SCO] - Sample rate: %f", asbd.mSampleRate);
    NSLog(@"[SCO] - Channels: %u", asbd.mChannelsPerFrame);
    NSLog(@"[SCO] - Bits per channel: %u", asbd.mBitsPerChannel);
    NSLog(@"[SCO] - Bytes per frame: %u", asbd.mBytesPerFrame);
}

- (BOOL)requestMicrophonePermissionSync:(NSError **)outError {
    __block BOOL granted = [[AVAudioSession sharedInstance] recordPermission] == AVAudioSessionRecordPermissionGranted;
    if (granted) return YES;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL g) {
        granted = g;
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
    if (!granted && outError) {
        *outError = [NSError errorWithDomain:TSSCOAudioErrorDomain code:-10 userInfo:@{NSLocalizedDescriptionKey:@"Microphone permission is not granted"}];
    }
    return granted;
}

- (BOOL)configureAudioSession:(NSError **)outError {
    NSError *error = nil;
    
    // Category: PlayAndRecord + AllowBluetooth 以允许HFP路由；A2DP不支持麦克风
    AVAudioSessionCategoryOptions opts = AVAudioSessionCategoryOptionAllowBluetooth;
    BOOL ok = [self.audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:opts error:&error];
    if (!ok) { if (outError) *outError = error; return NO; }
    
    ok = [self.audioSession setMode:AVAudioSessionModeVoiceChat error:&error]; // VoiceChat促使系统选用HFP/SCO
    if (!ok) { if (outError) *outError = error; return NO; }
    
    ok = [self.audioSession setPreferredSampleRate:self.preferredSampleRate error:&error];
    if (!ok) { if (outError) *outError = error; return NO; }
    
    // 修复：强制设置固定的缓冲区大小，避免系统自动调整
    // 使用较小的缓冲区大小以确保实时性和一致性
    ok = [self.audioSession setPreferredIOBufferDuration:0.016 error:&error]; // 16ms = 256 frames @ 16kHz
    if (!ok) { if (outError) *outError = error; return NO; }
    
    // 验证缓冲区大小设置
    NSLog(@"[SCO] 设置缓冲区大小: %f, 实际缓冲区大小: %f", 0.016, self.audioSession.IOBufferDuration);
    
    // 修复：强制选择蓝牙输入源
    if (self.preferBluetooth) {
        AVAudioSessionPortDescription *bluetoothInput = nil;
        for (AVAudioSessionPortDescription *input in self.audioSession.availableInputs) {
            if ([input.portType isEqualToString:AVAudioSessionPortBluetoothHFP]) {
                bluetoothInput = input;
                NSLog(@"[SCO] 找到蓝牙输入源: %@", input);
                break;
            }
        }
        
        if (bluetoothInput) {
            BOOL setInputResult = [self.audioSession setPreferredInput:bluetoothInput error:&error];
            if (setInputResult) {
                NSLog(@"[SCO] 成功设置蓝牙输入源: %@", bluetoothInput);
            } else {
                NSLog(@"[SCO] 设置蓝牙输入源失败: %@", error.localizedDescription);
            }
        }
    }
    
    ok = [self.audioSession setActive:YES error:&error];
    if (!ok) { if (outError) *outError = error; return NO; }
    
    NSLog(@"[SCO] 音频会话激活成功");
    
    // 修复：音频会话激活后再次确认蓝牙输入源选择
    if (self.preferBluetooth) {
        NSLog(@"[SCO] 开始双重确认蓝牙输入源选择");
        
        // 等待一小段时间让音频会话稳定
        usleep(100000); // 100ms
        
        // 再次尝试选择蓝牙输入源
        AVAudioSessionPortDescription *bluetoothInput = nil;
        for (AVAudioSessionPortDescription *input in self.audioSession.availableInputs) {
            if ([input.portType isEqualToString:AVAudioSessionPortBluetoothHFP]) {
                bluetoothInput = input;
                NSLog(@"[SCO] 双重确认找到蓝牙输入源: %@", input);
                break;
            }
        }
        
        if (bluetoothInput) {
            NSString *currentPreferredUID = self.audioSession.preferredInput.UID;
            NSString *bluetoothUID = bluetoothInput.UID;
            NSLog(@"[SCO] 当前首选输入UID: %@, 蓝牙输入UID: %@", currentPreferredUID, bluetoothUID);
            
            if (![currentPreferredUID isEqualToString:bluetoothUID]) {
                NSLog(@"[SCO] 音频会话激活后重新设置蓝牙输入源");
                BOOL setResult = [self.audioSession setPreferredInput:bluetoothInput error:nil];
                NSLog(@"[SCO] 重新设置蓝牙输入源结果: %@", setResult ? @"成功" : @"失败");
            } else {
                NSLog(@"[SCO] 蓝牙输入源已经是首选，无需重新设置");
            }
        } else {
            NSLog(@"[SCO] 双重确认未找到蓝牙输入源");
        }
    }
    return YES;
}

- (void)callBackError:(NSError *)error {
    self.isError = YES;
    if (error && self.onError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.onError(error);
        });
    }
}

- (TSSCOSpeakStartBlock)onSpeakStartBlock{
    return _onSpeakStartBlock;
}

- (TSSCOSpeakDataBlock)onDataBlock{
    return _onDataBlock;
}

- (TSSCOSpeakEndBlock)onSpeakEndBlock{
    return _onSpeakEndBlock;
}


- (void)setupSpeakStart:(TSSCOSpeakStartBlock)speakStart
                    data:(TSSCOSpeakDataBlock)data
                speakEnd:(TSSCOSpeakEndBlock)speakEnd{
    
    self.onSpeakStartBlock  = [speakStart copy];
    self.onDataBlock = [data copy];
    self.onSpeakEndBlock  = [speakEnd copy];
    
}


@end
