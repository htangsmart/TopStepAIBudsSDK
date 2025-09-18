//
//  StarburstAsrModel.h
//  StarburstSdk
//
//  Created by incar on 2024/9/13.
//

#import <Foundation/Foundation.h>

/// 翻译结果
@interface StarburstTranslateResult : NSObject
@property (nonatomic, strong) NSString *text;/// 语⾳识别后翻译的结果⽚段
@property (nonatomic, assign) BOOL definite;/// 当前翻译⽚段是否确定
@property (nonatomic, assign) int definiteIndex;/// 已翻译⽚段序号
@end

/// tts音频流
@interface StarburstAsrTtsResult : NSObject
@property (nonatomic, assign) NSInteger index;/// 音频数据⽚段的序号
@property (nonatomic, assign) NSInteger translateIndex;/// 翻译的序号
@property (nonatomic, strong) NSString *streamPiece;/// 音频流
@end


/// 识别结果
@interface StarburstAsrModel : NSObject
@property (nonatomic, assign) NSInteger channel;/// 0非立体声，1左声道，2右声道
@property (nonatomic, assign) NSInteger code;/// 状态码
@property (nonatomic, strong) NSString *msg;/// 提示语
@property (nonatomic, strong) NSString *requestId;/// 请求id
@property (nonatomic, strong) NSString *textResult;/// 语⾳识别结果⽚段内容
@property (nonatomic, assign) NSInteger sequence;/// 响应的编号
@property (nonatomic, assign) BOOL definite;/// 语⾳识别结果⽚段是否已确定，后序不会有变化
@property (nonatomic, assign) NSInteger definiteIndex;/// 已确定的识别结果序列号
@property (nonatomic, assign) BOOL isLastPackage;//是否为最后一包，后续没有数据(包括asr、tts、翻译结果)
@property (nonatomic, strong) StarburstTranslateResult *translateResult;///翻译结果
@property (nonatomic, strong) StarburstAsrTtsResult *ttsResult;///tts音频流

+ (StarburstAsrModel *)modelWith:(NSDictionary *)dict;
@end

