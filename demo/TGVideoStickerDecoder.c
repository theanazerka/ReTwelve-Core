#include "TGVideoStickerDecoder.h"
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>
#include <libavutil/imgutils.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

typedef struct { const uint8_t *bytes; size_t length, offset; } TGStickerInput;
static int TGRead(void *opaque, uint8_t *buffer, int size) {
    TGStickerInput *input = opaque;
    size_t remaining = input->length - input->offset;
    if (!remaining) return AVERROR_EOF;
    size_t count = remaining < (size_t)size ? remaining : (size_t)size;
    memcpy(buffer, input->bytes + input->offset, count); input->offset += count;
    return (int)count;
}
static int64_t TGSeek(void *opaque, int64_t offset, int whence) {
    TGStickerInput *input = opaque;
    if (whence == AVSEEK_SIZE) return input->length;
    whence &= ~AVSEEK_FORCE;
    int64_t base = whence == SEEK_SET ? 0 : whence == SEEK_CUR ? input->offset : whence == SEEK_END ? input->length : -1;
    if (base < 0 || offset < -base || offset > (int64_t)input->length - base) return AVERROR(EINVAL);
    input->offset = base + offset; return input->offset;
}
int TGDecodeVideoSticker(const void *data, size_t length, int maxSide, double targetFPS,
                        TGVideoStickerFrameCallback callback, void *context, double *duration) {
    if (!data || !length || length > 512 * 1024 || maxSide < 1 || maxSide > 320 ||
        targetFPS < 1 || targetFPS > 30 || !callback || !duration) return 0;
    TGStickerInput input = {data, length, 0};
    AVFormatContext *format = avformat_alloc_context();
    uint8_t *ioBuffer = av_malloc(8192);
    AVIOContext *io = ioBuffer ? avio_alloc_context(ioBuffer, 8192, 0, &input, TGRead, NULL, TGSeek) : NULL;
    AVCodecContext *codec = NULL; AVFrame *frame = NULL; AVPacket *packet = NULL;
    struct SwsContext *scaler = NULL; uint8_t *pixels = NULL;
    int emitted = 0, decoded = 0, valid = 0, stream = -1, draining = 0;
    double nextTime = 0, endTime = 0, firstTime = NAN, sourceFPS = 30;
    if (!format || !io) goto cleanup;
    format->pb = io; format->flags |= AVFMT_FLAG_CUSTOM_IO;
    // Explicit demuxer and decoder prevent probing unrelated formats or losing alpha.
    if (avformat_open_input(&format, NULL, av_find_input_format("matroska"), NULL) < 0) goto cleanup;
    for (unsigned i = 0; i < format->nb_streams; i++)
        if (format->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) { stream = (int)i; break; }
    if (stream < 0 || format->streams[stream]->codecpar->codec_id != AV_CODEC_ID_VP9) goto cleanup;
    const AVCodec *decoder = avcodec_find_decoder_by_name("libvpx-vp9");
    if (!decoder) goto cleanup;
    codec = avcodec_alloc_context3(decoder);
    if (!codec || avcodec_parameters_to_context(codec, format->streams[stream]->codecpar) < 0) goto cleanup;
    if (codec->width < 1 || codec->height < 1 || codec->width > 512 || codec->height > 512) goto cleanup;
    codec->max_pixels = 512 * 512;
    codec->thread_count = 1;
    if (avcodec_open2(codec, decoder, NULL) < 0) goto cleanup;
    AVRational rate = av_guess_frame_rate(format, format->streams[stream], NULL);
    if (rate.num > 0 && rate.den > 0) sourceFPS = av_q2d(rate);
    if (sourceFPS < 1 || sourceFPS > 60) goto cleanup;
    frame = av_frame_alloc(); packet = av_packet_alloc();
    if (!frame || !packet) goto cleanup;
    while (decoded < 180) {
        int result = avcodec_receive_frame(codec, frame);
        if (result == AVERROR_EOF) { valid = 1; break; }
        if (result == AVERROR(EAGAIN)) {
            if (draining) goto cleanup;
            while ((result = av_read_frame(format, packet)) >= 0) {
                if (packet->stream_index == stream) break;
                av_packet_unref(packet);
            }
            if (result < 0) {
                if (result != AVERROR_EOF) goto cleanup;
                draining = 1; result = avcodec_send_packet(codec, NULL);
            } else result = avcodec_send_packet(codec, packet);
            av_packet_unref(packet);
            if (result < 0 && result != AVERROR_EOF) goto cleanup;
            continue;
        }
        if (result < 0) goto cleanup;
        decoded++;
        if (frame->width < 1 || frame->height < 1 || frame->width > 512 || frame->height > 512) goto cleanup;
        double time = frame->best_effort_timestamp == AV_NOPTS_VALUE ? (decoded - 1) / sourceFPS :
            frame->best_effort_timestamp * av_q2d(format->streams[stream]->time_base);
        if (isnan(firstTime)) firstTime = time;
        time -= firstTime;
        if (!isfinite(time) || time < 0 || time > 3.1) goto cleanup;
        endTime = time + 1 / sourceFPS;
        // WebM timestamps have millisecond precision; choose the closest source
        // frame instead of dropping frames rounded just before the target time.
        if (time + .5 / sourceFPS >= nextTime && emitted < 90) {
            int longest = frame->width > frame->height ? frame->width : frame->height;
            int width = (frame->width * maxSide + longest / 2) / longest;
            int height = (frame->height * maxSide + longest / 2) / longest;
            width = width > 0 ? width : 1; height = height > 0 ? height : 1;
            scaler = sws_getCachedContext(scaler, frame->width, frame->height, frame->format,
                width, height, AV_PIX_FMT_BGRA, SWS_BILINEAR, NULL, NULL, NULL);
            if (!scaler) goto cleanup;
            free(pixels); pixels = malloc((size_t)width * height * 4);
            if (!pixels) goto cleanup;
            uint8_t *dest[4] = {pixels, NULL, NULL, NULL}; int strides[4] = {width * 4, 0, 0, 0};
            if (sws_scale(scaler, (const uint8_t *const *)frame->data, frame->linesize, 0, frame->height, dest, strides) != height) goto cleanup;
            for (int i = 0; i < width * height; i++) {
                unsigned alpha = pixels[i * 4 + 3];
                for (int channel = 0; channel < 3; channel++) pixels[i * 4 + channel] = (pixels[i * 4 + channel] * alpha + 127) / 255;
            }
            if (!callback(context, pixels, width, height)) goto cleanup;
            emitted++; nextTime += 1 / targetFPS;
            if (nextTime < time) nextTime = time + 1 / targetFPS;
        }
        av_frame_unref(frame);
    }
cleanup:
    free(pixels); sws_freeContext(scaler);
    av_packet_free(&packet); av_frame_free(&frame); avcodec_free_context(&codec);
    avformat_close_input(&format);
    if (io) { av_freep(&io->buffer); avio_context_free(&io); } else av_free(ioBuffer);
    if (!valid || emitted < 2 || endTime <= 0 || endTime > 3.2) return 0;
    *duration = endTime; return emitted;
}
