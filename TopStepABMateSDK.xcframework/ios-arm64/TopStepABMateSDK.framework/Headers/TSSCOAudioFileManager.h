#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Audio file manager for saving PCM data
 * @chinese 音频文件管理器，用于保存PCM数据
 *
 * @discussion
 * [EN]: Manages two types of audio files:
 *       1. SDK Audio files (Document/SDKAudio/) - Created on setupStartSpeak
 *       2. Temp Audio files (Document/SDKTempAudio/) - Created when speaking starts
 * [CN]: 管理两种类型的音频文件：
 *       1. SDK音频文件（Document/SDKAudio/）- 在setupStartSpeak时创建
 *       2. 临时音频文件（Document/SDKTempAudio/）- 在开始说话时创建
 */
@interface TSSCOAudioFileManager : NSObject

#pragma mark - SDK Audio File (Document/SDKAudio/)

/**
 * @brief Create SDK audio file
 * @chinese 创建SDK音频文件
 *
 * @discussion
 * [EN]: Creates a new file in Document/SDKAudio/ directory with timestamp-based filename.
 *       File format: sdk_audio_<timestamp>.pcm
 * [CN]: 在Document/SDKAudio/目录下创建新文件，使用时间戳作为文件名。
 *       文件格式：sdk_audio_<时间戳>.pcm
 *
 * @return
 * EN: YES if file created successfully, NO otherwise
 * CN: 创建成功返回YES，失败返回NO
 */
- (BOOL)createSDKAudioFile;

/**
 * @brief Save PCM data to SDK audio file
 * @chinese 保存PCM数据到SDK音频文件
 *
 * @param pcmData
 * EN: PCM audio data to save
 * CN: 要保存的PCM音频数据
 *
 * @return
 * EN: YES if data saved successfully, NO otherwise
 * CN: 保存成功返回YES，失败返回NO
 */
- (BOOL)savePCMDataToSDKFile:(NSData *)pcmData;

/**
 * @brief Get current SDK audio file path
 * @chinese 获取当前SDK音频文件路径
 *
 * @return
 * EN: Current SDK audio file path, nil if not created
 * CN: 当前SDK音频文件路径，未创建时返回nil
 */
- (nullable NSString *)getCurrentSDKAudioFilePath;

/**
 * @brief Close SDK audio file
 * @chinese 关闭SDK音频文件
 */
- (void)closeSDKAudioFile;

#pragma mark - Temp Audio File (Document/SDKTempAudio/)

/**
 * @brief Create temp audio file
 * @chinese 创建临时音频文件
 *
 * @discussion
 * [EN]: Creates a new file in Document/SDKTempAudio/ directory with timestamp-based filename.
 *       File format: temp_audio_<timestamp>.pcm
 * [CN]: 在Document/SDKTempAudio/目录下创建新文件，使用时间戳作为文件名。
 *       文件格式：temp_audio_<时间戳>.pcm
 *
 * @return
 * EN: YES if file created successfully, NO otherwise
 * CN: 创建成功返回YES，失败返回NO
 */
- (BOOL)createTempAudioFile;

/**
 * @brief Save PCM data to temp audio file
 * @chinese 保存PCM数据到临时音频文件
 *
 * @param pcmData
 * EN: PCM audio data to save
 * CN: 要保存的PCM音频数据
 *
 * @return
 * EN: YES if data saved successfully, NO otherwise
 * CN: 保存成功返回YES，失败返回NO
 */
- (BOOL)savePCMDataToTempFile:(NSData *)pcmData;

/**
 * @brief Get current temp audio file path
 * @chinese 获取当前临时音频文件路径
 *
 * @return
 * EN: Current temp audio file path, nil if not created
 * CN: 当前临时音频文件路径，未创建时返回nil
 */
- (nullable NSString *)getCurrentTempAudioFilePath;

/**
 * @brief Close temp audio file
 * @chinese 关闭临时音频文件
 */
- (void)closeTempAudioFile;

#pragma mark - Utilities

/**
 * @brief Close all audio files
 * @chinese 关闭所有音频文件
 *
 * @discussion
 * [EN]: Closes both SDK audio file and temp audio file handles.
 * [CN]: 关闭SDK音频文件和临时音频文件的文件句柄。
 */
- (void)closeAllFiles;

/**
 * @brief Clear all SDK audio files
 * @chinese 清空所有SDK音频文件
 *
 * @discussion
 * [EN]: Deletes all files in Document/SDKAudio/ directory.
 * [CN]: 删除Document/SDKAudio/目录下的所有文件。
 *
 * @return
 * EN: YES if cleared successfully, NO otherwise
 * CN: 清空成功返回YES，失败返回NO
 */
- (BOOL)clearAllSDKAudioFiles;

/**
 * @brief Clear all temp audio files
 * @chinese 清空所有临时音频文件
 *
 * @discussion
 * [EN]: Deletes all files in Document/SDKTempAudio/ directory.
 * [CN]: 删除Document/SDKTempAudio/目录下的所有文件。
 *
 * @return
 * EN: YES if cleared successfully, NO otherwise
 * CN: 清空成功返回YES，失败返回NO
 */
- (BOOL)clearAllTempAudioFiles;

/**
 * @brief Clear all audio files
 * @chinese 清空所有音频文件
 *
 * @discussion
 * [EN]: Deletes all files in both Document/SDKAudio/ and Document/SDKTempAudio/ directories.
 * [CN]: 删除Document/SDKAudio/和Document/SDKTempAudio/目录下的所有文件。
 *
 * @return
 * EN: YES if all cleared successfully, NO otherwise
 * CN: 全部清空成功返回YES，失败返回NO
 */
- (BOOL)clearAllAudioFiles;

@end

NS_ASSUME_NONNULL_END

