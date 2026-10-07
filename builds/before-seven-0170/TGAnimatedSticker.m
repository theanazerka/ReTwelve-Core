#import "TGAnimatedSticker.h"
#import <zlib.h>
#import <rlottie_capi.h>
#import "TGStickerAnimationCacheKey.h"
#import <objc/runtime.h>
#import "TGVideoStickerDecoder.h"

static char TGStickerDurationKey;
NSTimeInterval TGAnimatedStickerDuration(NSArray *frames) {
    NSNumber *duration = objc_getAssociatedObject(frames, &TGStickerDurationKey);
    return duration ? duration.doubleValue : frames.count / ([UIScreen mainScreen].scale > 1 ? 24.0 : 15.0);
}

static void TGFreeFrame(__unused void *info, const void *bytes, __unused size_t length) { free((void *)bytes); }

typedef struct { void *frames; CGColorSpaceRef colorSpace; } TGVideoStickerOutput;
static int TGAddVideoFrame(void *context, const uint8_t *pixels, int width, int height) {
    TGVideoStickerOutput *output = context;
    size_t length = (size_t)width * height * 4;
    void *copy = malloc(length); if (!copy) return 0;
    memcpy(copy, pixels, length);
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, copy, length, TGFreeFrame);
    CGImageRef image = provider ? CGImageCreate(width, height, 8, 32, width * 4, output->colorSpace,
        kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little, provider, NULL, false, kCGRenderingIntentDefault) : NULL;
    if (image) [(__bridge NSMutableArray *)output->frames addObject:[UIImage imageWithCGImage:image]];
    if (image) CGImageRelease(image);
    if (provider) CGDataProviderRelease(provider); else free(copy);
    return image != NULL;
}
NSArray *TGVideoStickerFrames(NSData *webmData) {
    NSMutableArray *frames = [NSMutableArray array];
    TGVideoStickerOutput output = {(__bridge void *)frames, CGColorSpaceCreateDeviceRGB()};
    BOOL retina = [UIScreen mainScreen].scale > 1; double duration = 0;
    int count = TGDecodeVideoSticker(webmData.bytes, webmData.length, retina ? 160 : 128,
        retina ? 24 : 15, TGAddVideoFrame, &output, &duration);
    CGColorSpaceRelease(output.colorSpace);
    if (count < 2 || frames.count != (NSUInteger)count) return nil;
    objc_setAssociatedObject(frames, &TGStickerDurationKey, @(duration), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return frames;
}

NSArray *TGAnimatedStickerFrames(NSData *tgsData) {
    if (!tgsData.length || tgsData.length > 512 * 1024) return nil;
    z_stream stream = {0};
    if (inflateInit2(&stream, MAX_WBITS + 16) != Z_OK) return nil;
    NSMutableData *json = [NSMutableData dataWithLength:2 * 1024 * 1024];
    stream.next_in = (Bytef *)tgsData.bytes;
    stream.avail_in = (uInt)tgsData.length;
    stream.next_out = json.mutableBytes;
    stream.avail_out = (uInt)json.length - 1;
    int status = inflate(&stream, Z_FINISH);
    NSUInteger count = stream.total_out;
    inflateEnd(&stream);
    if (status != Z_STREAM_END || count < 10 || count >= json.length) return nil;
    ((char *)json.mutableBytes)[count] = 0;
    NSString *key = TGStickerAnimationCacheKey(json.bytes, count);
    Lottie_Animation *animation = lottie_animation_from_data(json.bytes, key.UTF8String, "");
    if (!animation) return nil;
    size_t total = lottie_animation_get_totalframe(animation);
    double fps = lottie_animation_get_framerate(animation);
    if (total < 2 || total > 600 || fps < 1 || fps > 120) {
        lottie_animation_destroy(animation); return nil;
    }
    BOOL retina = [UIScreen mainScreen].scale > 1;
    const size_t side = retina ? 160 : 128;
    double targetFps = retina ? 24.0 : 15.0;
    NSUInteger frameCount = MIN(retina ? 72 : 45,
        MAX(2, (NSUInteger)ceil((double)total / fps * targetFps)));
    NSMutableArray *frames = [NSMutableArray arrayWithCapacity:frameCount];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    for (NSUInteger i = 0; i < frameCount; i++) {
        uint32_t *pixels = calloc(side * side, sizeof(uint32_t));
        if (!pixels) break;
        size_t sourceFrame = MIN(total - 1, (size_t)((double)i * total / frameCount));
        lottie_animation_render(animation, sourceFrame, pixels, side, side, side * 4);
        CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixels, side * side * 4, TGFreeFrame);
        CGImageRef image = provider ? CGImageCreate(side, side, 8, 32, side * 4, colorSpace,
            kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little, provider, NULL, false,
            kCGRenderingIntentDefault) : NULL;
        if (image) [frames addObject:[UIImage imageWithCGImage:image]];
        if (image) CGImageRelease(image);
        if (provider) CGDataProviderRelease(provider); else free(pixels);
    }
    CGColorSpaceRelease(colorSpace);
    lottie_animation_destroy(animation);
    if (frames.count != frameCount) return nil;
    objc_setAssociatedObject(frames, &TGStickerDurationKey, @((double)total / fps), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return frames;
}
