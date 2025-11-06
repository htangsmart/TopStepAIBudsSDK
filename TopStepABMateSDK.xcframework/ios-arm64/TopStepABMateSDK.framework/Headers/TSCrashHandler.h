//
//  TSCrashHandler.h
//  TopStepABMateSDK
//
//  Created by Auto on 2025/01/XX.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Crash handler for Signal crashes (SIGABRT, SIGSEGV, SIGBUS, SIGTRAP, etc.)
 * @chinese 用于处理 Signal 崩溃的处理器（SIGABRT、SIGSEGV、SIGBUS、SIGTRAP 等）
 *
 * @discussion
 * [EN]: This class handles Signal-based crashes that cannot be caught by NSSetUncaughtExceptionHandler.
 *      It registers signal handlers for common crash types and saves crash logs to file.
 * [CN]: 此类处理无法通过 NSSetUncaughtExceptionHandler 捕获的基于 Signal 的崩溃。
 *      它会为常见的崩溃类型注册信号处理器，并将崩溃日志保存到文件。
 *
 * @note
 * [EN]: Signal crashes include Swift runtime errors (array out of bounds, force unwrap nil, etc.)
 *      and system-level crashes (memory access violations, etc.)
 * [CN]: Signal 崩溃包括 Swift 运行时错误（数组越界、强制解包 nil 等）和系统级崩溃（内存访问违规等）
 */
@interface TSCrashHandler : NSObject

/**
 * @brief Install signal handlers for crash capture
 * @chinese 安装信号处理器以捕获崩溃
 *
 * @discussion
 * [EN]: Registers handlers for common crash signals:
 *      - SIGABRT: Abort signal (assertion failures, abort() calls)
 *      - SIGBUS: Bus error (invalid memory access)
 *      - SIGSEGV: Segmentation violation (memory access violations)
 *      - SIGILL: Illegal instruction
 *      - SIGTRAP: Trace/BPT trap (Swift runtime errors, breakpoint exceptions)
 *      - SIGFPE: Floating-point exception
 *
 *      After calling this method, crash logs will be automatically saved to the log directory.
 * [CN]: 为常见的崩溃信号注册处理器：
 *      - SIGABRT: 中止信号（断言失败、abort() 调用）
 *      - SIGBUS: 总线错误（无效内存访问）
 *      - SIGSEGV: 段错误（内存访问违规）
 *      - SIGILL: 非法指令
 *      - SIGTRAP: 跟踪/断点陷阱（Swift 运行时错误、断点异常）
 *      - SIGFPE: 浮点异常
 *
 *      调用此方法后，崩溃日志将自动保存到日志目录。
 *
 * @note
 * [EN]: This method should only be called once during app initialization.
 *      Multiple calls will have no effect.
 * [CN]: 此方法应在应用初始化时仅调用一次。多次调用无效。
 */
+ (void)installSignalHandlers;

/**
 * @brief Get the crash log directory path
 * @chinese 获取崩溃日志目录路径
 *
 * @return
 * [EN]: The directory path where crash logs are saved
 * [CN]: 保存崩溃日志的目录路径
 */
+ (NSString *)crashLogDirectory;

/**
 * @brief Set the crash log directory path
 * @chinese 设置崩溃日志目录路径
 *
 * @param directory
 * [EN]: The directory path where crash logs should be saved
 * [CN]: 应保存崩溃日志的目录路径
 */
+ (void)setCrashLogDirectory:(NSString *)directory;

/**
 * @brief Save crash log to file synchronously
 * @chinese 同步保存崩溃日志到文件
 *
 * @param crashInfo
 * [EN]: The crash information string to save
 * [CN]: 要保存的崩溃信息字符串
 *
 * @param fileName
 * [EN]: The file name for the crash log (e.g., "UncaughtException.log" or "SignalCrash.log")
 * [CN]: 崩溃日志的文件名（例如："UncaughtException.log" 或 "SignalCrash.log"）
 *
 * @discussion
 * [EN]: This method should be used within signal handlers or exception handlers.
 *      It performs synchronous file I/O to ensure crash information is saved before app termination.
 * [CN]: 此方法应在信号处理器或异常处理器内使用。
 *      它执行同步文件 I/O 以确保在应用终止前保存崩溃信息。
 */
+ (void)saveCrashLog:(NSString *)crashInfo toFile:(NSString *)fileName;

@end

NS_ASSUME_NONNULL_END

