#import "TGCallAudio.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <opus/opus.h>
#import <libkern/OSAtomic.h>

#define TG_CALL_RATE 48000
#define TG_CALL_FRAME 960
#define TG_CALL_RING 48000
static char TGCallCodecQueueKey;

typedef struct {
    int16_t samples[TG_CALL_RING];
    volatile uint32_t head;
    volatile uint32_t tail;
} TGCallRing;

static BOOL TGCallRingWrite(TGCallRing *ring, const int16_t *samples, uint32_t count) {
    uint32_t head = ring->head, tail = ring->tail;
    if (count > TG_CALL_RING - (head - tail)) return NO;
    for (uint32_t i = 0; i < count; i++) ring->samples[(head + i) % TG_CALL_RING] = samples[i];
    OSMemoryBarrier(); ring->head = head + count;
    return YES;
}
static uint32_t TGCallRingRead(TGCallRing *ring, int16_t *samples, uint32_t count) {
    uint32_t tail = ring->tail;
    uint32_t available = ring->head - tail;
    uint32_t taken = MIN(count, available);
    for (uint32_t i = 0; i < taken; i++) samples[i] = ring->samples[(tail + i) % TG_CALL_RING];
    OSMemoryBarrier(); ring->tail = tail + taken;
    return taken;
}

@interface TGCallAudio () {
@public
    AudioUnit _unit;
    OpusEncoder *_encoder;
    OpusDecoder *_decoder;
    TGCallRing _capture;
    TGCallRing _playback;
    dispatch_queue_t _codecQueue;
    dispatch_source_t _captureTimer;
    BOOL _running;
}
@end

static OSStatus TGCallInput(void *refcon, AudioUnitRenderActionFlags *flags,
    const AudioTimeStamp *timestamp, UInt32 bus, UInt32 count, AudioBufferList *data) {
    TGCallAudio *audio = (__bridge TGCallAudio *)refcon;
    if (count > 2048) return kAudio_ParamError;
    int16_t samples[2048];
    AudioBufferList buffer = { .mNumberBuffers = 1,
        .mBuffers = {{ .mNumberChannels = 1, .mDataByteSize = count * sizeof(int16_t), .mData = samples }} };
    OSStatus status = AudioUnitRender(audio->_unit, flags, timestamp, 1, count, &buffer);
    if (status == noErr) TGCallRingWrite(&audio->_capture, samples, count);
    return status;
}
static OSStatus TGCallOutput(void *refcon, AudioUnitRenderActionFlags *flags,
    const AudioTimeStamp *timestamp, UInt32 bus, UInt32 count, AudioBufferList *data) {
    TGCallAudio *audio = (__bridge TGCallAudio *)refcon;
    for (UInt32 i = 0; i < data->mNumberBuffers; i++) {
        AudioBuffer *buffer = &data->mBuffers[i];
        UInt32 frames = MIN(count, buffer->mDataByteSize / sizeof(int16_t));
        int16_t *samples = buffer->mData;
        uint32_t taken = TGCallRingRead(&audio->_playback, samples, frames);
        if (taken < frames) memset(samples + taken, 0, (frames - taken) * sizeof(int16_t));
        buffer->mDataByteSize = frames * sizeof(int16_t);
    }
    return noErr;
}

