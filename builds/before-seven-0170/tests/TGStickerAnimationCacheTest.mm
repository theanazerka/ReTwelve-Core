#import <Foundation/Foundation.h>
#import "../TGStickerAnimationCacheKey.h"
#include <rlottie_capi.h>
#include <zlib.h>
#include <vector>

static NSData *JSON(NSString *path) {
    gzFile file = gzopen(path.fileSystemRepresentation, "rb");
    NSCAssert(file, @"Missing fixture: %@", path);
    NSMutableData *data = [NSMutableData data];
    char buffer[8192]; int count;
    while ((count = gzread(file, buffer, sizeof(buffer))) > 0) [data appendBytes:buffer length:count];
    NSCAssert(count == 0, @"Invalid TGS fixture"); gzclose(file);
    return data;
}
int main(int argc, char **argv) { @autoreleasepool {
    NSCAssert(argc == 3, @"Pass two different TGS paths");
    NSString *firstKey = nil; size_t previousTotal = 0;
    for (int i = 1; i < argc; i++) {
        NSData *json = JSON([NSString stringWithUTF8String:argv[i]]);
        NSString *key = TGStickerAnimationCacheKey(json.bytes, json.length);
        NSCAssert([key isEqual:TGStickerAnimationCacheKey(json.bytes, json.length)], @"Unstable cache key");
        if (firstKey) NSCAssert(![firstKey isEqual:key], @"Different animations share a model key");
        else firstKey = key;
        NSDictionary *metadata = [NSJSONSerialization JSONObjectWithData:json options:0 error:nil];
        NSMutableData *terminated = [json mutableCopy]; [terminated appendBytes:"" length:1];
        Lottie_Animation *animation = lottie_animation_from_data((const char *)terminated.bytes, key.UTF8String, "");
        NSCAssert(animation, @"Animation failed to parse");
        size_t total = lottie_animation_get_totalframe(animation);
        NSCAssert(total == [metadata[@"op"] unsignedIntegerValue] - [metadata[@"ip"] unsignedIntegerValue], @"Wrong cached animation timeline");
        NSCAssert(lottie_animation_get_framerate(animation) == [metadata[@"fr"] doubleValue], @"Wrong FPS");
        if (previousTotal) NSCAssert(total != previousTotal, @"Fixtures must have distinct timelines");
        previousTotal = total;
        std::vector<uint32_t> first(64 * 64), later(64 * 64);
        lottie_animation_render(animation, 0, first.data(), 64, 64, 64 * 4);
        lottie_animation_render(animation, total / 2, later.data(), 64, 64, 64 * 4);
        NSCAssert(first != later, @"Sticker decoded as a static image");
        lottie_animation_destroy(animation);
        printf("PASS %s: %zu animated frames\n", argv[i], total);
    }
} return 0; }
