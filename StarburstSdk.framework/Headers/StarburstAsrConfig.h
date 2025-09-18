//
//  StarburstAsrConfig.h
//  StarburstSdk
//
//  Created by incar on 2024/9/14.
//

#import <Foundation/Foundation.h>

//语言
//简体中文 zh-CN
//四川话 sc
//粤语 cant
//上海话 zh_shanghai
//英文  en-US
//日语 ja-JP
//韩语 ko-KR
//法语 fr-FR
//西班牙语 es-MX
//葡萄牙语 pt-BR
//印尼语 id-ID
//俄语 ru-RU
//马来语 ms-MY

/// voice chat配置
@interface StarburstVoiceChatConfig : NSObject
@property (nonatomic, strong) NSString *role;/// 对话⻆⾊设定；默认为⽆特⾊的智能助⼿
//@property (nonatomic, assign) int channel;/// 默认为1，只⽀持1：单声道、2：双声道
@property (nonatomic, strong) NSString *language;/// 语⾔编码，默认为普通话(zh-CN)
@property (nonatomic, assign) BOOL tts;/// 是否进⾏Tts，默认false
@property (nonatomic, strong) NSString *ttsAudioFormat;/// 默认pcm。⽀持pcm / ogg_opus / mp3
@property (nonatomic, strong) NSString *ttsSpeakerType;/// tts声⾊类型，仅当传"clone"时，ttsSpeaker为单⾊克隆⽣成的speakerId
@property (nonatomic, strong) NSString *ttsSpeakerId;/// tts声⾊设置，默认使⽤“⾃然⼥声”
@end

/// 手机录音asr配置
@interface StarburstAsrConfig : NSObject
@property (nonatomic, assign) BOOL isTranslate;/// 是否翻译，默认false。如果为true翻译源语言和目标语言不能是同一种语言
@property (nonatomic, strong) NSString *fromLanguage;/// 语⾔编码，默认为普通话(zh-CN)，auto_lang自动识别
@property (nonatomic, strong) NSString *toLanguage;/// ⽬标语⾔编码，默认为英语(en-US)，auto_lang自动识别
@property (nonatomic, assign) BOOL isTTs;/// 是否进⾏Tts，默认false
@property (nonatomic, strong) NSString *ttsFormat;/// 默认pcm ⽀持pcm / ogg_opus / mp3
@property (nonatomic, strong) NSString *ttsType;/// 默认只⽀持"stream"，
@property (nonatomic, strong) NSString *ttsSpeaker;/// tts声⾊设置
@end

/// 蓝牙耳机录音asr配置
@interface StarburstBleAsrConfig : NSObject
@property (nonatomic, assign) NSInteger type;/// 0x00实时录音，0x0c通话录音,其他待定
@end

/// 文件/文本asr配置
@interface StarburstAsrFileConfig : NSObject
@property (nonatomic, assign) BOOL isTranslate;/// 是否翻译，默认false
@property (nonatomic, strong) NSString *fromLanguage;/// 语⾔编码
@property (nonatomic, strong) NSString *toLanguage;/// ⽬标语⾔编码
@property (nonatomic, assign) BOOL summary;/// 是否进行总结，默认false
@property (nonatomic, assign) BOOL speakerSplit;/// 是否区分说话人，默认false
@end


/// 翻译配置
@interface StarburstTslConfig : NSObject
@property (nonatomic, strong) NSString *fromLanguage;/// 语⾔编码
@property (nonatomic, strong) NSString *toLanguage;/// ⽬标语⾔编码
@end
