#import "TSSCOAudioFileManager.h"

@interface TSSCOAudioFileManager ()

// SDK音频文件相关
@property (nonatomic, strong) NSString *sdkAudioFilePath;
@property (nonatomic, strong) NSFileHandle *sdkAudioFileHandle;

// 临时音频文件相关
@property (nonatomic, strong) NSString *tempAudioFilePath;
@property (nonatomic, strong) NSFileHandle *tempAudioFileHandle;

@end

@implementation TSSCOAudioFileManager

#pragma mark - Lifecycle

- (void)dealloc {
    [self closeAllFiles];
}

#pragma mark - SDK Audio File (Document/SDKAudio/)

/**
 * 创建SDK音频文件
 */
- (BOOL)createSDKAudioFile {
    // 关闭之前的文件句柄（如果有）
    [self closeSDKAudioFile];
    
    // 获取Document目录
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    
    // 创建SDKAudio目录
    NSString *sdkAudioDirectory = [documentsDirectory stringByAppendingPathComponent:@"SDKAudio"];
    if (![self createDirectoryIfNeeded:sdkAudioDirectory]) {
        NSLog(@"[AudioFileManager] 创建SDKAudio目录失败");
        return NO;
    }
    
    // 生成文件名（使用当前时间戳）
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    NSString *fileName = [NSString stringWithFormat:@"sdk_audio_%.0f.pcm", timestamp * 1000];
    
    // 完整文件路径
    NSString *filePath = [sdkAudioDirectory stringByAppendingPathComponent:fileName];
    self.sdkAudioFilePath = filePath;
    
    // 创建文件
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager createFileAtPath:filePath contents:nil attributes:nil]) {
        NSLog(@"[AudioFileManager] 创建SDK音频文件失败: %@", filePath);
        return NO;
    }
    
    // 打开文件句柄用于写入
    self.sdkAudioFileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    if (!self.sdkAudioFileHandle) {
        NSLog(@"[AudioFileManager] 打开SDK音频文件句柄失败: %@", filePath);
        return NO;
    }
    
    NSLog(@"[AudioFileManager] SDK音频文件创建成功: %@", filePath);
    return YES;
}

/**
 * 保存PCM数据到SDK音频文件
 */
- (BOOL)savePCMDataToSDKFile:(NSData *)pcmData {
    if (!pcmData || pcmData.length == 0) {
        NSLog(@"[AudioFileManager] PCM数据为空，无法保存");
        return NO;
    }
    
    if (!self.sdkAudioFileHandle) {
        NSLog(@"[AudioFileManager] SDK音频文件句柄不存在，无法保存数据");
        return NO;
    }
    
    @try {
        [self.sdkAudioFileHandle writeData:pcmData];
        return YES;
    } @catch (NSException *exception) {
        NSLog(@"[AudioFileManager] 写入SDK音频文件失败: %@", exception.reason);
        return NO;
    }
}

/**
 * 获取当前SDK音频文件路径
 */
- (NSString *)getCurrentSDKAudioFilePath {
    return self.sdkAudioFilePath;
}

/**
 * 关闭SDK音频文件
 */
- (void)closeSDKAudioFile {
    if (self.sdkAudioFileHandle) {
        [self.sdkAudioFileHandle closeFile];
        NSLog(@"[AudioFileManager] SDK音频文件已关闭: %@", self.sdkAudioFilePath);
        self.sdkAudioFileHandle = nil;
    }
}

#pragma mark - Temp Audio File (Document/SDKTempAudio/)

/**
 * 创建临时音频文件
 */
