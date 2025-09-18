//
//  StarburstSdk.h
//  VoiceDemo
//
//  Created by incar on 2024/9/12.
//

#import <Foundation/Foundation.h>
#import <StarburstSdk/StarburstAsrConfig.h>
#import <StarburstSdk/StarburstAsrModel.h>
#import <StarburstSdk/StarbaustVoiceChatModel.h>
#import <StarburstSdk/StarburstFileAsrModel.h>
#import <StarburstSdk/StarburstOffLineFile.h>
#import <StarburstSdk/StarburstStreamModel.h>
#import <StarburstSdk/StarbusrtSpeaker.h>
#import <StarburstSdk/StartburstDecoderConfig.h>

typedef NS_OPTIONS(NSInteger,StarburstCode) {
    StarburstCode_Start_Record = 20001,///开始录音
    StarburstCode_Stop_Record = 20002,///停止录音
    StarburstCode_Record_Error = 20003,///录音出错
    StarburstCode_Ble_Disconected = 20004,///蓝牙断开
    StarburstCode_Websocket_Connected = 30001,///socket连上
    StarburstCode_Websocket_Disconnected = 30002,///socket断开连接
    StarburstCode_Websocket_Connecting = 30003,///socket连接中...
    StarburstCode_Websocket_pingTimeOut = 30004,///ping超时
    StarburstCode_Net_Error = 50000,///网络错误
    StarburstCode_UnAuth = 60000,///未鉴权
};


@interface StarburstSdk : NSObject
//@property (nonatomic, strong)void (^authSuccessCallback)(void);/// 鉴权成功回调
@property (nonatomic, strong)void (^authCallback)(int code,NSString *msg);/// 鉴权结果回调，code200代表成功，其他为失败
@property (nonatomic, readonly)BOOL didAuth;// 是否已经鉴权
@property (nonatomic, strong)void (^websocketStateCallback)(BOOL connected);/// websocket状态回调,true为已连接，false未链接
@property (nonatomic, strong)void (^bleRecordStateCallback)(int state);/// 耳机录音状态回调,1录音，2结束录音
@property (nonatomic, strong)void (^sendToBleCallback)(NSData *data);/// 发送给蓝牙设备

/// 单利
+ (instancetype)shared;

/// 收到蓝牙设备传过来的数据，交给sdk处理
/// - Parameter data:数据
- (void)receiveBleData:(NSData *)data;

/// 蓝牙设备已经连上（蓝牙连接和断开都需要通知sdk）
- (void)bleConnected;

/// 蓝牙断开连接（在监听到蓝牙断开的时候，调用该方法通知sdk结束当前任务）
- (void)bleDisConnected;

///// 【文本摘要】
///// - Parameters:
/////   - text: 识别的文本
/////   - recognize: 识别结果回调
/////   - error: 错误回调
- (void)summaryByText:(NSString *)text config:(StarburstAsrFileConfig*)config recognizeText:(void (^)(StarburstFileAsrModel*))recognize error:(void (^)(NSError *err))error;

/// 【文本摘要】--流式
/// - Parameters:
///   - text: 摘要的文字
///   - recognize: 结果回调
///   - error: 错误回调
- (void)summaryByTextWithSplit:(NSString *)text recognizeText:(void (^)(StarburstStreamModel*))recognize error:(void (^)(NSError *err))error;

/// 取消 【文本摘要】--流式
-(void)cancelSummaryByTextWithSplit;

/// 【文本翻译】
/// - Parameters:
///   - text: 翻译的文字
///   - config: 翻译配置
///   - recognize: 识别结果回调
///   - error: 错误回调
- (void)translateByText:(NSString *)text config:(StarburstAsrFileConfig*)config recognizeText:(void (^)(StarburstFileAsrModel*))recognize error:(void (^)(NSError *err))error;

/// 【文本翻译】--流式
/// - Parameters:
///   - text: 翻译的文字
///   - config: 翻译配置
///   - recognize: 结果回调
///   - error: 错误回调
- (void)translateByTextWithSplit:(NSString *)text config:(StarburstTslConfig*)config recognizeText:(void (^)(StarburstStreamModel*))recognize error:(void (^)(NSError *err))error;


/// 取消 【文本翻译】--流式
-(void)cancelTranslateByTextWithSplit;

