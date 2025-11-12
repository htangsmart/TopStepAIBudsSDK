//
//  TSOpusDecoder.m
//  soundbuds
//

#import "TSOpusDecoder.h"
#include <libopus/opus.h>
@interface TSOpusDecoder () {
  OpusDecoder *_decoder;
}
@property (nonatomic, assign) int frameSize;
@end

@implementation TSOpusDecoder

- (instancetype)initWithSampleRate:(int)sampleRateHz channels:(int)channels {
  self = [super init];
  if (self) {
    _sampleRate = sampleRateHz;
    _channels = channels;
    int error = 0;
    _decoder = opus_decoder_create(sampleRateHz, channels, &error);
    if (error != OPUS_OK || _decoder == NULL) {
      return nil;
    }
    // Typical max frame size for 48kHz is 120ms → 5760 samples per channel.
    // We pick a safe buffer; actual decoded size returned by opus_decode().
    _frameSize = 5760;
  }
  return self;
}

- (NSData *)decodePacket:(NSData *)packet {
  if (_decoder == NULL || packet == nil || packet.length == 0) {
    return nil;
  }

  // Allocate temporary buffer for decoded PCM (16-bit signed).
  // samples = frameSize * channels
  int numSamples = _frameSize * _channels;
  int16_t *pcmBuffer = (int16_t *)malloc(sizeof(int16_t) * numSamples);
  if (!pcmBuffer) {
    return nil;
  }

  opus_int32 packetLen = (opus_int32)packet.length;
  const unsigned char *data = (const unsigned char *)packet.bytes;

  // Decode one packet. OPUS_AUTO for FEC disabled; change if needed.
  int decodedSamples = opus_decode(_decoder, data, packetLen, pcmBuffer, _frameSize, 0);
  if (decodedSamples < 0) {
    free(pcmBuffer);
    return nil;
  }

  // Build NSData from decoded PCM
  size_t bytes = (size_t)decodedSamples * _channels * sizeof(int16_t);
  NSData *pcmData = [NSData dataWithBytes:pcmBuffer length:bytes];
  free(pcmBuffer);
  return pcmData;
}

- (void)reset {
  if (_decoder) {
    opus_decoder_ctl(_decoder, OPUS_RESET_STATE);
  }
}

- (void)close {
  if (_decoder) {
    opus_decoder_destroy(_decoder);
    _decoder = NULL;
  }
}

- (void)dealloc {
  [self close];
}

@end