- (BOOL)createTempAudioFile {
    // 关闭之前的文件句柄（如果有）
    [self closeTempAudioFile];
    
    // 获取Document目录
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    
    // 创建SDKTempAudio目录
    NSString *tempAudioDirectory = [documentsDirectory stringByAppendingPathComponent:@"SDKTempAudio"];
    if (![self createDirectoryIfNeeded:tempAudioDirectory]) {
        NSLog(@"[AudioFileManager] 创建SDKTempAudio目录失败");
        return NO;
    }
    
    // 生成文件名（使用当前时间戳）
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    NSString *fileName = [NSString stringWithFormat:@"temp_audio_%.0f.pcm", timestamp * 1000];
    
    // 完整文件路径
    NSString *filePath = [tempAudioDirectory stringByAppendingPathComponent:fileName];
    self.tempAudioFilePath = filePath;
    
    // 创建文件
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager createFileAtPath:filePath contents:nil attributes:nil]) {
        NSLog(@"[AudioFileManager] 创建临时音频文件失败: %@", filePath);
        return NO;
    }
    
    // 打开文件句柄用于写入
    self.tempAudioFileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    if (!self.tempAudioFileHandle) {
        NSLog(@"[AudioFileManager] 打开临时音频文件句柄失败: %@", filePath);
        return NO;
    }
    
    NSLog(@"[AudioFileManager] 临时音频文件创建成功: %@", filePath);
    return YES;
}

/**
 * 保存PCM数据到临时音频文件
 */
- (BOOL)savePCMDataToTempFile:(NSData *)pcmData {
    if (!pcmData || pcmData.length == 0) {
        NSLog(@"[AudioFileManager] PCM数据为空，无法保存");
        return NO;
    }
    
    if (!self.tempAudioFileHandle) {
        NSLog(@"[AudioFileManager] 临时音频文件句柄不存在，无法保存数据");
        return NO;
    }
    
    // 打印 PCM 数据详情
//    [self logPCMDataDetails:pcmData tag:@"TempAudio"];
    
    @try {
        [self.tempAudioFileHandle writeData:pcmData];
//        NSLog(@"[AudioFileManager] 保存 %lu 字节数据到临时音频文件", (unsigned long)pcmData.length);
        return YES;
    } @catch (NSException *exception) {
        NSLog(@"[AudioFileManager] 写入临时音频文件失败: %@", exception.reason);
        return NO;
    }
}

/**
 * 获取当前临时音频文件路径
 */
- (NSString *)getCurrentTempAudioFilePath {
    return self.tempAudioFilePath;
}

/**
 * 关闭临时音频文件
 */
- (void)closeTempAudioFile {
    if (self.tempAudioFileHandle) {
        [self.tempAudioFileHandle closeFile];
        NSLog(@"[AudioFileManager] 临时音频文件已关闭: %@", self.tempAudioFilePath);
        self.tempAudioFileHandle = nil;
    }
}

#pragma mark - Utilities

/**
 * 关闭所有音频文件
 */
- (void)closeAllFiles {
    [self closeSDKAudioFile];
    [self closeTempAudioFile];
}

/**
 * 清空所有SDK音频文件
 */
- (BOOL)clearAllSDKAudioFiles {
    // 先关闭当前文件句柄
    [self closeSDKAudioFile];
    
    // 获取Document目录
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    NSString *sdkAudioDirectory = [documentsDirectory stringByAppendingPathComponent:@"SDKAudio"];
    
    return [self clearDirectoryContents:sdkAudioDirectory directoryName:@"SDKAudio"];
}

/**
 * 清空所有临时音频文件
 */
- (BOOL)clearAllTempAudioFiles {
    // 先关闭当前文件句柄
    [self closeTempAudioFile];
    
    // 获取Document目录
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    NSString *tempAudioDirectory = [documentsDirectory stringByAppendingPathComponent:@"SDKTempAudio"];
    
    return [self clearDirectoryContents:tempAudioDirectory directoryName:@"SDKTempAudio"];
}

/**
 * 清空所有音频文件
 */
- (BOOL)clearAllAudioFiles {
    BOOL sdkResult = [self clearAllSDKAudioFiles];
    BOOL tempResult = [self clearAllTempAudioFiles];
    
    if (sdkResult && tempResult) {
        NSLog(@"[AudioFileManager] 所有音频文件清空成功");
        return YES;
    } else {
        NSLog(@"[AudioFileManager] 音频文件清空失败 - SDK: %@, Temp: %@", 
              sdkResult ? @"成功" : @"失败", 
              tempResult ? @"成功" : @"失败");
        return NO;
    }
}

#pragma mark - Private Methods

