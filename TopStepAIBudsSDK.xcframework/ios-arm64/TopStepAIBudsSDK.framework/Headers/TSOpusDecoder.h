//
//  TSOpusDecoder.h
//  soundbuds
//
//  A tiny Objective-C wrapper for libopus to decode Opus packets to PCM16.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSOpusDecoder : NSObject

/// Initialize an Opus decoder.
/// - Parameters:
///   - sampleRateHz: Sampling rate in Hz. Commonly 48000 for Opus.
///   - channels: Number of audio channels. 1 for mono, 2 for stereo.
- (instancetype)initWithSampleRate:(int)sampleRateHz channels:(int)channels;

/// Decode a single Opus packet to PCM S16LE.
/// - Parameter packet: Encoded Opus frame bytes (one packet). Must not be nil.
/// - Returns: PCM data in little-endian 16-bit. Returns nil on error.
- (nullable NSData *)decodePacket:(NSData *)packet;

/// Reset decoder state (e.g., when seeking or stream discontinuity).
- (void)reset;

/// Dispose resources. Called automatically on dealloc.
- (void)close;

@property (nonatomic, readonly) int sampleRate;
@property (nonatomic, readonly) int channels;

@end

NS_ASSUME_NONNULL_END


