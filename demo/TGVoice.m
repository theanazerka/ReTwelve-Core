#import "TGVoice.h"
#import <AudioToolbox/AudioToolbox.h>
#import <opus/opus.h>
#import <opus/opusfile.h>
#import <ogg/ogg.h>
#import <Security/Security.h>

static void TGWrite16(uint8_t *at, uint16_t value) { at[0] = value & 255; at[1] = value >> 8; }
static void TGWrite32(uint8_t *at, uint32_t value) {
    at[0] = value & 255; at[1] = (value >> 8) & 255;
    at[2] = (value >> 16) & 255; at[3] = value >> 24;
}
static void TGAppendPages(ogg_stream_state *stream, NSMutableData *output, BOOL flush) {
    ogg_page page;
    while ((flush ? ogg_stream_flush(stream, &page) : ogg_stream_pageout(stream, &page)) > 0) {
        [output appendBytes:page.header length:page.header_len];
        [output appendBytes:page.body length:page.body_len];
    }
}
static BOOL TGAddPacket(ogg_stream_state *stream, NSMutableData *output, const void *bytes,
                        long length, ogg_int64_t number, ogg_int64_t granule, BOOL first, BOOL last) {
    ogg_packet packet = {0};
    packet.packet = (unsigned char *)bytes;
    packet.bytes = length;
    packet.b_o_s = first;
    packet.e_o_s = last;
    packet.granulepos = granule;
    packet.packetno = number;
    if (ogg_stream_packetin(stream, &packet) != 0) return NO;
    TGAppendPages(stream, output, first || last);
    return YES;
}

NSData *TGVoiceEncodeCAF(NSString *path, NSData **waveform, NSString **error) {
    if (error) *error = nil;
    if (waveform) *waveform = nil;
    ExtAudioFileRef file = NULL;
    NSURL *url = [NSURL fileURLWithPath:path];
    OSStatus status = ExtAudioFileOpenURL((__bridge CFURLRef)url, &file);
    if (status != noErr || !file) { if (error) *error = @"Не удалось открыть запись."; return nil; }
    AudioStreamBasicDescription format = {0};
    format.mSampleRate = 48000;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    format.mBytesPerPacket = 2; format.mFramesPerPacket = 1;
    format.mBytesPerFrame = 2; format.mChannelsPerFrame = 1; format.mBitsPerChannel = 16;
    status = ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, sizeof(format), &format);
    SInt64 frameCount = 0;
    UInt32 propertySize = sizeof(frameCount);
    if (status == noErr) status = ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileLengthFrames, &propertySize, &frameCount);
    if (status != noErr || frameCount <= 0) {
        ExtAudioFileDispose(file);
        if (error) *error = @"Запись пуста или повреждена.";
        return nil;
    }
    int opusError = 0;
    OpusEncoder *encoder = opus_encoder_create(48000, 1, OPUS_APPLICATION_VOIP, &opusError);
    if (!encoder || opusError != OPUS_OK) {
        ExtAudioFileDispose(file);
        if (error) *error = @"Не удалось запустить кодирование Opus.";
        return nil;
    }
    opus_encoder_ctl(encoder, OPUS_SET_BITRATE(24000));
    int lookahead = 0;
    opus_encoder_ctl(encoder, OPUS_GET_LOOKAHEAD(&lookahead));
    uint32_t serial = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(serial), (uint8_t *)&serial) != errSecSuccess) serial = arc4random();
    ogg_stream_state stream;
    if (ogg_stream_init(&stream, (int)serial) != 0) {
        opus_encoder_destroy(encoder); ExtAudioFileDispose(file);
        if (error) *error = @"Не удалось создать Ogg поток.";
        return nil;
    }
    NSMutableData *output = [NSMutableData data];
    uint8_t head[19] = {0};
    memcpy(head, "OpusHead", 8); head[8] = 1; head[9] = 1;
    TGWrite16(head + 10, (uint16_t)lookahead);
    TGWrite32(head + 12, 48000);
    const char *vendor = "Telegram Legacy iOS 6";
    uint32_t vendorLength = (uint32_t)strlen(vendor);
    NSMutableData *tags = [NSMutableData dataWithBytes:"OpusTags" length:8];
    uint8_t lengthBytes[4]; TGWrite32(lengthBytes, vendorLength);
    [tags appendBytes:lengthBytes length:4];
    [tags appendBytes:vendor length:vendorLength];
    TGWrite32(lengthBytes, 0); [tags appendBytes:lengthBytes length:4];
    BOOL good = TGAddPacket(&stream, output, head, sizeof(head), 0, 0, YES, NO) &&
                TGAddPacket(&stream, output, tags.bytes, (long)tags.length, 1, 0, NO, NO);
    TGAppendPages(&stream, output, YES);
    SInt64 encodedFrames = frameCount + lookahead;
    SInt64 packetCount = (encodedFrames + 959) / 960;
    uint16_t peaks[100] = {0};
    for (SInt64 index = 0; good && index < packetCount; index++) {
        opus_int16 pcm[960] = {0};
        UInt32 frames = 960;
        AudioBufferList buffers = {0};
        buffers.mNumberBuffers = 1;
        buffers.mBuffers[0].mNumberChannels = 1;
        buffers.mBuffers[0].mDataByteSize = sizeof(pcm);
        buffers.mBuffers[0].mData = pcm;
        if (index * 960 < frameCount) {
            status = ExtAudioFileRead(file, &frames, &buffers);
            if (status != noErr) { good = NO; break; }
            for (UInt32 sample = 0; sample < frames; sample++) {
                NSUInteger bucket = (NSUInteger)MIN(99, ((index * 960 + sample) * 100) / frameCount);
                int amplitude = abs((int)pcm[sample]);
                if (amplitude > peaks[bucket]) peaks[bucket] = (uint16_t)amplitude;
            }
        }
        uint8_t packet[1500];
        opus_int32 packetLength = opus_encode(encoder, pcm, 960, packet, sizeof(packet));
        if (packetLength <= 0) { good = NO; break; }
        BOOL last = index == packetCount - 1;
        ogg_int64_t granule = last ? encodedFrames : (index + 1) * 960;
        good = TGAddPacket(&stream, output, packet, packetLength, index + 2, granule, NO, last);
        if (!last) TGAppendPages(&stream, output, NO);
    }
    ogg_stream_clear(&stream);
    opus_encoder_destroy(encoder);
    ExtAudioFileDispose(file);
    if (!good || !output.length) {
        if (error) *error = @"Не удалось закодировать голосовое сообщение.";
        return nil;
    }
    if (waveform) {
        uint32_t sum = 0;
        for (int i = 0; i < 100; i++) sum += peaks[i];
        uint32_t scale = MAX(2500, sum * 18 / 1000);
        uint8_t packed[63] = {0};
        for (int i = 0; i < 100; i++) {
            unsigned value = MIN(31, (uint32_t)peaks[i] * 31 / scale);
            NSUInteger bit = (NSUInteger)i * 5, byte = bit / 8;
            packed[byte] |= (uint8_t)(value << (bit % 8));
            if (byte + 1 < sizeof(packed)) packed[byte + 1] |= (uint8_t)(value >> (8 - bit % 8));
        }
        *waveform = [NSData dataWithBytes:packed length:sizeof(packed)];
    }
    return output;
}