/**
 * 创建目录（如果不存在）
 */
- (BOOL)createDirectoryIfNeeded:(NSString *)directoryPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    BOOL exists = [fileManager fileExistsAtPath:directoryPath isDirectory:&isDirectory];
    
    if (exists && isDirectory) {
        return YES;
    }
    
    NSError *error = nil;
    BOOL success = [fileManager createDirectoryAtPath:directoryPath
                          withIntermediateDirectories:YES
                                           attributes:nil
                                                error:&error];
    
    if (!success) {
        NSLog(@"[AudioFileManager] 创建目录失败: %@, 错误: %@", directoryPath, error.localizedDescription);
        return NO;
    }
    
    NSLog(@"[AudioFileManager] 成功创建目录: %@", directoryPath);
    return YES;
}

/**
 * 清空目录内容
 */
- (BOOL)clearDirectoryContents:(NSString *)directoryPath directoryName:(NSString *)directoryName {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // 检查目录是否存在
    BOOL isDirectory = NO;
    BOOL exists = [fileManager fileExistsAtPath:directoryPath isDirectory:&isDirectory];
    
    if (!exists || !isDirectory) {
        NSLog(@"[AudioFileManager] %@目录不存在，无需清空", directoryName);
        return YES;
    }
    
    // 获取目录中的所有文件
    NSError *error = nil;
    NSArray *files = [fileManager contentsOfDirectoryAtPath:directoryPath error:&error];
    
    if (error) {
        NSLog(@"[AudioFileManager] 读取%@目录失败: %@", directoryName, error.localizedDescription);
        return NO;
    }
    
    if (files.count == 0) {
        NSLog(@"[AudioFileManager] %@目录为空，无需清空", directoryName);
        return YES;
    }
    
    // 删除所有文件
    NSUInteger deletedCount = 0;
    for (NSString *fileName in files) {
        NSString *filePath = [directoryPath stringByAppendingPathComponent:fileName];
        
        NSError *deleteError = nil;
        BOOL success = [fileManager removeItemAtPath:filePath error:&deleteError];
        
        if (success) {
            deletedCount++;
        } else {
            NSLog(@"[AudioFileManager] 删除文件失败: %@, 错误: %@", filePath, deleteError.localizedDescription);
        }
    }
    
    NSLog(@"[AudioFileManager] %@目录清空完成，删除了 %lu 个文件", directoryName, (unsigned long)deletedCount);
    return deletedCount == files.count;
}

#pragma mark - PCM Data Logging

/**
 * 打印PCM数据详情
 * @param pcmData PCM数据
 * @param tag 标签（用于区分不同来源）
 */
- (void)logPCMDataDetails:(NSData *)pcmData tag:(NSString *)tag {
    if (!pcmData || pcmData.length == 0) {
        NSLog(@"[AudioFileManager][%@] PCM数据为空", tag);
        return;
    }
    
    // 基础信息
    NSUInteger dataLength = pcmData.length;

    // 格式化输出
    NSLog(@"[AudioFileManager][%@] ══════════════════════════════════", tag);
    NSLog(@"[AudioFileManager][%@] PCM数据详情:", tag);
    NSLog(@"[AudioFileManager][%@] ├─ 数据长度: %lu bytes", tag, (unsigned long)dataLength);
    NSLog(@"[AudioFileManager][%@] └─ 数据预览: %@", tag, [self hexStringFromData:pcmData maxLength:pcmData.length]);
    NSLog(@"[AudioFileManager][%@] ══════════════════════════════════", tag);
}

/**
 * 将数据转换为十六进制字符串（每4字节一组，用空格分隔）
 * @param data 数据
 * @param maxLength 最大长度（现在打印全部数据，此参数保留兼容性）
 * @return 十六进制字符串（格式：9954ee41 d03ed932 0e2e4835...）
 */
- (NSString *)hexStringFromData:(NSData *)data maxLength:(NSUInteger)maxLength {
    if (!data || data.length == 0) {
        return @"<empty>";
    }
    
    // 打印全部数据，忽略maxLength限制
    NSUInteger length = data.length;
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
    
    return hexString;
}

@end