/// 【同声传译】开始手机拾音
/// - Parameters:
///   - config: 识别配置
///   - voiceRecordData: 录音音频流回调
///   - recognizeText: 识别回调
///   - stateChange: 状态回调
///   - interrupt:打断回调（接听电话等打断）
- (void)startRecordAsr:(StarburstAsrConfig*)config voiceRecord:(void (^)(NSData*))voiceData recognizeText:(void (^)(StarburstAsrModel*))recognize stateChange:(void(^)(StarburstCode code))stateChange interruption:(void(^)(void))interrupt;

/// 【同声传译】结束手机拾音
/// - Parameter fileCallback: 录音文件回调
- (void)stopRecordAsr:(void(^)(NSString *filePath))callback;

/// 开始耳机拾音
/// - Parameters:
///   - config: 识别配置
- (void)startDeviceRecord:(StarburstBleAsrConfig*)config;

/// 结束耳机拾音
- (void)stopDeviceRecord;

/// 设置耳机拾音回调
/// - Parameters:
///   - recordPath: 录音文件保存的路径。如果文件已经存在，则音频数据会追加到尾部；如果不存在，则创建新文件；传nil则会按之前时间格式创建新文件
///   - asrConfig: 识别配置
///   - bleConfig: 耳机录音类型回调
///   - recognize: 识别回调
///   - stateChange: 状态回调
///   - path: 录音结束，录音文件地址回调
- (void)setupDeviceRecordWith:(NSString *)recordPath asrConfig:(StarburstAsrConfig*)asrConfig bleConfig:(void (^)(StarburstBleAsrConfig*))bleConfig recognizeText:(void (^)(StarburstAsrModel*))recognize stateChange:(void(^)(StarburstCode code))stateChange finished:(void(^)(NSString *filePath))path;


/// opus输出给app，app解码后将数据通过inputPcmData传回给sdk
- (void)outputOpusData:(void (^)(StartburstDecoderConfig *copusConfig,NSData*opusData))recordCallBack;

/// opus解码后传给sdk
- (void)inputPcmData:(NSData *)pcmData;





/// 获取音色列表
/// - Parameter callBack: 结果回调
- (void)getVcSpeekerList:(void (^)(NSArray <StarbusrtSpeaker*> *list,BOOL success))callBack;

///  设置voice chat回调,目前只支持蓝牙设备发起对话
/// - Parameters:
///   - config: 对话配置
///   - startCallBack: 开始回调
///   - textCallBack: 文本识别回调
///   - voiceCallBack: AI语音回复回调
///   - stateChange: 状态回调
///   - finished：录音地址回调
- (void)setupVoiceChatWith:(StarburstVoiceChatConfig*)config start:(void (^)(NSInteger dialogId))startCallback textCallback:(void (^)(StarbaustVoiceChatModel*))textCallBack  responseVoice:(void (^)(NSInteger dialogId,NSData*data,BOOL finish))voiceCallBack stateChange:(void(^)(StarburstCode code))stateChange finished:(void(^)(NSString *filePath))path;

/// 终止voice chat对话
- (void)stopVoiceChat:(NSInteger)dialogId;

/// 开始播放tts
- (void)startPlayTtsAudio:(NSInteger)dialogId;

/// 结束播放tts
- (void)stopPlayTtsAudio:(NSInteger)dialogId;

///  发送文字对话
/// - Parameters:
///   - text: 对话的文字
///   - isTts: 是否tts
- (void)sendVoiceChat:(NSString *)text tts:(BOOL)isTts;


//不可用
- (void)setupPhoneChatWith:(StarburstVoiceChatConfig*)config start:(void (^)(NSInteger dialogId))startCallback textCallback:(void (^)(StarbaustVoiceChatModel*))textCallBack  responseVoice:(void (^)(NSInteger dialogId,NSData*data,BOOL finish))voiceCallBack stateChange:(void(^)(StarburstCode code))stateChange finished:(void(^)(NSString *filePath))path;
//不可用
- (void)startPhoneChat:(int)vadType;
//不可用
- (void)stopPhoneChat;
//不可用
- (void)registerWithProductKey:(NSString *)productKey productSecret:(NSString *)productSecret deviceName:(NSString *)deviceName random:(NSString *)random finished:(void (^)(NSString *deviceSecret,NSError *error))finished;
//不可用
- (void)connectWithProductKey:(NSString *)productKey  deviceName:(NSString *)deviceName deviceSecret:(NSString *)deviceSecret finished:(void (^)(BOOL isSuccess,NSError *error))finished;
@end