@implementation TGCallAudio
- (instancetype)init {
    self = [super init];
    if (self) {
        _codecQueue = dispatch_queue_create("telegram.call-audio", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_codecQueue, &TGCallCodecQueueKey, &TGCallCodecQueueKey, NULL);
    }
    return self;
}
- (BOOL)start:(NSString **)error {
    if (_running) return YES;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *sessionError = nil;
    if (![session setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionError] ||
        ![session setActive:YES error:&sessionError]) {
        if (error) *error = sessionError.localizedDescription ?: @"Не удалось включить микрофон.";
        return NO;
    }
    [session setPreferredSampleRate:TG_CALL_RATE error:nil];
    int opusError = OPUS_OK;
    _encoder = opus_encoder_create(TG_CALL_RATE, 1, OPUS_APPLICATION_VOIP, &opusError);
    if (!_encoder || opusError != OPUS_OK) goto failure;
    opus_encoder_ctl(_encoder, OPUS_SET_BITRATE(24000));
    opus_encoder_ctl(_encoder, OPUS_SET_COMPLEXITY(3));
    opus_encoder_ctl(_encoder, OPUS_SET_INBAND_FEC(1));
    _decoder = opus_decoder_create(TG_CALL_RATE, 1, &opusError);
    if (!_decoder || opusError != OPUS_OK) goto failure;
    AudioComponentDescription component = {0};
    component.componentType = kAudioUnitType_Output;
    component.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    component.componentManufacturer = kAudioUnitManufacturer_Apple;
    AudioComponent found = AudioComponentFindNext(NULL, &component);
    if (!found || AudioComponentInstanceNew(found, &_unit) != noErr) goto failure;
    UInt32 enabled = 1;
    if (AudioUnitSetProperty(_unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1,
                             &enabled, sizeof(enabled)) != noErr) goto failure;
    AudioStreamBasicDescription format = {0};
    format.mSampleRate = TG_CALL_RATE;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    format.mFramesPerPacket = 1; format.mChannelsPerFrame = 1;
    format.mBitsPerChannel = 16; format.mBytesPerFrame = 2; format.mBytesPerPacket = 2;
    if (AudioUnitSetProperty(_unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1,
                             &format, sizeof(format)) != noErr ||
        AudioUnitSetProperty(_unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
                             &format, sizeof(format)) != noErr) goto failure;
    AURenderCallbackStruct input = { .inputProc = TGCallInput, .inputProcRefCon = (__bridge void *)self };
    AURenderCallbackStruct output = { .inputProc = TGCallOutput, .inputProcRefCon = (__bridge void *)self };
    if (AudioUnitSetProperty(_unit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1,
                             &input, sizeof(input)) != noErr ||
        AudioUnitSetProperty(_unit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0,
                             &output, sizeof(output)) != noErr || AudioUnitInitialize(_unit) != noErr) goto failure;
    _capture.head = _capture.tail = _playback.head = _playback.tail = 0;
    [self startCaptureTimer];
    if (AudioOutputUnitStart(_unit) != noErr) goto failure;
    _running = YES;
    return YES;
failure:
    if (error) *error = @"Не удалось запустить звуковой модуль звонка.";
    [self stop];
    return NO;
}
- (void)startCaptureTimer {
    _captureTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _codecQueue);
    __weak TGCallAudio *weakSelf = self;
    dispatch_source_set_event_handler(_captureTimer, ^{
        TGCallAudio *audio = weakSelf;
        if (audio) [audio encodeAvailableAudio];
    });
    dispatch_source_set_timer(_captureTimer, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_MSEC),
                              10 * NSEC_PER_MSEC, 2 * NSEC_PER_MSEC);
    dispatch_resume(_captureTimer);
}
- (void)encodeAvailableAudio {
    int16_t samples[TG_CALL_FRAME];
    uint8_t encoded[4000];
    for (int i = 0; i < 4 && _capture.head - _capture.tail >= TG_CALL_FRAME; i++) {
        if (TGCallRingRead(&_capture, samples, TG_CALL_FRAME) != TG_CALL_FRAME) break;
        int length = opus_encode(_encoder, samples, TG_CALL_FRAME, encoded, sizeof(encoded));
        if (length > 0 && self.packetHandler) self.packetHandler([NSData dataWithBytes:encoded length:length]);
    }
}
- (void)receivePacket:(NSData *)packet {
    if (!_running || !packet.length || packet.length > 4000) return;
    NSData *copy = [packet copy];
    __weak TGCallAudio *weakSelf = self;
    dispatch_async(_codecQueue, ^{
        TGCallAudio *audio = weakSelf;
        if (!audio || !audio->_running || !audio->_decoder) return;
        int16_t samples[5760];
        int count = opus_decode(audio->_decoder, copy.bytes, (opus_int32)copy.length,
                                samples, 5760, 0);
        if (count > 0) TGCallRingWrite(&audio->_playback, samples, (uint32_t)count);
    });
}
- (void)stop {
    _running = NO;
    if (_captureTimer) { dispatch_source_cancel(_captureTimer); _captureTimer = nil; }
    if (_unit) { AudioOutputUnitStop(_unit); AudioUnitUninitialize(_unit);
        AudioComponentInstanceDispose(_unit); _unit = NULL; }
    if (!dispatch_get_specific(&TGCallCodecQueueKey)) dispatch_sync(_codecQueue, ^{});
    if (_encoder) { opus_encoder_destroy(_encoder); _encoder = NULL; }
    if (_decoder) { opus_decoder_destroy(_decoder); _decoder = NULL; }
    _capture.head = _capture.tail = _playback.head = _playback.tail = 0;
    [[AVAudioSession sharedInstance] setActive:NO error:nil];
}
- (void)dealloc { [self stop]; }
@end
