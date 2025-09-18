//
//  TSCppEISWrapper.h
//  Runner
//
//  Created by luigi on 2025/8/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSCppEISWrapper : NSObject
typedef void (^StabilizationProgressBlock)(float progress); // 0.0 ~ 1.0
typedef void (^StabilizationCompletionBlock)(NSError * _Nullable error);

- (void)stabilizeVideo:(NSURL *)inputURL outputURL:(NSURL *)outputURL result:(void (^)(NSString * _Nullable, NSError * _Nullable))result;

@end

NS_ASSUME_NONNULL_END
