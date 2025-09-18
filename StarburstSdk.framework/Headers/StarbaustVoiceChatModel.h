//
//  StarbaustVoiceChatModel.h
//  StarburstSdk
//
//  Created by incar on 2024/11/22.
//

#import <Foundation/Foundation.h>
#import <StarburstSdk/StarburstAsrModel.h>

@interface StarbaustVoiceChatModel : NSObject
@property (nonatomic, assign) NSInteger code;/// 状态码,200成功
@property (nonatomic, strong) NSString *msg;/// 提示语
@property (nonatomic, strong) NSString *requestId;/// 请求id
@property (nonatomic, assign) NSInteger dialogId;/// 对话id
@property (nonatomic, assign) BOOL isAsrFinish;/// 识别是否已结束
@property (nonatomic, strong) NSString *textResult;/// 语⾳识别结果⽚段内容
@property (nonatomic, strong) NSString *responseText;/// 响应结果⽚段内容
@property (nonatomic, strong) NSString *intent;/// 意图
@property (nonatomic, assign) NSInteger sequence;/// 响应的编号
@property (nonatomic, assign) BOOL definite;/// 语⾳识别结果⽚段是否已确定，后序不会有变化
@property (nonatomic, assign) NSInteger definiteIndex;/// 已确定的识别结果序列号
//@property (nonatomic, assign) NSInteger conversationIndex;/// 已确定的响应结果序列号
@property (nonatomic, assign) BOOL conversationFinish;/// 对话是否结束
@property (nonatomic, strong) StarburstTranslateResult *translateResult;///翻译结果
@property (nonatomic, strong) StarburstAsrTtsResult *ttsResult;///tts音频流

@end