BOOL TGVoiceDecodeOgg(NSData *data, NSString *wavPath, NSString **error) {
    if (error) *error = nil;
    if (!data.length || data.length > INT32_MAX) { if (error) *error = @"Голосовое сообщение недоступно."; return NO; }
    int opusError = 0;
    OggOpusFile *file = op_open_memory(data.bytes, (size_t)data.length, &opusError);
    if (!file) { if (error) *error = @"Не удалось открыть Ogg/Opus."; return NO; }
    [[NSFileManager defaultManager] createFileAtPath:wavPath contents:nil attributes:nil];
    NSFileHandle *output = [NSFileHandle fileHandleForWritingAtPath:wavPath];
    if (!output) { op_free(file); if (error) *error = @"Не удалось сохранить голосовое сообщение."; return NO; }
    uint8_t header[44] = {0};
    [output writeData:[NSData dataWithBytes:header length:sizeof(header)]];
    uint64_t samples = 0;
    BOOL good = YES;
    for (;;) {
        opus_int16 pcm[11520];
        int count = op_read_stereo(file, pcm, 11520);
        if (count == 0) break;
        if (count < 0 || samples + count > UINT32_MAX / 4) { good = NO; break; }
        [output writeData:[NSData dataWithBytes:pcm length:(NSUInteger)count * 4]];
        samples += count;
    }
    op_free(file);
    if (good) {
        memcpy(header, "RIFF", 4); TGWrite32(header + 4, (uint32_t)(36 + samples * 4));
        memcpy(header + 8, "WAVEfmt ", 8); TGWrite32(header + 16, 16);
        TGWrite16(header + 20, 1); TGWrite16(header + 22, 2);
        TGWrite32(header + 24, 48000); TGWrite32(header + 28, 48000 * 4);
        TGWrite16(header + 32, 4); TGWrite16(header + 34, 16);
        memcpy(header + 36, "data", 4); TGWrite32(header + 40, (uint32_t)(samples * 4));
        [output seekToFileOffset:0];
        [output writeData:[NSData dataWithBytes:header length:sizeof(header)]];
    }
    [output closeFile];
    if (!good) {
        [[NSFileManager defaultManager] removeItemAtPath:wavPath error:nil];
        if (error) *error = @"Ошибка декодирования Opus.";
    }
    return good;
}
